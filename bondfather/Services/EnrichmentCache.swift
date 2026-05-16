import Foundation

struct EnrichmentCache {
    private static let key = "com.bondfather.enrichmentCache.v1"

    func load() -> [String: OfferingEnrichment] {
        guard let data = UserDefaults.standard.data(forKey: Self.key),
              let dict = try? JSONDecoder().decode([String: OfferingEnrichment].self, from: data)
        else { return [:] }
        return dict
    }

    func save(_ dict: [String: OfferingEnrichment]) {
        guard let data = try? JSONEncoder().encode(dict) else { return }
        UserDefaults.standard.set(data, forKey: Self.key)
    }
}
