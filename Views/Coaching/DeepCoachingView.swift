import SwiftUI

struct DeepCoachingView: View {
    let coaching: String?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color.klunaBackground.ignoresSafeArea()
            VStack(spacing: 16) {
                Text(L10n.deepCoaching)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.klunaPrimary)
                if let coaching, !coaching.isEmpty {
                    ScrollView {
                        Text(coaching)
                            .font(.system(size: 17))
                            .foregroundColor(.klunaPrimary)
                            .lineSpacing(5)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 12)
                    }
                } else {
                    ProgressView().tint(.klunaAccent)
                    Text(L10n.analyzing).foregroundColor(.klunaMuted)
                }
                Button(L10n.done) { dismiss() }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Color.klunaAccent)
                    .cornerRadius(10)
            }
            .padding()
        }
    }
}
