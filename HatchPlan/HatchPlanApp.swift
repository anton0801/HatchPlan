import SwiftUI
import Combine
import Firebase
import UserNotifications
import AppsFlyerLib
import AppTrackingTransparency

extension ApplicationDelegate {
    
    func passDataToMainApp() {
        var mergingDataPulses = hatchPlanConversionData
        for (key, value) in hatchDataConversionDeeplinks {
            if mergingDataPulses[key] == nil {
                mergingDataPulses[key] = value
            }
        }
        sendData(data: mergingDataPulses)
        UserDefaults.standard.set(true, forKey: hasSentAttributionKey)
        hatchPlanConversionData = [:]
        hatchDataConversionDeeplinks = [:]
        mergingTimerForHatch?.invalidate()
    }
    
}

@main
struct HatchPlanApp: App {
    
    @UIApplicationDelegateAdaptor(ApplicationDelegate.self) var delegate
    
    var body: some Scene {
        WindowGroup {
            HatchPlanEntry()
        }
    }
    
}

struct ContentWrapperView: View {
    
    @AppStorage("hasSeenOnboarding") var hasSeenOnboarding = false
    
    @StateObject private var store = AppStore()
    
    var body: some View {
        ZStack {
            if hasSeenOnboarding {
                MainTabView().environmentObject(store)
                    .preferredColorScheme(.dark)
                    .onAppear {
                        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
                            if granted {
                                DispatchQueue.main.async {
                                    UIApplication.shared.registerForRemoteNotifications()
                                }
                            }
                        }
                    }
            } else {
                OnboardingView { hasSeenOnboarding = true }
                    .environmentObject(store)
                    .preferredColorScheme(.dark)
            }
        }
        .onAppear {
            setupAppearance()
        }
    }
    
    private func setupAppearance() {
        UINavigationBar.appearance().largeTitleTextAttributes = [.foregroundColor: UIColor.white]
        UINavigationBar.appearance().titleTextAttributes = [.foregroundColor: UIColor.white]
        UITabBar.appearance().barTintColor = UIColor(Theme.background)
    }
    
}

struct MainTabView: View {
    @EnvironmentObject var store: AppStore
    
    var body: some View {
        TabView {
            DashboardView().tabItem { Label("Home", systemImage: "house") }
            BatchesView().tabItem { Label("Batches", systemImage: "tray.full") }
            CalendarView().tabItem { Label("Calendar", systemImage: "calendar") }
            ReportsView().tabItem { Label("Reports", systemImage: "chart.bar") }
            SettingsView().tabItem { Label("Settings", systemImage: "gear") }
        }
        .accentColor(Color.yellow)
        .background(Theme.background)
    }
}

struct HatchingEggAnimation: View {
    @State private var crack = 0.0
    var body: some View {
        ZStack {
            Image("EggChicken")
                .resizable()
                .frame(width: 120, height: 140)
            Path { path in
                let w = 120.0
                let h = 140.0
                path.move(to: CGPoint(x: w*0.4, y: h*0.3))
                path.addLine(to: CGPoint(x: w*0.6, y: h*0.35))
            }
            .trim(from: 0, to: crack)
            .stroke(Color.white, lineWidth: 3)
            .onAppear {
                withAnimation(.easeInOut(duration: 2).repeatCount(1)) {
                    crack = 1.0
                }
            }
        }
    }
}

class ApplicationDelegate: UIResponder, UIApplicationDelegate, AppsFlyerLibDelegate, MessagingDelegate, UNUserNotificationCenterDelegate, DeepLinkDelegate {
    
    private var hatchDataConversionDeeplinks: [AnyHashable: Any] = [:]
    private var hatchPlanConversionData: [AnyHashable: Any] = [:]
    
    private let hasSentAttributionKey = "hasSentAttributionData"
    
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        FirebaseApp.configure()
        Messaging.messaging().delegate = self
        UNUserNotificationCenter.current().delegate = self
        UIApplication.shared.registerForRemoteNotifications()
        AppsFlyerLib.shared().appsFlyerDevKey = AppConstants.appsFlyerDevKey
        AppsFlyerLib.shared().appleAppID = AppConstants.appsFlyerAppID
        AppsFlyerLib.shared().delegate = self
        AppsFlyerLib.shared().deepLinkDelegate = self
        
        if let remotePayload = launchOptions?[.remoteNotification] as? [AnyHashable: Any] {
            pulsingDataFromPushRetrive(from: remotePayload)
        }
        
