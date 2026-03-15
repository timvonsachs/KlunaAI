import Foundation

final class XPManager {
    static let shared = XPManager()
    private init() {}

    var totalXP: Int {
        get { UserDefaults.standard.integer(forKey: "totalXP") }
        set { UserDefaults.standard.set(newValue, forKey: "totalXP") }
    }

    func addXP(_ amount: Int) {
        totalXP += amount
    }

    func xpForSession(overallScore: Double) -> Int {
        switch overallScore {
        case 80...: return 30
        case 65..<80: return 20
        case 50..<65: return 15
        default: return 10
        }
    }
}
