import SwiftUI

struct VoiceIntelligenceHistoryView: View {
    let logs: [SessionFeatureLog]
    let circadian: CircadianProfile?
    let sessionCount: Int

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                ScoreHistoryGraph(logs: logs)
                if sessionCount >= 5 { DimensionRadarChart(logs: logs) }
                if sessionCount >= 20, let circadian, circadian.isReady {
                    CircadianClockWidget(profile: circadian)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)
        }
        .background(NoiseBackground())
    }
}

struct ScoreHistoryGraph: View {
    let logs: [SessionFeatureLog]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("VERLAUF")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.klunaMuted)
                .tracking(1.2)

            GeometryReader { geo in
                let width = geo.size.width
                let height: CGFloat = 160
                let recent = Array(logs.suffix(30))
                let scores = recent.compactMap { $0.scoreOverall }
                let minY = max(0, (scores.min() ?? 0) - 10)
                let maxY = min(100, (scores.max() ?? 100) + 10)
                let rangeY = max(1.0, maxY - minY)

                ZStack {
                    ForEach([25, 50, 75], id: \.self) { line in
                        let y = height - (height * CGFloat(Double(line) - minY) / CGFloat(rangeY))
                        Path { path in
                            path.move(to: CGPoint(x: 0, y: y))
                            path.addLine(to: CGPoint(x: width, y: y))
                        }
                        .stroke(Color.white.opacity(0.04), lineWidth: 1)
                    }
                    Path { path in
                        for (i, log) in recent.enumerated() {
                            guard let score = log.scoreOverall else { continue }
                            let x = width * CGFloat(i) / CGFloat(max(1, recent.count - 1))
                            let y = height - (height * CGFloat(score - minY) / CGFloat(rangeY))
                            if i == 0 { path.move(to: CGPoint(x: x, y: y)) } else { path.addLine(to: CGPoint(x: x, y: y)) }
                        }
                    }
                    .stroke(Color.white.opacity(0.2), style: StrokeStyle(lineWidth: 1.5, lineCap: .round))

                    Path { path in
                        for (i, log) in recent.enumerated() {
                            guard let score = log.scoreOverall else { continue }
                            let x = width * CGFloat(i) / CGFloat(max(1, recent.count - 1))
                            let y = height - (height * CGFloat(score - minY) / CGFloat(rangeY))
                            if i == 0 { path.move(to: CGPoint(x: x, y: y)) } else { path.addLine(to: CGPoint(x: x, y: y)) }
                        }
                        path.addLine(to: CGPoint(x: width, y: height))
                        path.addLine(to: CGPoint(x: 0, y: height))
                        path.closeSubpath()
                    }
                    .fill(
                        LinearGradient(
                            colors: [KlunaColors.accent.opacity(0.12), KlunaColors.accent.opacity(0.02), Color.clear],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                    ForEach(Array(recent.enumerated()), id: \.offset) { i, log in
                        if let score = log.scoreOverall {
                            let x = width * CGFloat(i) / CGFloat(max(1, recent.count - 1))
                            let y = height - (height * CGFloat(score - minY) / CGFloat(rangeY))
                            Circle()
                                .fill(stateColor(log.vocalState))
                                .frame(width: 8, height: 8)
                                .position(x: x, y: y)
                        }
                    }
                }
            }
            .frame(height: 160)

            HStack(spacing: 12) {
                stateLegendDot(color: .stateEnergized, label: "Energetisch")
                stateLegendDot(color: .stateFocused, label: "Fokussiert")
                stateLegendDot(color: .stateTense, label: "Angespannt")
                stateLegendDot(color: .stateTired, label: "Müde")
                stateLegendDot(color: .stateRelaxed, label: "Entspannt")
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color.white.opacity(0.04)))
    }

    private func stateColor(_ state: String?) -> Color {
        switch state {
        case "energetisch": return .stateEnergized
        case "fokussiert": return .stateFocused
        case "angespannt": return .stateTense
        case "muede", "müde": return .stateTired
        case "entspannt": return .stateRelaxed
        default: return Color.white.opacity(0.3)
        }
    }

    private func stateLegendDot(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text(label)
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(.klunaMuted)
        }
    }
}