        func observeAppActivation() {
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(triggerTracking),
                name: UIApplication.didBecomeActiveNotification,
                object: nil
            )
        }
        
        observeAppActivation()
        return true
    }
    
    private let mergingTimerKeyForDL = "deepLinkMergeTimer"
    
    private var mergingTimerForHatch: Timer?
    
    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        Messaging.messaging().apnsToken = deviceToken
    }
    
    @objc private func triggerTracking() {
        if #available(iOS 14.0, *) {
            AppsFlyerLib.shared().waitForATTUserAuthorization(timeoutInterval: 60)
            ATTrackingManager.requestTrackingAuthorization { _ in
                DispatchQueue.main.async {
                    AppsFlyerLib.shared().start()
                }
            }
        }
    }
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        pulsingDataFromPushRetrive(from: response.notification.request.content.userInfo)
        completionHandler()
    }
    
    private func fireMergedTimer() {
        mergingTimerForHatch?.invalidate()
        mergingTimerForHatch = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: false) { [weak self] _ in
            self?.passDataToMainApp()
        }
    }
    
    
    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        pulsingDataFromPushRetrive(from: userInfo)
        completionHandler(.newData)
    }
    
    
    private func pulsingDataFromPushRetrive(from payload: [AnyHashable: Any]) {
        var hatchPlanningDtaFromPush: String?
        if let url = payload["url"] as? String {
            hatchPlanningDtaFromPush = url
        } else if let data = payload["data"] as? [String: Any],
                  let url = data["url"] as? String {
            hatchPlanningDtaFromPush = url
        }
        if let yesssssPussshhhDataUrl = hatchPlanningDtaFromPush {
            UserDefaults.standard.set(yesssssPussshhhDataUrl, forKey: "temp_url")
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                NotificationCenter.default.post(
                    name: NSNotification.Name("LoadTempURL"),
                    object: nil,
                    userInfo: ["temp_url": yesssssPussshhhDataUrl]
                )
            }
        }
    }
    func onConversionDataSuccess(_ data: [AnyHashable: Any]) {
        hatchPlanConversionData = data
        fireMergedTimer()
        if !hatchDataConversionDeeplinks.isEmpty {
            passDataToMainApp()
        }
    }
    
    func didResolveDeepLink(_ result: DeepLinkResult) {
        guard case .found = result.status,
              let deepLinkObj = result.deepLink else { return }
        guard !UserDefaults.standard.bool(forKey: hasSentAttributionKey) else { return }
        hatchDataConversionDeeplinks = deepLinkObj.clickEvent
        NotificationCenter.default.post(name: Notification.Name("deeplink_values"), object: nil, userInfo: ["deeplinksData": hatchDataConversionDeeplinks])
        mergingTimerForHatch?.invalidate()
        if !hatchPlanConversionData.isEmpty {
            passDataToMainApp()
        }
    }
    
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        messaging.token { [weak self] token, error in
            guard error == nil, let token = token else { return }
            UserDefaults.standard.set(token, forKey: "fcm_token")
            UserDefaults.standard.set(token, forKey: "push_token")
        }
    }
    
    
    func sendData(data: [AnyHashable: Any]) {
        NotificationCenter.default.post(
            name: Notification.Name("ConversionDataReceived"),
            object: nil,
            userInfo: ["conversionData": data]
        )
    }
    
    func onConversionDataFail(_ error: Error) {
        sendData(data: [:])
    }
    
    
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        let payload = notification.request.content.userInfo
        pulsingDataFromPushRetrive(from: payload)
        completionHandler([.banner, .sound])
    }
    
}


class AppStore: ObservableObject {
    @Published var batches: [Batch] = []
    @Published var tasks: [IncubationTask] = []
    @Published var presets: [IncubationPreset] = IncubationPreset.default.values.map { $0 }

    init() {
        batches = Storage.shared.loadBatches()
        tasks = Storage.shared.loadTasks()
    }

    func day(for batch: Batch) -> Int {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: batch.startDate, to: Date())
        return max(1, (components.day ?? 0) + 1)
    }

    func progress(for batch: Batch) -> Double {
        Double(day(for: batch)) / Double(batch.totalDays)
    }

    func status(for batch: Batch) -> (text: String, color: Color) {
        let day = self.day(for: batch)
        if day >= batch.stopTurnDay { return ("Lockdown", Theme.accentTeal) }
        return ("Normal", Theme.successLime)
    }

    func addBatch(_ batch: Batch) {
        batches.append(batch)
        Storage.shared.saveBatches(batches)
        scheduleTasks(for: batch)
    }

    func scheduleTasks(for batch: Batch) {
        var newTasks: [IncubationTask] = []

        // Turn tasks
        for day in 1..<batch.stopTurnDay {
            for _ in 1...batch.preset.turnPerDay {
                let due = Calendar.current.date(byAdding: .day, value: day - 1, to: batch.startDate)!
                newTasks.append(IncubationTask(batchId: batch.id, type: .turn, dueAt: due))
            }
        }

        // Candling
        let candleDays = [7, 14]
        for day in candleDays where day <= batch.totalDays {
            let due = Calendar.current.date(byAdding: .day, value: day - 1, to: batch.startDate)!
            newTasks.append(IncubationTask(batchId: batch.id, type: .candle, dueAt: due))
        }

        // Stop turn
        let stopDue = Calendar.current.date(byAdding: .day, value: batch.stopTurnDay - 1, to: batch.startDate)!
        newTasks.append(IncubationTask(batchId: batch.id, type: .stopTurn, dueAt: stopDue))

        tasks.append(contentsOf: newTasks)
        Storage.shared.saveTasks(tasks)
    }

    func completeTask(_ task: IncubationTask) {
        if let idx = tasks.firstIndex(where: { $0.id == task.id }) {
            tasks[idx].status = .done
            Storage.shared.saveTasks(tasks)
        }
    }
}
