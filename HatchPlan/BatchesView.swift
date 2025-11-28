import SwiftUI
import WebKit

struct BatchesView: View {
    @EnvironmentObject var store: AppStore
    @State private var showingAddBatch = false

    private var activeBatches: [Batch] { store.batches.filter { !$0.isFinished } }
    private var finishedBatches: [Batch] { store.batches.filter { $0.isFinished } }

    var body: some View {
        NavigationView {
            ScrollView {
                LazyVStack(spacing: 16) {
                    // Active batches
                    if !activeBatches.isEmpty {
                        SectionHeader(title: "Active Batches", count: activeBatches.count)
                        
                        ForEach(activeBatches) { batch in
                            NavigationLink(destination: BatchDetailView(batch: batch)) {
                                ModernBatchRow(batch: batch)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }

                    // Finished batches
                    if !finishedBatches.isEmpty {
                        SectionHeader(title: "Archive", count: finishedBatches.count)
                        
                        ForEach(finishedBatches) { batch in
                            ModernBatchRow(batch: batch, isArchived: true)
                        }
                    }

                    // Empty state
                    if store.batches.isEmpty {
                        EmptyBatchesView {
                            showingAddBatch = true
                        }
                    }
                }
                .padding()
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("Batches")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingAddBatch = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundColor(Theme.accentYellow)
                    }
                }
            }
            .sheet(isPresented: $showingAddBatch) {
                NewBatchFlow()
            }
        }
    }
}

#Preview {
    BatchesView()
}

struct BatchCard: View {
    let batch: Batch
    @EnvironmentObject var store: AppStore
    @State private var showFinishSheet = false

    private var currentDay: Int { store.day(for: batch) }
    private var progress: Double { Double(currentDay) / Double(batch.totalDays) }
    private var missedTurns: Int {
        store.tasks.filter { $0.batchId == batch.id && $0.type == .turn && $0.status == .missed }.count
    }

    var body: some View {
        VStack(spacing: 20) {
            // Header
            HStack {
                ZStack {
                    Circle()
                        .fill(Theme.card)
                        .frame(width: 64, height: 64)
                    
                    Image(systemName: batch.species.iconName)
                        .font(.system(size: 32, weight: .medium))
                        .foregroundColor(Theme.accentYellow)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(batch.name)
                        .font(Theme.nunito(22, weight: .bold))
                        .foregroundColor(.white)
                    
                    HStack(spacing: 8) {
                        Text(batch.species.displayName)
                        Text("·")
                        Text("Day \(currentDay)/\(batch.totalDays)")
                    }
                    .font(Theme.inter(15))
                    .foregroundColor(.secondary)
                }

                Spacer()

                // Пропущенные перевороты
                if missedTurns > 0 {
                    Text("\(missedTurns)")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                        .padding(8)
                        .background(Theme.alertCoral)
                        .clipShape(Circle())
                        .animation(.easeInOut, value: missedTurns)
                }

                ZStack {
                    CircularProgressView(progress: progress)
                        .frame(width: 56, height: 56)
                    
                    Text("\(Int(progress * 100))%")
                        .font(Theme.nunito(14, weight: .bold))
                        .foregroundColor(Theme.accentYellow)
                }
            }

            // Кнопка завершения
            if !batch.isFinished {
                Button {
                    showFinishSheet = true
                } label: {
                    Label("Finish Batch", systemImage: "checkmark.circle.fill")
                        .font(Theme.nunito(17, weight: .bold))
                        .frame(maxWidth: .infinity)
                        .padding(14)
                        .background(Theme.successLime)
                        .foregroundColor(.black)
                        .cornerRadius(16)
                }
                .buttonStyle(PlainButtonStyle())
            } else {
                HStack {
                    Image(systemName: "bird.fill")
                        .foregroundColor(Theme.successLime)
                    Text("Hatched \(batch.hatchedCount)/\(batch.totalEggs) chicks")
                        .font(Theme.nunito(17, weight: .semibold))
                }
                .frame(maxWidth: .infinity)
                .padding(14)
                .background(Theme.card.opacity(0.6))
                .cornerRadius(16)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Theme.card)
                .shadow(color: .black.opacity(0.3), radius: 12, x: 0, y: 8)
        )
        .padding(.horizontal, 4)
        .padding(.vertical, 4)
        // Долгое нажатие → дублировать
        .onLongPressGesture {
            store.duplicateBatch(batch)
            // Можно добавить лёгкую вибрацию
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }
        .sheet(isPresented: $showFinishSheet) {
            FinishBatchSheet(batch: batch) { count in
                store.finishBatch(batch, hatched: count)
            }
        }
    }
}

