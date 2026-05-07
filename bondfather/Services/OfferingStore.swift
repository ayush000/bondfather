import Foundation

struct OfferingStore {
    private static let key = "com.bondfather.knownOfferingIds"

    func knownIds() -> Set<String> {
        let array = UserDefaults.standard.stringArray(forKey: Self.key) ?? []
        return Set(array)
    }

    func save(_ offerings: [Offering]) {
        UserDefaults.standard.set(offerings.map(\.id), forKey: Self.key)
    }

    func newOfferings(from offerings: [Offering]) -> [Offering] {
        let known = knownIds()
        return offerings.filter { !known.contains($0.id) }
    }
}
