import Foundation

/// Feature Flags – separates Consumer and B2B Team features.
/// Single codebase, two experiences.
enum FeatureFlags {
    
    /// Whether the user is in Team/B2B mode
    static var isTeamMode: Bool {
        UserDefaults.standard.string(forKey: "teamCode") != nil
    }
    
    /// Whether the user is a team admin
    static var isTeamAdmin: Bool {
        UserDefaults.standard.string(forKey: "userRole") == "admin"
    }
    
    /// Whether consumer mode (no team)
    static var isConsumerMode: Bool {
        !isTeamMode
    }
}
