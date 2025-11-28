import SwiftUI
import WebKit

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