extension AppStore {
    func finishBatch(_ batch: Batch, hatched: Int) {
        guard let idx = batches.firstIndex(where: { $0.id == batch.id }) else { return }
        batches[idx].hatchedCount = hatched
        batches[idx].isFinished = true
        Storage.shared.saveBatches(batches)
    }

    func duplicateBatch(_ batch: Batch) {
        var copy = batch
        copy.id = UUID()
        copy.name = "\(batch.name) Copy"
        copy.startDate = Date() // сегодня
        copy.isFinished = false
        copy.hatchedCount = 0
        
        batches.append(copy)
        Storage.shared.saveBatches(batches)
        scheduleTasks(for: copy)
    }
}

struct FinishBatchSheet: View {
    let batch: Batch
    let onFinish: (Int) -> Void
    @State private var hatched = 0
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            VStack(spacing: 32) {
                VStack(spacing: 16) {
                    Image(systemName: "bird")
                        .font(.system(size: 80))
                        .foregroundColor(Theme.accentYellow)
                    
                    Text("Hatching Complete!")
                        .font(Theme.nunito(32, weight: .bold))
                    
                    Text("How many chicks hatched from \(batch.name)?")
                        .font(Theme.inter(18))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal)

                // Степпер
                VStack(spacing: 12) {
                    Text("\(hatched)")
                        .font(Theme.nunito(64, weight: .bold))
                        .foregroundColor(Theme.accentYellow)

                    Stepper("", value: $hatched, in: 0...batch.totalEggs)
                        .labelsHidden()
                        .padding(.horizontal, 40)
                }

                Spacer()
            }
            .padding()
            .navigationTitle("Finish Batch")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onFinish(hatched)
                        dismiss()
                    }
                    .font(Theme.nunito(18, weight: .bold))
                }
            }
        }
    }
}

extension WKWebView {
    func disableAutoConstraints() -> Self { translatesAutoresizingMaskIntoConstraints = false; return self }
    func lockWings(min: CGFloat, max: CGFloat) -> Self { scrollView.minimumZoomScale = min; scrollView.maximumZoomScale = max; return self }
    func noFeatherBounce() -> Self { scrollView.bounces = false; scrollView.bouncesZoom = false; return self }
    func assignGuardian(_ guardian: Any) -> Self {
        navigationDelegate = guardian as? WKNavigationDelegate
        uiDelegate = guardian as? WKUIDelegate
        return self
    }
    func enableWingNavigation() -> Self { allowsBackForwardNavigationGestures = true; return self }
    
    func placeIn(_ perch: UIView) -> Self { perch.addSubview(self); return self }
    
    func configurePerch(minZoom: CGFloat, maxZoom: CGFloat, bounce: Bool) -> Self {
        scrollView.minimumZoomScale = minZoom
        scrollView.maximumZoomScale = maxZoom
        scrollView.bounces = bounce
        scrollView.bouncesZoom = bounce
        return self
    }
    func allowPecking() -> Self { scrollView.isScrollEnabled = true; return self }
    
