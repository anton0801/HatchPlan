import SwiftUI
import UniformTypeIdentifiers
import WebKit

struct ReportsView: View {
    @EnvironmentObject var store: AppStore

    var body: some View {
        NavigationView {
            ScrollView {
                LazyVStack(spacing: 16) {
                    if store.batches.isEmpty {
                        EmptyReportState()
                    } else {
                        ForEach(store.batches) { batch in
                            ReportCard(batch: batch)
                                .padding(.horizontal)
                        }
                    }
                }
                .padding(.vertical)
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("Reports")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

struct EmptyReportState: View {
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "chart.pie")
                .font(.system(size: 80))
                .foregroundColor(.secondary.opacity(0.5))
            
            Text("No Reports Yet")
                .font(Theme.nunito(28))
            
            Text("Complete a batch to see success rates, trends, and exportable reports.")
                .font(Theme.inter(16))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 100)
    }
}

// MARK: - Report Card
struct ReportCard: View {
    let batch: Batch
    @EnvironmentObject var store: AppStore
    @State private var showDetail = false

    private var successRate: Double {
        batch.totalEggs > 0 ? Double(batch.hatchedCount) / Double(batch.totalEggs) * 100 : 0
    }

    private var statusColor: Color {
        successRate >= 80 ? Theme.successLime :
        successRate >= 60 ? Theme.accentYellow : Theme.alertCoral
    }

    var body: some View {
        Button {
            showDetail = true
        } label: {
            VStack(alignment: .leading, spacing: 16) {
                // Header
                HStack {
                    Image(systemName: batch.species.iconName)
                        .font(.title2)
                        .foregroundColor(Theme.accentYellow)
                        .frame(width: 44, height: 44)
                        .background(Theme.card)
                        .clipShape(Circle())

                    VStack(alignment: .leading, spacing: 4) {
                        Text(batch.name)
                            .font(Theme.nunito(20))
                            .foregroundColor(.white)
                        
                        Text("\(batch.species.displayName) • \(batch.totalDays) days")
                            .font(Theme.inter(14))
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    
                    // Success Badge
                    Text("\(Int(successRate))%")
                        .font(Theme.nunito(24, weight: .bold))
                        .foregroundColor(statusColor)
                }

                // Progress Bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(Color.white.opacity(0.1))
                            .frame(height: 8)
                            .cornerRadius(4)
                        
                        Rectangle()
                            .fill(statusColor)
                            .frame(width: geo.size.width * (successRate / 100), height: 8)
                            .cornerRadius(4)
                    }
                }
                .frame(height: 8)

                // Stats Row
                HStack {
                    StatItem(label: "Hatched", value: "\(batch.hatchedCount)")
                    Spacer()
                    StatItem(label: "Total", value: "\(batch.totalEggs)")
                    Spacer()
                    StatItem(label: "Day", value: "\(store.day(for: batch))")
                }
            }
            .padding(20)
            .background(Theme.card)
            .cornerRadius(20)
            .shadow(color: .black.opacity(0.3), radius: 12, x: 0, y: 6)
        }
        .buttonStyle(PlainButtonStyle())
        .sheet(isPresented: $showDetail) {
            BatchReportView(batch: batch)
                .environmentObject(store)
        }
    }
}


struct HatchMainViewContainer: UIViewRepresentable {
    let hatchPlanContainer: URL
    
    @StateObject private var contentContainer = HatchiPlanMainConverterandContainerMainer()
    
    func makeCoordinator() -> DelegateForHathcingPlanMainView {
        DelegateForHathcingPlanMainView(for: contentContainer)
    }
    
    func makeUIView(context: Context) -> WKWebView {
        contentContainer.setUpAllHatches()
        contentContainer.mainHatchView.uiDelegate = context.coordinator
        contentContainer.mainHatchView.navigationDelegate = context.coordinator
        
        contentContainer.restoreSavedDataOfPugs()
        contentContainer.mainHatchView.load(URLRequest(url: hatchPlanContainer))
        
        return contentContainer.mainHatchView
    }
    
    func updateUIView(_ uiView: WKWebView, context: Context) {}
}


