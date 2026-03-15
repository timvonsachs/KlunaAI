import SwiftUI
import UIKit

struct DataExportView: View {
    @State private var logCount = 0
    @State private var fileSize = "0 KB"
    @State private var showShareSheet = false
    @State private var showClearConfirmation = false
    @State private var analytics: LogAnalytics = .empty
    @State private var missingRates: [(String, Double)] = []
    @State private var showInspector = false

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading) {
                    Text("Feature Logs")
                        .font(KlunaFont.heading(16))
                        .foregroundColor(.klunaPrimary)
                    Text("\(logCount) Sessions - \(fileSize)")
                        .font(KlunaFont.caption(12))
                        .foregroundColor(.klunaMuted)
                }
                Spacer()
            }

            if logCount < 500 {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("ML-Readiness")
                            .font(KlunaFont.caption(12))
                            .foregroundColor(.klunaMuted)
                        Spacer()
                        Text("\(logCount)/500")
                            .font(KlunaFont.caption(12))
                            .foregroundColor(.klunaMuted)
                    }

                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4).fill(Color.klunaSurfaceLight)
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.purple.opacity(0.7))
                                .frame(width: geo.size.width * min(1, CGFloat(logCount) / 500.0))
                        }
                    }
                    .frame(height: 8)

                    Text("500 Sessions = genug Daten für ein personalisiertes ML-Modell")
                        .font(KlunaFont.caption(11))
                        .foregroundColor(.klunaMuted)
                }
            } else {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.klunaGreen)
                    Text("Genug Daten für ML-Training!")
                        .font(KlunaFont.caption(12))
                        .foregroundColor(.klunaGreen)
                }
            }

            Button(action: { showShareSheet = true }) {
                HStack {
                    Image(systemName: "square.and.arrow.up")
                    Text("Logs exportieren")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue.opacity(0.2))
                .cornerRadius(12)
            }
            .disabled(logCount == 0)
            .sheet(isPresented: $showShareSheet) {
                ShareSheet(items: [FeatureLogger.shared.getLogFilePath()])
            }

            Button(action: { showClearConfirmation = true }) {
                HStack {
                    Image(systemName: "trash")
                    Text("Logs löschen")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.red.opacity(0.1))
                .cornerRadius(12)
                .foregroundColor(.red)
            }
            .disabled(logCount == 0)
            .alert("Logs löschen?", isPresented: $showClearConfirmation) {
                Button("Abbrechen", role: .cancel) {}
                Button("Löschen", role: .destructive) {
                    FeatureLogger.shared.clearAllLogs()
                    refreshStats()
                }
            } message: {
                Text("Alle \(logCount) Feature-Logs werden unwiderruflich gelöscht.")
            }

            if logCount > 0 {
                VStack(spacing: 10) {
                    Button(action: {
                        withAnimation(.easeOut(duration: 0.2)) {
                            showInspector.toggle()
                        }
                    }) {
                        HStack {
                            Image(systemName: "chart.bar.doc.horizontal")
                                .foregroundColor(.klunaAccent)
                            Text("Log Inspector")
                                .font(KlunaFont.heading(14))
                                .foregroundColor(.klunaPrimary)
                            Spacer()
                            Image(systemName: showInspector ? "chevron.up" : "chevron.down")
                                .foregroundColor(.klunaMuted)
                        }
                    }
                    .buttonStyle(.plain)

                    if showInspector {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                inspectorPill(title: "Avg", value: String(format: "%.1f", analytics.avgScore))
                                inspectorPill(title: "Best", value: String(format: "%.0f", analytics.bestScore))
                                inspectorPill(title: "Delta", value: String(format: "%+.1f", analytics.scoreImprovement))
                            }

                            Text("Top-Korrelationen")
                                .font(KlunaFont.caption(12))
                                .foregroundColor(.klunaMuted)
                            ForEach(Array(analytics.topCorrelations.prefix(5)), id: \.feature) { item in
                                HStack {
                                    Text(item.feature)
                                        .font(KlunaFont.caption(12))
                                        .foregroundColor(.klunaSecondary)
                                    Spacer()
                                    Text(String(format: "%.2f", item.correlation))
                                        .font(KlunaFont.caption(12))
                                        .foregroundColor(item.correlation >= 0 ? .klunaGreen : .klunaOrange)
                                }
                            }

                            Text("Data Quality (Missing-Rate)")
                                .font(KlunaFont.caption(12))
                                .foregroundColor(.klunaMuted)
                                .padding(.top, 4)
                            ForEach(Array(missingRates.prefix(6)), id: \.0) { item in
                                HStack {
                                    Text(item.0)
                                        .font(KlunaFont.caption(12))
                                        .foregroundColor(.klunaSecondary)
                                    Spacer()
                                    Text("\(Int((item.1 * 100).rounded()))%")
                                        .font(KlunaFont.caption(12))
                                        .foregroundColor(item.1 <= 0.2 ? .klunaGreen : (item.1 <= 0.5 ? .klunaAmber : .klunaRed))
                                }
                            }
                        }
                        .transition(.opacity)
                    }
                }
                .padding(12)
                .background(Color.klunaSurfaceLight.opacity(0.6))
                .cornerRadius(12)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.klunaSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.klunaBorder, lineWidth: 1)
                )
        )
        .onAppear(perform: refreshStats)
    }

    private func refreshStats() {
        logCount = FeatureLogger.shared.getLogCount()
        fileSize = FeatureLogger.shared.getLogFileSize()
        let logs = FeatureLogger.shared.loadAllLogs()
        analytics = FeatureAnalytics.analyze(logs: logs)
        missingRates = calculateMissingRates(logs: logs)
    }

    private func calculateMissingRates(logs: [SessionFeatureLog]) -> [(String, Double)] {
        guard !logs.isEmpty else { return [] }
        let total = Double(logs.count)
        let checks: [(String, (SessionFeatureLog) -> Bool)] = [
            ("loudnessRMS", { $0.loudnessRMS != nil }),
            ("f0Mean", { $0.f0Mean != nil }),
            ("f0RangeST", { $0.f0RangeST != nil }),
            ("jitter", { $0.jitter != nil }),
            ("hnr", { $0.hnr != nil }),
            ("speechRate", { $0.speechRate != nil }),
            ("presenceScore", { $0.presenceScore != nil }),
            ("intentionalityScore", { $0.intentionalityScore != nil }),
            ("scoreOverall", { $0.scoreOverall != nil }),
            ("profileName", { $0.profileName != nil }),
        ]
        return checks.map { (name, hasValue) in
            let filled = Double(logs.filter(hasValue).count)
            return (name, 1.0 - (filled / total))
        }
        .sorted { $0.1 < $1.1 }
    }

    @ViewBuilder
    private func inspectorPill(title: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(title)
                .font(KlunaFont.caption(10))
                .foregroundColor(.klunaMuted)
            Text(value)
                .font(KlunaFont.caption(12))
                .foregroundColor(.klunaPrimary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .background(Color.klunaSurface)
        .cornerRadius(8)
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
