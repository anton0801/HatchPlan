import SwiftUI
import WebKit
import Combine

struct BatchDetailView: View {
    let batch: Batch
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) var dismiss
    @State private var showFinishSheet = false
    @State private var showEditDate = false
    @State private var showDuplicate = false

    private var day: Int { store.day(for: batch) }
    private var progress: Double { Double(day) / Double(batch.totalDays) }
    private var missedTurns: Int {
        store.tasks.filter { $0.batchId == batch.id && $0.type == .turn && $0.status == .missed }.count
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.left")
                    }
                    Spacer()
                }
                .padding(.horizontal)
                VStack(spacing: 20) {
                    ZStack {
                        Circle()
                            .fill(Theme.card)
                            .frame(width: 100, height: 100)
                        Image(systemName: batch.species.iconName)
                            .font(.system(size: 50, weight: .medium))
                            .foregroundColor(Theme.accentYellow)
                    }

                    VStack(spacing: 8) {
                        Text(batch.name)
                            .font(Theme.nunito(34, weight: .bold))
                            .foregroundColor(.white)

                        Text(batch.species.displayName.uppercased())
                            .font(Theme.inter(16, weight: .semibold))
                            .foregroundColor(Theme.accentYellow)
                    }
                }
                .padding(.top, 20)

                // MARK: - Большой прогресс-круг
                ZStack {
                    CircularProgressView(progress: progress)
                        .frame(width: 220, height: 220)

                    VStack(spacing: 8) {
                        Text("Day \(day)")
                            .font(Theme.nunito(48, weight: .bold))
                        Text("of \(batch.totalDays)")
                            .font(Theme.inter(20))
                            .foregroundColor(.secondary)
                    }
                }

                // MARK: - Статистика
                VStack(spacing: 16) {
                    StatRow(title: "Total Eggs", value: "\(batch.totalEggs)", icon: "tray.full")
                    StatRow(title: "Missed Turns", value: missedTurns > 0 ? "\(missedTurns)" : "None",
                           icon: "exclamationmark.triangle", color: missedTurns > 0 ? Theme.alertCoral : Theme.successLime)
                    
                    if batch.isFinished {
                        StatRow(title: "Hatched", value: "\(batch.hatchedCount)/\(batch.totalEggs)",
                               icon: "bird.fill", color: Theme.successLime)
                    }
                }
                .padding(.horizontal, 24)

                VStack(spacing: 16) {
                    if !batch.isFinished {
                        BigActionButton2(
                            title: "Finish Batch",
                            icon: "checkmark.circle.fill",
                            color: Theme.successLime,
                            foreground: .black
                        ) {
                            showFinishSheet = true
                        }
                    }

                    BigActionButton2(
                        title: "Duplicate Batch",
                        icon: "doc.on.doc"
                    ) {
                        showDuplicate = true
                    }

                    BigActionButton2(
                        title: "Edit Lay Date",
                        icon: "calendar"
                    ) {
                        showEditDate = true
                    }
                }
                .padding(.horizontal, 20)

                Spacer(minLength: 40)
            }
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationBarHidden(true)
        .sheet(isPresented: $showFinishSheet) {
            FinishBatchSheet(batch: batch) { count in
                store.finishBatch(batch, hatched: count)
            }
        }
        .sheet(isPresented: $showEditDate) {
            EditLayDateSheet(batch: batch) { newDate in
                store.updateBatchDate(batch, newDate: newDate)
            }
        }
        .alert("Duplicate Batch?", isPresented: $showDuplicate) {
            Button("Duplicate") {
                store.duplicateBatch(batch)
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        }
    }
}

// MARK: - Компоненты
struct StatRow: View {
    let title: String
    let value: String
    let icon: String
    var color: Color = Theme.accentYellow

    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(Theme.inter(15))
                    .foregroundColor(.secondary)
                Text(value)
                    .font(Theme.nunito(24, weight: .bold))
            }

            Spacer()
        }
        .padding(20)
        .background(Theme.card)
        .cornerRadius(20)
    }
}

struct BigActionButton2: View {
    let title: String
    let icon: String
    var color: Color = Theme.accentYellow
    var foreground: Color = .black
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.title2)

                Text(title)
                    .font(Theme.nunito(20, weight: .bold))
            }
            .frame(maxWidth: .infinity)
            .padding(20)
            .background(color)
            .foregroundColor(foreground)
            .cornerRadius(20)
            .shadow(radius: 8)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

class HatchiPlanMainConverterandContainerMainer: ObservableObject {
    @Published var mainHatchView: WKWebView!
    
    private var observers = Set<AnyCancellable>()
    
    func setUpAllHatches() {
        mainHatchView = HatchPlanMainBuilderHelper.summonBirdNest()
            .configurePerch(minZoom: 1.0, maxZoom: 1.0, bounce: false)
            .enableWingNavigation()
    }
    
    @Published var extraDevicesForTrackHatch: [WKWebView] = []
    
    
    func restoreSavedDataOfPugs() {
        guard let saved = UserDefaults.standard.object(forKey: "preserved_grains") as? [String: [String: [HTTPCookiePropertyKey: AnyObject]]] else { return }
        
        let feeder = mainHatchView.configuration.websiteDataStore.httpCookieStore
        let grains = saved.values.flatMap { $0.values }.compactMap {
            HTTPCookie(properties: $0 as [HTTPCookiePropertyKey: Any])
        }
        
        grains.forEach { feeder.setCookie($0) }
    }
    
    func returnHatch(to url: URL? = nil) {
        if !extraDevicesForTrackHatch.isEmpty {
            if let topExtra = extraDevicesForTrackHatch.last {
                topExtra.removeFromSuperview()
                extraDevicesForTrackHatch.removeLast()
            }
            
            
            if let trail = url {
                mainHatchView.load(URLRequest(url: trail))
            }
        } else if mainHatchView.canGoBack {
            mainHatchView.goBack()
        }
    }
    
    func refreshDawn() {
        mainHatchView.reload()
    }
    
    
}

struct EditLayDateSheet: View {
    let batch: Batch
    let onSave: (Date) -> Void
    @State private var selectedDate = Date()
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            Form {
                DatePicker("Lay / Collection Date", selection: $selectedDate, displayedComponents: .date)
                    .datePickerStyle(.graphical)
            }
            .navigationTitle("Edit Date")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(selectedDate)
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            selectedDate = batch.startDate
        }
    }
}