struct DimensionRadarChart: View {
    let logs: [SessionFeatureLog]
    private let dimensions = ["Confidence", "Energy", "Tempo", "Gelassenheit", "Charisma"]
    private let angleStep = 360.0 / 5.0

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("STIMM-PROFIL")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.klunaMuted)
                .tracking(1.2)

            GeometryReader { geo in
                let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
                let radius = min(geo.size.width, geo.size.height) / 2 - 30
                ZStack {
                    ForEach([0.25, 0.5, 0.75, 1.0], id: \.self) { scale in
                        radarPath(values: [1, 1, 1, 1, 1].map { $0 * scale }, center: center, radius: radius)
                            .stroke(Color.white.opacity(0.05), lineWidth: 1)
                    }
                    ForEach(0..<5, id: \.self) { i in
                        let angle = Angle.degrees(Double(i) * angleStep - 90)
                        Path { path in
                            path.move(to: center)
                            path.addLine(to: pointOnCircle(center: center, radius: radius, angle: angle))
                        }
                        .stroke(Color.white.opacity(0.05), lineWidth: 1)
                    }
                    let avgValues = averageScores()
                    radarPath(values: avgValues, center: center, radius: radius).fill(Color.white.opacity(0.04))
                    radarPath(values: avgValues, center: center, radius: radius).stroke(Color.white.opacity(0.15), lineWidth: 1)
                    let latestValues = latestScores()
                    radarPath(values: latestValues, center: center, radius: radius)
                        .fill(LinearGradient(colors: [Color.stateEnergized.opacity(0.15), Color.stateRelaxed.opacity(0.15)], startPoint: .top, endPoint: .bottom))
                    radarPath(values: latestValues, center: center, radius: radius)
                        .stroke(LinearGradient(colors: [Color.stateEnergized, Color.stateRelaxed], startPoint: .top, endPoint: .bottom), lineWidth: 1.5)
                    radarPath(values: latestValues, center: center, radius: radius)
                        .fill(KlunaColors.accent.opacity(0.08))
                        .blur(radius: 12)
                    ForEach(Array(dimensions.enumerated()), id: \.offset) { i, dim in
                        let angle = Angle.degrees(Double(i) * angleStep - 90)
                        let labelPoint = pointOnCircle(center: center, radius: radius + 18, angle: angle)
                        Text(dim)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.klunaSecondary)
                            .position(labelPoint)
                    }
                }
            }
            .frame(height: 220)

            HStack(spacing: 12) {
                HStack(spacing: 4) {
                    Circle().fill(Color.white.opacity(0.35)).frame(width: 6, height: 6)
                    Text("30 Tage")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.klunaMuted)
                }
                HStack(spacing: 4) {
                    Circle().fill(Color.stateEnergized).frame(width: 6, height: 6)
                    Text("Letzte Session")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.klunaMuted)
                }
                Spacer()
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color.white.opacity(0.04)))
    }

    private func latestScores() -> [Double] {
        guard let last = logs.last else { return [0, 0, 0, 0, 0] }
        return [
            (last.scoreConfidence ?? 0) / 100,
            (last.scoreEnergy ?? 0) / 100,
            (last.scoreTempo ?? 0) / 100,
            (last.scoreStability ?? 0) / 100,
            (last.scoreCharisma ?? 0) / 100
        ]
    }

    private func averageScores() -> [Double] {
        let recent = Array(logs.suffix(30))
        guard !recent.isEmpty else { return [0, 0, 0, 0, 0] }
        let n = Double(recent.count)
        return [
            recent.compactMap { $0.scoreConfidence }.reduce(0, +) / n / 100,
            recent.compactMap { $0.scoreEnergy }.reduce(0, +) / n / 100,
            recent.compactMap { $0.scoreTempo }.reduce(0, +) / n / 100,
            recent.compactMap { $0.scoreStability }.reduce(0, +) / n / 100,
            recent.compactMap { $0.scoreCharisma }.reduce(0, +) / n / 100
        ]
    }

    private func radarPath(values: [Double], center: CGPoint, radius: CGFloat) -> Path {
        Path { path in
            for (i, value) in values.enumerated() {
                let angle = Angle.degrees(Double(i) * angleStep - 90)
                let point = pointOnCircle(center: center, radius: radius * CGFloat(value), angle: angle)
                if i == 0 { path.move(to: point) } else { path.addLine(to: point) }
            }
            path.closeSubpath()
        }
    }

    private func pointOnCircle(center: CGPoint, radius: CGFloat, angle: Angle) -> CGPoint {
        CGPoint(
            x: center.x + radius * CGFloat(cos(angle.radians)),
            y: center.y + radius * CGFloat(sin(angle.radians))
        )
    }
}

struct CircadianClockWidget: View {
    let profile: CircadianProfile

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("DEIN STIMM-RHYTHMUS")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.klunaMuted)
                .tracking(1.2)

            HStack(spacing: 2) {
                ForEach(profile.slots, id: \.hourRange) { slot in
                    VStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(slotColor(slot))
                            .frame(height: 32)
                            .overlay(
                                slot.isOptimal
                                ? RoundedRectangle(cornerRadius: 4).stroke(Color.stateEnergized, lineWidth: 2)
                                : nil
                            )
                        Text(slot.hourRange.replacingOccurrences(of: "-", with: "\n"))
                            .font(.system(size: 8, weight: .medium))
                            .foregroundColor(.klunaMuted)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                }
            }

            if let recommendation = profile.recommendation {
                Text(recommendation)
                    .font(.system(size: 13))
                    .foregroundColor(.klunaSecondary)
                    .lineSpacing(3)
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color.white.opacity(0.04)))
    }

    private func slotColor(_ slot: CircadianSlot) -> Color {
        if slot.avgOverall >= 70 { return Color.stateEnergized.opacity(0.5) }
        if slot.avgOverall >= 55 { return Color.klunaAmber.opacity(0.3) }
        return Color.klunaRed.opacity(0.2)
    }
}
