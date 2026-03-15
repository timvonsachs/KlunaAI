import SwiftUI

struct ProLockedOverlay: View {
    let feature: ProFeature
    let language: String
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            ZStack {
                Color.klunaBackground.opacity(0.72)
                VStack(spacing: KlunaSpacing.sm) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.klunaAccent)
                    Text("Kluna Pro")
                        .font(KlunaFont.heading(14))
                        .foregroundColor(.klunaAccent)
                }
            }
        }
        .buttonStyle(.plain)
    }
}