struct StatItem: View {
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(Theme.nunito(18, weight: .bold))
            Text(label)
                .font(Theme.inter(12))
                .foregroundColor(.secondary)
        }
    }
}

#Preview {
    ReportsView()
        .environmentObject(AppStore())
}

struct BatchReportView: View {
    let batch: Batch
    @EnvironmentObject var store: AppStore
    @State private var showShare = false
    @State private var exportURL: URL?

    @State private var readings: [SensorReading] = []

    private var successRate: Double {
        batch.totalEggs > 0 ? Double(batch.hatchedCount) / Double(batch.totalEggs) * 100 : 0
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 12) {
                        Image(systemName: batch.species.iconName)
                            .font(.system(size: 60))
                            .foregroundColor(Theme.accentYellow)
                        
                        Text(batch.name)
                            .font(Theme.nunito(32))
                        
                        Text("\(Int(successRate))% Success Rate")
                            .font(Theme.nunito(24, weight: .bold))
                            .foregroundColor(successRate >= 80 ? .green : successRate >= 60 ? .yellow : .red)
                    }

                    // Summary Cards
                    HStack(spacing: 16) {
                        SummaryCard(title: "Hatched", value: "\(batch.hatchedCount)", color: Theme.successLime)
                        SummaryCard(title: "Total Eggs", value: "\(batch.totalEggs)", color: Theme.accentTeal)
                    }
                    .padding(.horizontal)

                    // Temperature Chart
                    if !readings.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Temperature Trend")
                                .font(Theme.nunito(20))
                                .padding(.horizontal)
                            
                            TemperatureChart(readings: readings)
                                .frame(height: 200)
                                .padding(.horizontal)
                        }
                    }
                }
                .padding(.vertical)
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("Report")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showShare) {
                if let url = exportURL {
                    ShareSheet(activityItems: [url])
                }
            }
        }
    }

}

// MARK: - Summary Card
struct SummaryCard: View {
    let title: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Text(value)
                .font(Theme.nunito(28, weight: .bold))
            Text(title)
                .font(Theme.inter(14))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Theme.card)
        .cornerRadius(16)
    }
}

struct BigActionButton: View {
    let title: String
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .font(.title2)
                Text(title)
                    .font(Theme.nunito(18))
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Theme.accentYellow)
            .foregroundColor(.black)
            .cornerRadius(16)
            .shadow(radius: 8)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Temperature Chart (Simple Line)
struct TemperatureChart: View {
    let readings: [SensorReading]

    var body: some View {
        GeometryReader { geo in
            let values = readings.map { $0.temp }
            let minV = values.min() ?? 37.0
            let maxV = values.max() ?? 38.0
            let range = maxV - minV == 0 ? 1 : maxV - minV

            Path { path in
                for (index, reading) in readings.enumerated() {
                    let x = CGFloat(index) / CGFloat(readings.count - 1) * geo.size.width
                    let y = CGFloat((maxV - reading.temp) / range) * geo.size.height
                    if index == 0 {
                        path.move(to: CGPoint(x: x, y: y))
                    } else {
                        path.addLine(to: CGPoint(x: x, y: y))
                    }
                }
            }
            .stroke(Theme.accentYellow, lineWidth: 3)
        }
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
    }
}

// MARK: - Share Sheet
struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

struct ActivityView: UIViewControllerRepresentable {
    var activityItems: [Any]
    var applicationActivities: [UIActivity]? = nil

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: applicationActivities)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

struct PDFExporter {
    static func export(batch: Batch, readings: [SensorReading]) -> URL {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium

        let pdfURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(batch.name).pdf")
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 595, height: 842))

        let data = renderer.pdfData { ctx in
            ctx.beginPage()
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont(name: "Nunito-Bold", size: 24) ?? UIFont.systemFont(ofSize: 24),
                .foregroundColor: UIColor.white
            ]
            "HatchPlan Report".draw(at: CGPoint(x: 40, y: 40), withAttributes: attributes)
            "\(batch.name) – \(batch.species.displayName)".draw(at: CGPoint(x: 40, y: 80), withAttributes: attributes)
        }

        try? data.write(to: pdfURL)
        return pdfURL
    }
}
