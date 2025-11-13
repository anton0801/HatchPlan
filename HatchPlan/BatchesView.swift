import SwiftUI

struct BatchesView: View {
    @EnvironmentObject var store: AppStore

    var body: some View {
        NavigationView {
            List {
                ForEach(store.batches) { batch in
                    NavigationLink(destination: BatchDetailView(batch: batch)) {
                        HStack {
                            Image(systemName: batch.species.iconName)
                                .foregroundColor(Theme.accentYellow)
                            VStack(alignment: .leading) {
                                Text(batch.name)
                                Text("Day \(store.day(for: batch))/\(batch.totalDays)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Batches")
        }
    }
}

#Preview {
    BatchesView()
}
