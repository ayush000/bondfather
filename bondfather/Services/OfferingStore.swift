import Foundation

/// Remembers which offerings the app has already seen, so only new ones trigger an alert.
///
/// An offering is identified by its ID plus its subscription start date. The ID alone isn't enough: a company can
/// run another offering under the same ticker (or, without a ticker, the same issuer name) later, and that one
/// should still count as new.
struct OfferingStore {
    private static let key = "com.bondfather.seenOfferings.v2"
    /// Bare offering IDs written by earlier versions. Read until the next save so the upgrade doesn't re-alert
    /// about offerings that were already seen.
    private static let legacyKey = "com.bondfather.knownOfferingIds"

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func newOfferings(from offerings: [Offering]) -> [Offering] {
        let seen = seenKeys()
        let legacyIds = Set(defaults.stringArray(forKey: Self.legacyKey) ?? [])
        return offerings.filter { !seen.contains(Self.seenKey(for: $0)) && !legacyIds.contains($0.id) }
    }

    /// Adds the offerings to the seen set. Earlier entries are kept, so an offering that briefly drops off the
    /// calendar doesn't trigger a second alert when it comes back.
    func markAsSeen(_ offerings: [Offering]) {
        let keys = seenKeys().union(offerings.map(Self.seenKey(for:)))
        defaults.set(keys.sorted(), forKey: Self.key)
        defaults.removeObject(forKey: Self.legacyKey)
    }

    /// `ID@yyyy-MM-dd` using the subscription start date, or the bare ID while the dates are unknown.
    static func seenKey(for offering: Offering) -> String {
        guard let start = offering.subscriptionStart else { return offering.id }
        let format = Date.ISO8601FormatStyle(timeZone: .current).year().month().day()
        return "\(offering.id)@\(start.formatted(format))"
    }

    private func seenKeys() -> Set<String> {
        Set(defaults.stringArray(forKey: Self.key) ?? [])
    }
}
