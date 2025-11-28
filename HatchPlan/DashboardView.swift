import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var store: AppStore
    @State private var showAddBatch = false

    var activeBatches: [Batch] {
        store.batches.filter { !$0.isFinished }
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    if activeBatches.isEmpty {
                        EmptyStateView(message: "No active batches", action: { showAddBatch = true })
                    } else {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 16) {
                                ForEach(activeBatches) { batch in
                                    BatchCard(batch: batch)
                                        .padding(.horizontal)
                                }
                            }
                            .padding(.horizontal)
                        }
                    }

                    TodayTasksView()
                }
                .padding(.vertical)
            }
            .navigationTitle("HatchPlan")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showAddBatch = true } label: {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(Theme.accentYellow)
                            .font(.title2)
                    }
                }
            }
            .sheet(isPresented: $showAddBatch) {
                BatchWizardView()
            }
        }
    }
}

struct EmptyStateView: View {
    let message: String
    let action: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "tray")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            Text(message)
                .font(Theme.inter(18))
            Button("Add Batch", action: action)
                .buttonStyle(BigYellowButton())
        }
        .frame(maxWidth: .infinity)
        .padding()
    }
}

struct CircularProgressView: View {
    let progress: Double

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.gray.opacity(0.3), lineWidth: 6)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(Theme.accentYellow, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut, value: progress)
        }
    }
}

//struct BatchCard: View {
//    let batch: Batch
//    @EnvironmentObject var store: AppStore
//
//    var body: some View {
//        VStack(alignment: .leading, spacing: 12) {
//            HStack {
//                Image(systemName: batch.species.iconName)
//                    .font(.title)
//                    .foregroundColor(Theme.accentYellow)
//                VStack(alignment: .leading) {
//                    Text(batch.name).font(Theme.nunito(20))
//                    Text("\(batch.species.displayName) • Day \(store.day(for: batch))/\(batch.totalDays)")
//                        .font(Theme.inter(14))
//                        .foregroundColor(.secondary)
//                }
//                Spacer()
//                CircularProgressView(progress: store.progress(for: batch))
//                    .frame(width: 50, height: 50)
//            }
//
//            let status = store.status(for: batch)
//            Text(status.text)
//                .font(.caption).bold()
//                .padding(.horizontal, 8).padding(.vertical, 4)
//                .background(status.color.opacity(0.2))
//                .foregroundColor(status.color)
//                .cornerRadius(8)
//        }
//        .padding()
//        .background(Theme.card)
//        .cornerRadius(16)
//        .shadow(radius: 8)
//    }
//}

struct TodayTasksView: View {
    @EnvironmentObject var store: AppStore

    var todayTasks: [IncubationTask] {
        let today = Calendar.current.startOfDay(for: Date())
        return store.tasks.filter {
            Calendar.current.isDate($0.dueAt, inSameDayAs: today) && $0.status == .pending
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Today's Tasks")
                .font(Theme.nunito(22))
                .padding(.horizontal)

            if todayTasks.isEmpty {
                Text("All done!")
                    .foregroundColor(Theme.successLime)
                    .padding()
            } else {
                ForEach(todayTasks) { task in
                    HStack {
                        Image(systemName: task.type == .turn ? "arrow.2.circlepath" : "checkmark.circle")
                            .foregroundColor(Theme.accentYellow)
                        Text(task.type.title)
                        Spacer()
                        Button("Done") {
                            store.completeTask(task)
                        }
                        .foregroundColor(Theme.successLime)
                    }
                    .padding()
                    .background(Theme.card)
                    .cornerRadius(12)
                    .padding(.horizontal)
                }
            }
        }
    }
}

struct HatchPlanMainView: View {
    
    @State private var currentHatching = ""
    
    var body: some View {
        ZStack {
            if let url = URL(string: currentHatching) {
                HatchMainViewContainer(hatchPlanContainer: url)
                    .ignoresSafeArea(.keyboard, edges: .bottom)
            }
        }
        .preferredColorScheme(.dark)
        .onAppear(perform: checkMorningCall)
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("LoadTempUrl"))) { _ in
            if let call = UserDefaults.standard.string(forKey: "temp_url"), !call.isEmpty {
                currentHatching = call
                UserDefaults.standard.removeObject(forKey: "temp_url")
            }
        }
    }
    
    private func checkMorningCall() {
        let early = UserDefaults.standard.string(forKey: "temp_url")
        let regular = UserDefaults.standard.string(forKey: "saved_trail") ?? ""
        currentHatching = early ?? regular
        
        if early != nil {
            UserDefaults.standard.removeObject(forKey: "temp_url")
        }
    }
    
}

struct BatchWizardView: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) var dismiss

    @State private var step = 0
    @State private var species: Species = .chicken
    @State private var name = ""
    @State private var eggCount = 12
    @State private var startDate = Date()

    var body: some View {
        NavigationView {
            Form {
                if step == 0 { SpeciesStep(species: $species) }
                if step == 1 { NameEggsStep(name: $name, eggCount: $eggCount) }
                if step == 2 { DateStep(date: $startDate) }
                if step == 3 { SummaryStep(species: species, name: name, eggCount: eggCount, date: startDate) }
            }
            .navigationTitle("New Batch")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    if step < 3 {
                        Button("Next") { step += 1 }
                    } else {
                        Button("Done") { createBatch(); dismiss() }
                    }
                }
            }
        }
    }

    func createBatch() {
        let preset = IncubationPreset.default[species]!
        let batch = Batch(name: name, species: species, startDate: startDate, totalEggs: eggCount, preset: preset)
        store.addBatch(batch)
    }
}

struct SpeciesStep: View {
    @Binding var species: Species
    var body: some View {
        Section("Species") {
            ForEach(Species.allCases, id: \.self) { s in
                HStack {
                    Image(systemName: s.iconName)
                    Text(s.displayName)
                    Spacer()
                    if species == s { Image(systemName: "checkmark") }
                }
                .contentShape(Rectangle())
                .onTapGesture { species = s }
            }
        }
    }
}

struct NameEggsStep: View {
    @Binding var name: String
    @Binding var eggCount: Int
    var body: some View {
        Section("Details") {
            TextField("Batch Name", text: $name)
            Stepper("Eggs: \(eggCount)", value: $eggCount, in: 1...200)
        }
    }
}

struct DateStep: View {
    @Binding var date: Date
    var body: some View {
        Section("Start Date") {
            DatePicker("Lay Date", selection: $date, displayedComponents: .date)
        }
    }
}

struct SummaryStep: View {
    let species: Species
    let name: String
    let eggCount: Int
    let date: Date
    var body: some View {
        Section("Summary") {
            Text("Name: \(name)")
            Text("Species: \(species.displayName)")
            Text("Eggs: \(eggCount)")
            Text("Start: \(date, style: .date)")
        }
    }
}