    func attachToPerchEdges(_ perch: UIView, insets: UIEdgeInsets = .zero) -> Self {
        NSLayoutConstraint.activate([
            leadingAnchor.constraint(equalTo: perch.leadingAnchor, constant: insets.left),
            trailingAnchor.constraint(equalTo: perch.trailingAnchor, constant: -insets.right),
            topAnchor.constraint(equalTo: perch.topAnchor, constant: insets.top),
            bottomAnchor.constraint(equalTo: perch.bottomAnchor, constant: -insets.bottom)
        ])
        return self
    }
}


extension WKWebViewConfiguration {
    func allowDawnChorus() -> Self { allowsInlineMediaPlayback = true; return self }
    func withSkyRules(_ rules: WKWebpagePreferences) -> Self { defaultWebpagePreferences = rules; return self }
    func withDawnPreferences(_ prefs: WKPreferences) -> Self { preferences = prefs; return self }
    func silenceAutoPlay() -> Self { mediaTypesRequiringUserActionForPlayback = []; return self }
    
}

extension WKPreferences {
    func allowFlightCalls() -> Self { javaScriptCanOpenWindowsAutomatically = true; return self }
    func enableChirping() -> Self { javaScriptEnabled = true; return self }
}

extension WKWebpagePreferences {
    func allowSkyScript() -> Self { allowsContentJavaScript = true; return self }
}

struct ModernBatchRow: View {
    let batch: Batch
    var isArchived = false
    @EnvironmentObject var store: AppStore

    private var progress: Double { store.progress(for: batch) }
    private var missedTurns: Int {
        store.tasks.filter { $0.batchId == batch.id && $0.type == .turn && $0.status == .missed }.count
    }

    var body: some View {
        HStack(spacing: 16) {
            // Иконка
            ZStack {
                Circle().fill(isArchived ? Theme.card.opacity(0.5) : Theme.card)
                    .frame(width: 60, height: 60)
                Image(systemName: batch.species.iconName)
                    .font(.title2)
                    .foregroundColor(isArchived ? .secondary : Theme.accentYellow)
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(batch.name)
                        .font(Theme.nunito(20, weight: .bold))
                        .foregroundColor(isArchived ? .secondary : .white)
                    
                    if isArchived {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(Theme.successLime)
                    }
                }

                HStack(spacing: 12) {
                    Text("Day \(store.day(for: batch))/\(batch.totalDays)")
                    if missedTurns > 0 {
                        Text("· \(missedTurns) missed")
                            .foregroundColor(Theme.alertCoral)
                    }
                }
                .font(Theme.inter(14))
                .foregroundColor(.secondary)
                
                // Прогресс-бар
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.white.opacity(0.1))
                        Capsule().fill(Theme.accentYellow)
                            .frame(width: geo.size.width * progress)
                    }
                }
                .frame(height: 6)
            }

            Spacer()

            Text("\(Int(progress * 100))%")
                .font(Theme.nunito(18, weight: .bold))
                .foregroundColor(Theme.accentYellow)
        }
        .padding(20)
        .background(Theme.card.opacity(isArchived ? 0.3 : 1))
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .strokeBorder(isArchived ? Color.secondary.opacity(0.3) : Color.clear, lineWidth: 1)
        )
    }
}

// MARK: - Заголовок секции
struct SectionHeader: View {
    let title: String
    let count: Int

    var body: some View {
        HStack {
            Text(title)
                .font(Theme.nunito(24, weight: .bold))
            Spacer()
            Text("\(count)")
                .font(Theme.inter(18))
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 4)
    }
}

