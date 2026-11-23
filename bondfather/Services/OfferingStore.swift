import Foundation

/// IDs of offerings the app has already seen, used to detect new ones.
struct OfferingStore {
    private static let key = "com.bondfather.knownOfferingIds"

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func knownIds() -> Set<String> {
        Set(defaults.stringArray(forKey: Self.key) ?? [])
    }

    /// Adds the offerings to the known set. Earlier IDs are kept, so an offering that briefly
    /// drops off the calendar doesn't trigger a second alert when it comes back.
    func markAsSeen(_ offerings: [Offering]) {
        let ids = knownIds().union(offerings.map(\.id))
        defaults.set(ids.sorted(), forKey: Self.key)
    }

    func newOfferings(from offerings: [Offering]) -> [Offering] {
        let known = knownIds()
        return offerings.filter { !known.contains($0.id) }
    }
}
