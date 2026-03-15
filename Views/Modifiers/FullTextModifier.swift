import SwiftUI

struct FullTextModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .lineLimit(nil)
            .fixedSize(horizontal: false, vertical: true)
    }
}

extension View {
    func fullText() -> some View {
        modifier(FullTextModifier())
    }
}
