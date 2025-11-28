import SwiftUI
import WebKit

struct SettingsView: View {
    var body: some View {
        NavigationView {
            Form {
                Section("App Info") {
                    Text("HatchPlan v2.0")
                    Text("For informational purposes only.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Settings")
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
