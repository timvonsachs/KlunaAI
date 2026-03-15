import SwiftUI

struct VoiceDNARadarView: View {
    let profile: VoiceDNAProfile

    var body: some View {
        KlunaCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("VOICE DNA")
                        .font(KlunaFonts.upperLabel(10))
                        .foregroundColor(KlunaColors.textMuted)
                        .tracking(1.2)
                    Spacer()
                    Text("Dominant: \(profile.dominantQuadrant)")
                        .font(KlunaFonts.label(11))
                        .foregroundColor(KlunaColors.accent)
                }

                GeometryReader { geo in
                    let side = min(geo.size.width, geo.size.height)
                    let center = CGPoint(x: side / 2, y: side / 2)
                    let radius = side * 0.38

                    ZStack {
                        ForEach([0.25, 0.5, 0.75, 1.0], id: \.self) { factor in
                            diamond(center: center, radius: radius * factor)
                                .stroke(Color.white.opacity(0.10), lineWidth: 1)
                        }

                        axisLine(center: center, end: CGPoint(x: center.x, y: center.y - radius))
                        axisLine(center: center, end: CGPoint(x: center.x + radius, y: center.y))
                        axisLine(center: center, end: CGPoint(x: center.x, y: center.y + radius))
                        axisLine(center: center, end: CGPoint(x: center.x - radius, y: center.y))

                        dnaPolygon(center: center, radius: radius)
                            .fill(KlunaColors.accent.opacity(0.20))
                        dnaPolygon(center: center, radius: radius)
                            .stroke(KlunaColors.accent, lineWidth: 2)

                        label("Authority", value: profile.authority, point: CGPoint(x: center.x, y: center.y - radius - 20))
                        label("Charisma", value: profile.charisma, point: CGPoint(x: center.x + radius + 34, y: center.y))
                        label("Warmth", value: profile.warmth, point: CGPoint(x: center.x, y: center.y + radius + 20))
                        label("Composure", value: profile.composure, point: CGPoint(x: center.x - radius - 34, y: center.y))
                    }
                    .frame(width: side, height: side)
                }
                .frame(height: 260)

                Text(profile.description())
                    .font(KlunaFonts.body(13))
                    .foregroundColor(KlunaColors.textSecondary)
            }
        }
    }

    private func dnaPolygon(center: CGPoint, radius: CGFloat) -> Path {
        let points = [
            CGPoint(x: center.x, y: center.y - radius * CGFloat(profile.authority / 100)),
            CGPoint(x: center.x + radius * CGFloat(profile.charisma / 100), y: center.y),
            CGPoint(x: center.x, y: center.y + radius * CGFloat(profile.warmth / 100)),
            CGPoint(x: center.x - radius * CGFloat(profile.composure / 100), y: center.y),
        ]
        return Path { path in
            path.move(to: points[0])
            path.addLine(to: points[1])
            path.addLine(to: points[2])
            path.addLine(to: points[3])
            path.closeSubpath()
        }
    }

    private func diamond(center: CGPoint, radius: CGFloat) -> Path {
        Path { path in
            path.move(to: CGPoint(x: center.x, y: center.y - radius))
            path.addLine(to: CGPoint(x: center.x + radius, y: center.y))
            path.addLine(to: CGPoint(x: center.x, y: center.y + radius))
            path.addLine(to: CGPoint(x: center.x - radius, y: center.y))
            path.closeSubpath()
        }
    }

    private func axisLine(center: CGPoint, end: CGPoint) -> some View {
        Path { path in
            path.move(to: center)
            path.addLine(to: end)
        }
        .stroke(Color.white.opacity(0.12), lineWidth: 1)
    }

    @ViewBuilder
    private func label(_ title: String, value: Float, point: CGPoint) -> some View {
        let highlight = profile.dominantQuadrant == title
        VStack(spacing: 2) {
            Text(title)
                .font(KlunaFonts.label(11))
                .foregroundColor(highlight ? KlunaColors.accent : KlunaColors.textMuted)
            Text("\(Int(value))")
                .font(KlunaFonts.score(13))
                .foregroundColor(highlight ? KlunaColors.textPrimary : KlunaColors.textSecondary)
        }
        .position(point)
    }
}
