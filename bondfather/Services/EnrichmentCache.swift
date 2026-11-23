import Foundation
import os

/// Gemini results keyed by offering ID, so each issuer is looked up once unless refreshed.
struct EnrichmentCache {
    private static let key = "com.bondfather.enrichmentCache.v1"

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> [String: OfferingEnrichment] {
        guard let data = defaults.data(forKey: Self.key) else { return [:] }
        do {
            return try JSONDecoder().decode([String: OfferingEnrichment].self, from: data)
        } catch {
            Logger.gemini.error(
                "Discarding unreadable enrichment cache: \(error.localizedDescription, privacy: .public)")
            return [:]
        }
    }

    func save(_ cache: [String: OfferingEnrichment]) {
        do {
            defaults.set(try JSONEncoder().encode(cache), forKey: Self.key)
        } catch {
            Logger.gemini.error("Couldn't save enrichment cache: \(error.localizedDescription, privacy: .public)")
        }
    }
}
