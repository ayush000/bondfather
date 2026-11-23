import Foundation
import os

nonisolated enum OfferingServiceError: LocalizedError {
    case invalidURL
    case badStatus(Int)
    case unexpectedPageFormat

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            "Couldn't build the calendar URL."
        case .badStatus(let statusCode):
            "Nasdaq Baltic responded with HTTP \(statusCode)."
        case .unexpectedPageFormat:
            "The Nasdaq Baltic calendar page has an unexpected format."
        }
    }
}

/// Loads upcoming Tallinn offerings from the Nasdaq Baltic calendar and attaches bond details
/// and cached or freshly generated issuer insights.
struct OfferingService {
    private static let calendarHost = "nasdaqbaltic.com"
    private static let tallinnMarket = "TLN"

    private let enrichmentCache = EnrichmentCache()

    func fetchOfferings() async throws -> [Offering] {
        let url = try Self.calendarURL(from: .now)
        let html = try await Self.fetchHTML(from: url, maxAttempts: 3)
        guard let entries = OfferingParser.parseCalendar(html: html, baseURL: url) else {
            throw OfferingServiceError.unexpectedPageFormat
        }
        let tallinnEntries = entries.filter { $0.offering.markets.contains(Self.tallinnMarket) }
        let offerings = await attachDetails(to: tallinnEntries)
        return await attachEnrichment(to: offerings)
    }

    /// Regenerates the issuer insights for one offering, bypassing the cache.
    func refreshEnrichment(for offering: Offering) async throws -> OfferingEnrichment {
        guard let apiKey = Secrets.geminiAPIKey else { throw GeminiServiceError.missingAPIKey }
        let result = try await GeminiService(apiKey: apiKey)
            .enrich(issuerName: offering.issuerName, ticker: offering.ticker)
        var cache = enrichmentCache.load()
        cache[offering.id] = result
        enrichmentCache.save(cache)
        return result
    }

    // MARK: - Details

    private func attachDetails(to entries: [OfferingParser.CalendarEntry]) async -> [Offering] {
        await withTaskGroup(of: (Int, OfferingDetails?).self) { group in
            for (index, entry) in entries.enumerated() {
                guard let url = entry.announcementURL else { continue }
                group.addTask { (index, await Self.fetchDetails(from: url)) }
            }

            var offerings = entries.map(\.offering)
            for await (index, details) in group {
                if let details { offerings[index].apply(details) }
            }
            return offerings
        }
    }

    private nonisolated static func fetchDetails(from url: URL) async -> OfferingDetails? {
        do {
            return OfferingParser.parseDetails(html: try await fetchHTML(from: url))
        } catch {
            Logger.offerings.error(
                "Couldn't load announcement \(url.absoluteString, privacy: .public): \(error.localizedDescription, privacy: .public)"
            )
            return nil
        }
    }

    // MARK: - Enrichment

    private func attachEnrichment(to offerings: [Offering]) async -> [Offering] {
        var cache = enrichmentCache.load()
        let missing = offerings.filter { cache[$0.id] == nil }

        if !missing.isEmpty, let apiKey = Secrets.geminiAPIKey {
            let gemini = GeminiService(apiKey: apiKey)
            let fetched = await withTaskGroup(of: (String, OfferingEnrichment?).self) { group in
                for offering in missing {
                    group.addTask {
                        do {
                            let enrichment = try await gemini.enrich(
                                issuerName: offering.issuerName,
                                ticker: offering.ticker
                            )
                            return (offering.id, enrichment)
                        } catch {
                            Logger.gemini.error(
                                "Enrichment failed for \(offering.issuerName, privacy: .public): \(error.localizedDescription, privacy: .public)"
                            )
                            return (offering.id, nil)
                        }
                    }
                }

                var results: [String: OfferingEnrichment] = [:]
                for await (id, enrichment) in group {
                    results[id] = enrichment
                }
                return results
            }

            if !fetched.isEmpty {
                cache.merge(fetched) { _, new in new }
                enrichmentCache.save(cache)
            }
        }

        return offerings.map { offering in
            var offering = offering
            offering.enrichment = cache[offering.id]
            return offering
        }
    }

    // MARK: - Networking

    private nonisolated static func fetchHTML(from url: URL, maxAttempts: Int = 1) async throws -> String {
        var attempt = 1
        while true {
            do {
                let (data, response) = try await URLSession.shared.data(from: url)
                if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
                    throw OfferingServiceError.badStatus(http.statusCode)
                }
                return String(decoding: data, as: UTF8.self)
            } catch let error as URLError where error.code == .networkConnectionLost && attempt < maxAttempts {
                Logger.offerings.notice("Connection lost, retrying (attempt \(attempt) of \(maxAttempts))")
                try await Task.sleep(for: .milliseconds(500 * attempt))
                attempt += 1
            }
        }
    }

    static func calendarURL(from date: Date, calendar: Calendar = .current) throws -> URL {
        guard let nextYear = calendar.date(byAdding: .year, value: 1, to: date) else {
            throw OfferingServiceError.invalidURL
        }
        let format = Date.ISO8601FormatStyle(timeZone: calendar.timeZone).year().month().day()
        var components = URLComponents()
        components.scheme = "https"
        components.host = calendarHost
        components.path = "/statistics/en/calendar"
        components.queryItems = [
            URLQueryItem(name: "filter", value: "1"),
            URLQueryItem(name: "period", value: ""),
            URLQueryItem(name: "from", value: date.formatted(format)),
            URLQueryItem(name: "to", value: nextYear.formatted(format)),
            URLQueryItem(name: "category", value: "227"),
            URLQueryItem(name: "issuer", value: ""),
        ]
        guard let url = components.url else { throw OfferingServiceError.invalidURL }
        return url
    }
}
