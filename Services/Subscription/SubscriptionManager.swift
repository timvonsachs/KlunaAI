import StoreKit
import Foundation

// MARK: - Subscription Manager

/// Manages Free / Pro / Team tiers via StoreKit 2.
final class SubscriptionManager: ObservableObject {
    static let shared = SubscriptionManager()

    static let monthlyProductID = "com.kluna.pro.monthly"
    static let yearlyProductID = "com.kluna.pro.yearly"

    @Published var tier: SubscriptionTier = .free
    @Published var sessionsThisWeek = 0
    @Published var products: [Product] = []
    @Published var purchaseInProgress = false

    var canStartSession: Bool {
        isProUser || rollingSessionsUsed < freeSessionLimit
    }

    var isProUser: Bool { tier != .free }
    let freeSessionLimit = 3

    var freeSessionsRemaining: Int {
        max(0, freeSessionLimit - rollingSessionsUsed)
    }

    var hasDimensionAccess: Bool { hasAccess(to: .dimensionScores) }
    var hasDeepCoaching: Bool { hasAccess(to: .detailedFeedback) }
    var hasStreaks: Bool { tier != .free }
    var hasLeaderboard: Bool { tier != .free }
    var hasAnalytics: Bool { tier != .free }
    var hasCustomPitchTypes: Bool { tier != .free }
    var hasFullHistory: Bool { hasAccess(to: .fullHistory) }
    var hasHeatmap: Bool { hasAccess(to: .audioPlayback) }
    var hasSessionComparison: Bool { hasAccess(to: .personalBest) }

    private init() {
        sessionsThisWeek = UserDefaults.standard.integer(forKey: "freeSessionsThisWeek")
        checkWeeklyReset()
        refreshFreeSessionUsage()
        #if DEBUG
        if DebugConfig.forceProSubscription {
            tier = .pro
        }
        #endif
    }

    func checkSubscriptionStatus() async {
        #if DEBUG
        if DebugConfig.forceProSubscription {
            await MainActor.run { self.tier = .pro }
            return
        }
        #endif
        await MainActor.run {
            self.checkWeeklyReset()
            self.refreshFreeSessionUsage()
        }
        do {
            await loadProducts()
            var resolvedTier: SubscriptionTier = .free
            for await entitlement in Transaction.currentEntitlements {
                guard case .verified(let transaction) = entitlement else { continue }
                if transaction.productID == Self.monthlyProductID || transaction.productID == Self.yearlyProductID {
                    resolvedTier = .pro
                }
            }
            await MainActor.run { self.tier = resolvedTier }
        } catch {
            await MainActor.run { self.tier = .free }
        }
    }

    func purchaseMonthly() async throws {
        try await purchase(productID: Self.monthlyProductID)
    }

    func purchaseYearly() async throws {
        try await purchase(productID: Self.yearlyProductID)
    }

    func purchase(_ product: Product) async throws -> Bool {
        await MainActor.run { purchaseInProgress = true }
        defer {
            Task { @MainActor in
                self.purchaseInProgress = false
            }
        }
        let result = try await product.purchase()
        switch result {
        case .success(let verification):
            let transaction = try checkVerified(verification)
            await transaction.finish()
            await checkSubscriptionStatus()
            return true
        case .userCancelled, .pending:
            return false
        @unknown default:
            return false
        }
    }

    func restorePurchases() async {
        do {
            try await AppStore.sync()
            await checkSubscriptionStatus()
        } catch {
            // no-op for MVP
        }
    }

    func incrementSessionCount() {
        if Thread.isMainThread {
            refreshFreeSessionUsage()
        } else {
            DispatchQueue.main.async {
                self.refreshFreeSessionUsage()
            }
        }
    }

