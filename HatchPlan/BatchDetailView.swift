import SwiftUI

struct BatchDetailView: View {
    let batch: Batch
    @EnvironmentObject var store: AppStore
    @State private var showAddReading = false

    var body: some View {
        List {
            Section("Progress") {
                HStack {
                    Text("Day \(store.day(for: batch))/\(batch.totalDays)")
                    Spacer()
                    CircularProgressView(progress: store.progress(for: batch))
                        .frame(width: 60, height: 60)
                }
            }

            Section("Actions") {
                Button("Mark Turn") { }
                Button("Add Reading") { showAddReading = true }
                Button("Add Note") { }
            }

            Section("Notes") {
                Text(batch.notes.isEmpty ? "No notes" : batch.notes)
            }
        }
        .navigationTitle(batch.name)
        .sheet(isPresented: $showAddReading) {
            Text("Add T°/RH")
        }
    }
}

