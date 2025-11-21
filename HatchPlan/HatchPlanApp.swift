import SwiftUI
import Combine
import AppTrackingTransparency

class ApplicationDelegate: UIResponder, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    
    private var attributionData: [AnyHashable: Any] = [:]
    private let trackingActivationKey = UIApplication.didBecomeActiveNotification

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
//        NotificationCenter.default.addObserver(
//                    self,
//                    selector: #selector(triggerTracking),
//                    name: trackingActivationKey,
//                    object: nil
//                )
//        ATTrackingManager.requestTrackingAuthorization { _ in
//            DispatchQueue.main.async {
//                // AppsFlyerLib.shared().start()
//            }
//        }
        
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
        
        UNUserNotificationCenter.current().delegate = self
        return true
    }
    
//    @objc private func triggerTracking() {
//        if #available(iOS 14.0, *) {
//            // AppsFlyerLib.shared().waitForATTUserAuthorization(timeoutInterval: 60)
//            ATTrackingManager.requestTrackingAuthorization { _ in
//                DispatchQueue.main.async {
//                    // AppsFlyerLib.shared().start()  // ← СТАРТ ЗДЕСЬ, ОДИН РАЗ!
//                }
//            }
//        }
//    }
    
    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        // extractAndStoreDeepLink(from: userInfo)
        completionHandler(.newData)
    }
    
    // MARK: - UNUserNotificationCenterDelegate
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        let payload = notification.request.content.userInfo
        // extractAndStoreDeepLink(from: payload)
        completionHandler([.banner, .sound])
    }
    
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        // extractAndStoreDeepLink(from: response.notification.request.content.userInfo)
        completionHandler()
    }
    
}

@main
struct HatchPlanApp: App {
    
    @StateObject private var store = AppStore()
    @AppStorage("hasSeenOnboarding") var hasSeenOnboarding = false
    
    @UIApplicationDelegateAdaptor(ApplicationDelegate.self) var delegate
    
    init() {
        setupAppearance()
    }
    
    var body: some Scene {
        WindowGroup {
            if hasSeenOnboarding {
                MainTabView().environmentObject(store)
                    .preferredColorScheme(.dark)
            } else {
                OnboardingView { hasSeenOnboarding = true }
                    .environmentObject(store)
                    .preferredColorScheme(.dark)
            }
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
