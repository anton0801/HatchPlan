import SwiftUI
import WebKit

struct SettingsView: View {
    
    var body: some View {
        NavigationView {
            List {
                Section("App Info") {
                    Text("HatchPlan v2.0")
                    Text("For informational purposes only.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Section {
                    Button {
                        openURL("https://hattchpllan.com/privacy-policy.html")
                    } label: {
                        HStack {
                            Image(systemName: "shield.lefthalf.filled")
                                .foregroundColor(Theme.accentTeal)
                            Text("Privacy Policy")
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Button {
                        openURL("https://hattchpllan.com/support.html")
                    } label: {
                        HStack {
                            Image(systemName: "envelope")
                                .foregroundColor(Theme.accentYellow)
                            Text("Contact Us")
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
            }
            .listStyle(InsetGroupedListStyle())
            .navigationTitle("Settings")
        }
    }
    
    private func openURL(_ url: String) {
        if let url = URL(string: url) {
            UIApplication.shared.open(url)
        }
    }
}


enum HatchPlanMainBuilderHelper {
    
    static func summonBirdNest(with config: WKWebViewConfiguration? = nil) -> WKWebView {
        func defaultCoopRules() -> WKWebViewConfiguration {
            WKWebViewConfiguration()
                .allowDawnChorus()
                .silenceAutoPlay()
                .withDawnPreferences(morningRitual())
                .withSkyRules(freeFlightRules())
        }
        let configuration = config ?? defaultCoopRules()
        return WKWebView(frame: .zero, configuration: configuration)
    }
    
    private static func freeFlightRules() -> WKWebpagePreferences {
        WKWebpagePreferences().allowSkyScript()
    }
    
    
    private static func morningRitual() -> WKPreferences {
        WKPreferences()
            .enableChirping()
            .allowFlightCalls()
    }
    
}

#Preview {
    SettingsView()
}