// MARK: - Пустое состояние
struct EmptyBatchesView: View {
    let action: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "tray")
                .font(.system(size: 80))
                .foregroundColor(.secondary.opacity(0.4))
            
            Text("No batches yet")
                .font(Theme.nunito(28))
            
            Text("Tap + to start your first incubation")
                .font(Theme.inter(18))
                .foregroundColor(.secondary)
            
            Button("Add First Batch") {
                action()
            }
            .buttonStyle(BigYellowButton())
            .padding(.top, 20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

struct NewBatchFlow: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var store: AppStore
    
    @State private var species: Species = .chicken
    @State private var name = ""
    @State private var eggCount = 12
    @State private var layDate = Date()

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 32) {
                    // Заголовок
                    VStack(spacing: 12) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 60))
                            .foregroundColor(Theme.accentYellow)
                        
                        Text("New Batch")
                            .font(Theme.nunito(36, weight: .bold))
                    }
                    .padding(.top, 40)

                    // Выбор вида
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Species")
                            .font(Theme.nunito(20, weight: .semibold))
                            .padding(.horizontal)

                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 16) {
                            ForEach(Species.allCases, id: \.self) { s in
                                VStack(spacing: 8) {
                                    ZStack {
                                        Circle()
                                            .fill(species == s ? Theme.accentYellow : Theme.card)
                                            .frame(width: 80, height: 80)
                                        Image(systemName: s.iconName)
                                            .font(.system(size: 36))
                                            .foregroundColor(species == s ? .black : Theme.accentYellow)
                                    }
                                    Text(s.displayName)
                                        .font(Theme.inter(14))
                                        .foregroundColor(species == s ? Theme.accentYellow : .secondary)
                                }
                                .onTapGesture { species = s }
                            }
                        }
                        .padding(.horizontal)
                    }

                    // Название и количество
                    VStack(spacing: 20) {
                        FloatingTextFieldBatch(placeholder: "Batch Name", text: $name)
                        EggCounter(count: $eggCount)
                        DateSelector(date: $layDate)
                    }
                    .padding(.horizontal)

                    // Кнопка создания
                    Button {
                        createBatch()
                    } label: {
                        Text("Start Incubation")
                            .font(Theme.nunito(20, weight: .bold))
                            .frame(maxWidth: .infinity)
                            .padding(18)
                            .background(name.isEmpty ? Theme.card : Theme.accentYellow)
                            .foregroundColor(name.isEmpty ? .secondary : .black)
                            .cornerRadius(20)
                    }
                    .disabled(name.isEmpty)
                    .padding(.horizontal)
                    .padding(.bottom, 40)
                }
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationBarHidden(true)
        }
    }

    private func createBatch() {
        let preset = IncubationPreset.default[species]!
        let batch = Batch(
            name: name.isEmpty ? "\(species.displayName) Batch" : name,
            species: species,
            startDate: layDate,
            totalEggs: eggCount,
            preset: preset
        )
        store.addBatch(batch)
        dismiss()
    }
}

// Мини-компоненты для красоты
struct FloatingTextFieldBatch: View {
    let placeholder: String
    @Binding var text: String

    var body: some View {
        TextField(placeholder, text: $text)
            .font(Theme.nunito(20))
            .padding(20)
            .background(Theme.card)
            .cornerRadius(16)
            .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Theme.accentYellow.opacity(0.3), lineWidth: 1))
    }
}

struct EggCounter: View {
    @Binding var count: Int

    var body: some View {
        HStack {
            Text("Eggs")
                .font(Theme.nunito(20, weight: .semibold))
            Spacer()
            HStack(spacing: 20) {
                Button { if count > 1 { count -= 1 } } label: { Image(systemName: "minus.circle.fill").font(.title) }
                Text("\(count)")
                    .font(Theme.nunito(32, weight: .bold))
                    .frame(minWidth: 80)
                Button { count += 1 } label: { Image(systemName: "plus.circle.fill").font(.title) }
            }
            .foregroundColor(Theme.accentYellow)
        }
        .padding(20)
        .background(Theme.card)
        .cornerRadius(16)
    }
}

struct DateSelector: View {
    @Binding var date: Date

    var body: some View {
        DatePicker("Lay Date", selection: $date, displayedComponents: .date)
            .datePickerStyle(.compact)
            .font(Theme.nunito(20))
            .padding(20)
            .background(Theme.card)
            .cornerRadius(16)
    }
}
