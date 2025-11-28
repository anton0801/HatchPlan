import SwiftUI
import WebKit
import Combine

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
