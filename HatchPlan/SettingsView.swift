import SwiftUI

struct SettingsView: View {
    var body: some View {
        NavigationView {
            Form {
                Section("App Info") {
                    Text("HatchPlan v1.0")
                    Text("For informational purposes only.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Settings")
        }
    }
}

#Preview {
    SettingsView()
}
