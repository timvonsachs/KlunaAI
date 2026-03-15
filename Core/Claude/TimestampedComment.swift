import Foundation

struct TimestampedComment: Identifiable {
    let id = UUID()
    let position: Double
    let type: CommentType
    let text: String

    enum CommentType: String {
        case positive = "POSITIVE"
        case negative = "NEGATIVE"
        case tip = "TIP"
    }
}
