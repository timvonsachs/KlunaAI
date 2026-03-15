import SwiftUI

struct BaselineProgressView: View {
    let progress: BaselineProgress
    let language: String

    @State private var animatedProgress: Double = 0
    @State private var showDetail = false

    var body: some View {
        VStack(spacing: KlunaSpacing.md) {
            Button(action: {
                withAnimation(KlunaAnimation.spring) { showDetail.toggle() }
            }) {
                HStack(spacing: KlunaSpacing.md) {
                    ZStack {
                        Circle()
                            .stroke(Color.klunaSurfaceLight, lineWidth: 4)
                            .frame(width: 44, height: 44)
                        Circle()
                            .trim(from: 0, to: animatedProgress)
                            .stroke(progress.phase.accentColor, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                            .frame(width: 44, height: 44)
                            .rotationEffect(.degrees(-90))
                        if progress.isEstablished {
                            Image(systemName: "checkmark")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.klunaGold)
                        } else {
                            Text("\(Int(progress.percentage * 100))")
                                .font(KlunaFont.scoreDisplay(12))
                                .foregroundColor(progress.phase.accentColor)
                        }
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(progress.phase.title(language: language))
                            .font(KlunaFont.heading(14))
                            .foregroundColor(.klunaPrimary)
                        if !progress.isEstablished {
                            Text("\(progress.totalSessions)/\(progress.requiredSessions) Sessions")
                                .font(KlunaFont.caption(12))
                                .foregroundColor(.klunaMuted)
                        } else {
                            Text(progress.phase.description(language: language))
                                .font(KlunaFont.caption(12))
                                .foregroundColor(.klunaGold)
                        }
                    }
                    Spacer()
                    Image(systemName: showDetail ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12))
                        .foregroundColor(.klunaMuted)
                }
            }
            .buttonStyle(.plain)

            if showDetail {
                VStack(spacing: KlunaSpacing.md) {
                    Text(progress.phase.description(language: language))
                        .font(KlunaFont.body(14))
                        .foregroundColor(.klunaSecondary)
                        .lineSpacing(3)
                    BaselinePhaseBar(progress: progress, language: language)
                    if !progress.isEstablished {
                        VStack(alignment: .leading, spacing: KlunaSpacing.sm) {
                            PhaseUnlockRow(icon: "person.fill", text: language == "de" ? "Persönliche Scores" : "Personal scores", unlocked: progress.totalSessions >= 8, phase: "8 Sessions")
                            PhaseUnlockRow(icon: "trophy.fill", text: language == "de" ? "Personal Best Vergleich" : "Personal best comparison", unlocked: progress.totalSessions >= 15, phase: "15 Sessions")
                            PhaseUnlockRow(icon: "star.fill", text: language == "de" ? "Volle Kalibrierung" : "Full calibration", unlocked: progress.totalSessions >= 21, phase: "21 Sessions")
                        }
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(KlunaSpacing.md)
        .background(Color.klunaSurface)
        .cornerRadius(KlunaRadius.card)
        .overlay(
            RoundedRectangle(cornerRadius: KlunaRadius.card)
                .stroke(progress.isEstablished ? Color.klunaGold.opacity(0.3) : Color.klunaBorder, lineWidth: 1)
        )
        .onAppear {
            withAnimation(.easeOut(duration: 1.0).delay(0.3)) {
                animatedProgress = progress.percentage
            }
        }
    }
}

struct BaselinePhaseBar: View {
    let progress: BaselineProgress
    let language: String

    var body: some View {
        VStack(spacing: KlunaSpacing.xs) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.klunaBackground)
                        .frame(height: 8)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(LinearGradient(colors: [.klunaAccent, progress.phase.accentColor], startPoint: .leading, endPoint: .trailing))
                        .frame(width: geo.size.width * CGFloat(progress.percentage), height: 8)
                    ForEach([7, 14, 21], id: \.self) { session in
                        let position = CGFloat(session) / 21.0
                        Rectangle()
                            .fill(Color.klunaMuted.opacity(0.3))
                            .frame(width: 1, height: 12)
                            .offset(x: geo.size.width * position, y: -2)
                    }
                }
            }
            .frame(height: 8)

            HStack {
                Text(language == "de" ? "Lernt" : "Learning")
                    .font(KlunaFont.caption(9))
                    .foregroundColor(progress.totalSessions < 8 ? .klunaAccent : .klunaMuted)
                Spacer()
                Text(language == "de" ? "Versteht" : "Understands")
                    .font(KlunaFont.caption(9))
                    .foregroundColor(progress.totalSessions >= 8 && progress.totalSessions < 15 ? .klunaAccent : .klunaMuted)
                Spacer()
                Text(language == "de" ? "Kennt" : "Knows")
                    .font(KlunaFont.caption(9))
                    .foregroundColor(progress.totalSessions >= 15 && progress.totalSessions < 21 ? .klunaGreen : .klunaMuted)
                Spacer()
                Text("✓")
                    .font(KlunaFont.caption(9))
                    .foregroundColor(progress.isEstablished ? .klunaGold : .klunaMuted)
            }
        }
    }
}

struct PhaseUnlockRow: View {
    let icon: String
    let text: String
    let unlocked: Bool
    let phase: String

    var body: some View {
        HStack(spacing: KlunaSpacing.sm) {
            Image(systemName: unlocked ? icon : "lock.fill")
                .font(.system(size: 12))
                .foregroundColor(unlocked ? .klunaGreen : .klunaMuted)
                .frame(width: 20)
            Text(text)
                .font(KlunaFont.body(13))
                .foregroundColor(unlocked ? .klunaPrimary : .klunaMuted)
            Spacer()
            Text(phase)
                .font(KlunaFont.caption(11))
                .foregroundColor(.klunaMuted)
        }
    }
}