    private func purchase(productID: String) async throws {
        if await MainActor.run(body: { self.products.isEmpty }) {
            await loadProducts()
        }
        let availableProducts = await MainActor.run { self.products }
        guard let product = availableProducts.first(where: { $0.id == productID }) else { return }
        await MainActor.run { purchaseInProgress = true }
        defer {
            Task { @MainActor in
                self.purchaseInProgress = false
            }
        }
        let result = try await product.purchase()
        switch result {
        case .success(let verification):
            let transaction = try checkVerified(verification)
            await transaction.finish()
            await checkSubscriptionStatus()
        case .userCancelled, .pending:
            break
        @unknown default:
            break
        }
    }

    func loadProducts() async {
        do {
            let fetched = try await Product.products(for: [Self.monthlyProductID, Self.yearlyProductID])
            await MainActor.run {
                self.products = fetched.sorted(by: { $0.price < $1.price })
            }
        } catch {
            await MainActor.run {
                self.products = []
            }
        }
    }

    func hasAccess(to feature: ProFeature) -> Bool {
        if isProUser { return true }
        switch feature {
        case .unlimitedSessions:
            return rollingSessionsUsed < freeSessionLimit
        case .dimensionScores, .audioPlayback, .coachMode, .microDrills, .personalBest, .progressMilestones, .voiceJournal, .progressiveChallengesAll, .fullHistory, .detailedFeedback:
            return false
        case .progressiveChallengesBasic, .dailyChallenge, .warmups, .baselineVisualization:
            return true
        }
    }

    private func checkWeeklyReset() {
        let calendar = Calendar.current
        let lastReset = UserDefaults.standard.object(forKey: "lastWeeklyReset") as? Date ?? .distantPast
        if !calendar.isDate(lastReset, equalTo: Date(), toGranularity: .weekOfYear) {
            sessionsThisWeek = 0
            UserDefaults.standard.set(0, forKey: "freeSessionsThisWeek")
            UserDefaults.standard.set(Date(), forKey: "lastWeeklyReset")
        }
    }

    private var rollingSessionsUsed: Int {
        let memory = MemoryManager(context: PersistenceController.shared.container.viewContext)
        return memory.sessionsInLast(days: 7)
    }

    private func refreshFreeSessionUsage() {
        sessionsThisWeek = rollingSessionsUsed
        UserDefaults.standard.set(sessionsThisWeek, forKey: "freeSessionsThisWeek")
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .verified(let safe): return safe
        case .unverified: throw StoreError.verificationFailed
        }
    }
}

enum ProFeature {
    case unlimitedSessions
    case dimensionScores
    case audioPlayback
    case coachMode
    case microDrills
    case personalBest
    case progressMilestones
    case voiceJournal
    case progressiveChallengesAll
    case progressiveChallengesBasic
    case fullHistory
    case detailedFeedback
    case dailyChallenge
    case warmups
    case baselineVisualization
}

enum StoreError: Error {
    case verificationFailed
}

enum SubscriptionTier: String {
    case free
    case pro
    case team
}

// MARK: - Team Manager

/// Manages B2B team features: join, create, aggregated stats.
final class TeamManager: ObservableObject {
    @Published var currentTeam: Team?
    @Published var isInTeam: Bool = false
    
    /// Creates a new team (Admin flow).
    func createTeam(name: String) -> String {
        // TODO: Generate team code, create on backend
        // TODO: Set user role to admin
        let code = generateTeamCode()
        return code
    }
    
    /// Joins an existing team via code (Member flow).
    func joinTeam(code: String) async throws {
        // TODO: Validate code with backend
        // TODO: Set user role to member
        // TODO: Store teamCode in UserDefaults
    }
    
    /// Leaves the current team.
    func leaveTeam() {
        // TODO: Remove from backend, clear local team data
    }
    
    /// Fetches aggregated team stats (Admin only).
    func fetchTeamStats() async -> Team? {
        // TODO: Backend call for aggregated data
        return nil
    }
    
    private func generateTeamCode() -> String {
        let chars = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
        let fallback = Character("A")
        return String((0..<6).map { _ in chars.randomElement() ?? fallback })
    }
}
