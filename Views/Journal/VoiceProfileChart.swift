import SwiftUI

struct VoiceProfileChart: View {
    let snapshots: [WeeklyVoiceSnapshot]
    let language: String

    var body: some View {
        VStack(alignment: .leading, spacing: KlunaSpacing.md) {
            HStack {
                Image(systemName: "waveform.path.ecg")
                    .font(.system(size: 14))
                    .foregroundColor(.klunaAccent)
                Text(language == "de" ? "Dein Stimmverlauf" : "Your Voice Profile")
                    .font(KlunaFont.heading(16))
                    .foregroundColor(.klunaPrimary)
            }

            if snapshots.isEmpty {
                Text(language == "de"
                    ? "Sprich täglich 60 Sekunden ins Journal und sieh wie sich deine Stimme entwickelt."
                    : "Speak 60 seconds daily into your journal and see how your voice evolves.")
                .font(KlunaFont.body(14))
                .foregroundColor(.klunaMuted)
                .lineSpacing(3)
            } else {
                HStack(alignment: .bottom, spacing: KlunaSpacing.sm) {
                    ForEach(snapshots) { snapshot in
                        VStack(spacing: 4) {
                            if let quadrant = snapshot.dominantQuadrant {
                                Text(quadrant.dot)
                                    .font(.system(size: 14))
                            }

                            VStack(spacing: 2) {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(energyColor(snapshot.avgEnergy))
                                    .frame(width: 32, height: max(8, CGFloat(snapshot.avgEnergy) * 80))
                                Circle()
                                    .fill(stabilityColor(snapshot.avgStability))
                                    .frame(width: 6, height: 6)
                            }

                            Text(snapshot.weekStart.shortWeekLabel)
                                .font(KlunaFont.caption(9))
                                .foregroundColor(.klunaMuted)
                            Text("\(snapshot.entryCount)x")
                                .font(KlunaFont.caption(8))
                                .foregroundColor(.klunaMuted.opacity(0.6))
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .frame(height: 120)

                HStack(spacing: KlunaSpacing.md) {
                    LegendItem(color: .klunaAccent, label: language == "de" ? "Energie" : "Energy")
                    LegendItem(color: .klunaGreen, label: language == "de" ? "Gelassenheit" : "Calmness")
                }
            }
        }
        .padding(KlunaSpacing.md)
        .background(Color.klunaSurface)
        .cornerRadius(KlunaRadius.card)
        .overlay(
            RoundedRectangle(cornerRadius: KlunaRadius.card)
                .stroke(Color.klunaBorder, lineWidth: 1)
        )
    }

    private func energyColor(_ energy: Double) -> Color {
        if energy > 0.55 { return .klunaGreen }
        if energy > 0.35 { return .klunaAccent }
        return .klunaAmber
    }

    private func stabilityColor(_ stability: Double) -> Color {
        if stability > 0.7 { return .klunaGreen }
        if stability > 0.4 { return .klunaAmber }
        return .klunaRed
    }
}

struct LegendItem: View {
    let color: Color
    let label: String

    var body: some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text(label).font(KlunaFont.caption(10)).foregroundColor(.klunaMuted)
        }
    }
}

extension Date {
    var shortWeekLabel: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd.MM"
        return formatter.string(from: self)
    }
}
