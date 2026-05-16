import Foundation

enum OfferingServiceError: Error {
    case invalidURL
    case parseFailure
}

struct OfferingService {
    private let geminiService = GeminiService()
    private let enrichmentCache = EnrichmentCache()

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "dd.MM.yyyy"
        return f
    }()

    func fetchOfferings() async throws -> [Offering] {
        let url = try buildURL()
        let (data, _) = try await URLSession.shared.data(from: url)
        guard let html = String(data: data, encoding: .utf8) else {
            throw OfferingServiceError.parseFailure
        }
        let partials = parseOfferings(from: html).filter { $0.offering.markets.contains("TLN") }
        let withDetails = await enrichWithInterestRates(partials)
        return await enrichWithGemini(withDetails)
    }

    private func enrichWithGemini(_ offerings: [Offering]) async -> [Offering] {
        var cache = enrichmentCache.load()
        let needed = offerings.filter { cache[$0.id] == nil }

        let fetched = await withTaskGroup(of: (String, OfferingEnrichment?).self) { group in
            for offering in needed {
                group.addTask {
                    let result = try? await geminiService.enrich(
                        issuerName: offering.issuerName,
                        ticker: offering.id
                    )
                    return (offering.id, result)
                }
            }
            var results: [String: OfferingEnrichment] = [:]
            for await (id, enrichment) in group {
                if let enrichment { results[id] = enrichment }
            }
            return results
        }

        for (id, value) in fetched { cache[id] = value }
        if !fetched.isEmpty { enrichmentCache.save(cache) }

        return offerings.map { offering in
            Offering(
                id: offering.id,
                issuerName: offering.issuerName,
                subscriptionStart: offering.subscriptionStart,
                subscriptionEnd: offering.subscriptionEnd,
                markets: offering.markets,
                interestRate: offering.interestRate,
                isin: offering.isin,
                priceOfSecurity: offering.priceOfSecurity,
                minimumInvestment: offering.minimumInvestment,
                settlementDate: offering.settlementDate,
                enrichment: cache[offering.id]
            )
        }
    }

    struct NewsDetails: Sendable {
        var interestRate: Double?
        var isin: String?
        var priceOfSecurity: String?
        var minimumInvestment: String?
        var settlementDate: String?

        nonisolated init(
            interestRate: Double? = nil,
            isin: String? = nil,
            priceOfSecurity: String? = nil,
            minimumInvestment: String? = nil,
            settlementDate: String? = nil
        ) {
            self.interestRate = interestRate
            self.isin = isin
            self.priceOfSecurity = priceOfSecurity
            self.minimumInvestment = minimumInvestment
            self.settlementDate = settlementDate
        }
    }

    private func enrichWithInterestRates(_ partials: [ParsedOffering]) async -> [Offering] {
        await withTaskGroup(of: (Int, NewsDetails).self) { group in
            for (index, partial) in partials.enumerated() {
                group.addTask {
                    guard let url = partial.newsURL else { return (index, NewsDetails()) }
                    return (index, await Self.fetchDetails(from: url))
                }
            }
            var details = Array<NewsDetails>(repeating: NewsDetails(), count: partials.count)
            for await (index, d) in group { details[index] = d }
            return zip(partials, details).map { partial, d in
                let o = partial.offering
                return Offering(
                    id: o.id,
                    issuerName: o.issuerName,
                    subscriptionStart: o.subscriptionStart,
                    subscriptionEnd: o.subscriptionEnd,
                    markets: o.markets,
                    interestRate: d.interestRate,
                    isin: d.isin,
                    priceOfSecurity: d.priceOfSecurity,
                    minimumInvestment: d.minimumInvestment,
                    settlementDate: d.settlementDate,
                    enrichment: nil
                )
            }
        }
    }

    private static func fetchDetails(from url: URL) async -> NewsDetails {
        guard let (data, _) = try? await URLSession.shared.data(from: url),
              let html = String(data: data, encoding: .utf8) else { return NewsDetails() }
        return parseDetails(from: html)
    }

    static func parseDetails(from html: String) -> NewsDetails {
        let stripped = html
            .replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        var details = NewsDetails()
        if let rate = firstMatch(in: stripped, pattern: #"Interest rate[\s:]*([0-9]+(?:[.,][0-9]+)?)\s*%"#) {
            details.interestRate = Double(rate.replacingOccurrences(of: ",", with: "."))
        }
        details.isin = firstMatch(in: stripped, pattern: #"ISIN code[\s:]*([A-Z]{2}[A-Z0-9]{9}[0-9])"#)
        details.priceOfSecurity = firstMatch(
            in: stripped,
            pattern: #"Price of one security[\s:]*(.+?)(?=\s+(?:Minimum investment|Interest rate|Offering period|Settlement date|ISIN code)\b|$)"#
        )
        details.minimumInvestment = firstMatch(
            in: stripped,
            pattern: #"Minimum investment amount[\s:]*(.+?)(?=\s+(?:Price of one security|Interest rate|Offering period|Settlement date|ISIN code)\b|$)"#
        )
        details.settlementDate = firstMatch(in: stripped, pattern: #"Settlement date[\s:]*([0-9]{2}\.[0-9]{2}\.[0-9]{4})"#)
        return details
    }

    private static func firstMatch(in text: String, pattern: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              match.numberOfRanges >= 2,
              let range = Range(match.range(at: 1), in: text) else { return nil }
        return text[range].trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static let urlDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    private func buildURL() throws -> URL {
        let today = Date.now
        guard let nextYear = Calendar.current.date(byAdding: .year, value: 1, to: today) else {
            throw OfferingServiceError.invalidURL
        }
        let fmt = Self.urlDateFormatter
        var components = URLComponents()
        components.scheme = "https"
        components.host = "nasdaqbaltic.com"
        components.path = "/statistics/en/calendar"
        components.queryItems = [
            .init(name: "filter", value: "1"),
            .init(name: "period", value: ""),
            .init(name: "from", value: fmt.string(from: today)),
            .init(name: "to", value: fmt.string(from: nextYear)),
            .init(name: "category", value: "227"),
            .init(name: "issuer", value: ""),
        ]
        guard let url = components.url else { throw OfferingServiceError.invalidURL }
        return url
    }

    private struct ParsedOffering {
        let offering: Offering
        let newsURL: URL?
    }

    private func parseOfferings(from html: String) -> [ParsedOffering] {
        guard let tbodyStart = html.range(of: "<tbody>"),
              let tbodyEnd = html.range(of: "</tbody>") else { return [] }
        let tbody = String(html[tbodyStart.upperBound..<tbodyEnd.lowerBound])
        return extractRows(from: tbody).compactMap { parseRow($0) }
    }

    private func extractRows(from tbody: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: #"(?s)<tr[^>]*>(.*?)</tr>"#) else { return [] }
        let matches = regex.matches(in: tbody, range: NSRange(tbody.startIndex..., in: tbody))
        return matches.compactMap { match -> String? in
            guard let range = Range(match.range(at: 1), in: tbody) else { return nil }
            return String(tbody[range])
        }
    }

    private func parseRow(_ row: String) -> ParsedOffering? {
        let tds = extractTDs(from: row)
        guard tds.count >= 4 else { return nil }

        let dates = extractDates(from: tds[0])
        let subStart = dates.count > 0 ? dates[0] : nil
        let subEnd = dates.count > 1 ? dates[1] : nil

        let ticker = extractFromStrong(tds[1])
        let issuerName: String = {
            if let brRange = tds[1].range(of: "<br>") {
                let raw = String(tds[1][..<brRange.lowerBound])
                let stripped = stripTags(raw).trimmingCharacters(in: .whitespacesAndNewlines)
                return stripped.isEmpty ? ticker : stripped
            }
            return stripTags(tds[1]).trimmingCharacters(in: .whitespacesAndNewlines)
        }()

        let markets = extractMarkets(from: tds[3])
        let newsURL = extractNewsURL(from: tds[2])
        guard !ticker.isEmpty || !issuerName.isEmpty else { return nil }

        let offering = Offering(
            id: Offering.makeId(ticker: ticker.isEmpty ? nil : ticker, issuerName: issuerName),
            issuerName: issuerName,
            subscriptionStart: subStart,
            subscriptionEnd: subEnd,
            markets: markets,
            interestRate: nil,
            isin: nil,
            priceOfSecurity: nil,
            minimumInvestment: nil,
            settlementDate: nil,
            enrichment: nil
        )
        return ParsedOffering(offering: offering, newsURL: newsURL)
    }

    private func extractNewsURL(from html: String) -> URL? {
        guard let regex = try? NSRegularExpression(pattern: #"href="([^"]+)""#),
              let match = regex.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)),
              let range = Range(match.range(at: 1), in: html) else { return nil }
        let decoded = String(html[range]).replacingOccurrences(of: "&amp;", with: "&")
        return URL(string: decoded)
    }

    private func extractTDs(from row: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: #"(?s)<td[^>]*>(.*?)</td>"#) else { return [] }
        let matches = regex.matches(in: row, range: NSRange(row.startIndex..., in: row))
        return matches.compactMap { match -> String? in
            guard let range = Range(match.range(at: 1), in: row) else { return nil }
            return String(row[range])
        }
    }

    private func extractDates(from html: String) -> [Date] {
        guard let regex = try? NSRegularExpression(pattern: #"\d{2}\.\d{2}\.\d{4}"#) else { return [] }
        let matches = regex.matches(in: html, range: NSRange(html.startIndex..., in: html))
        return matches.compactMap { match -> Date? in
            guard let range = Range(match.range, in: html) else { return nil }
            return Self.dateFormatter.date(from: String(html[range]))
        }
    }

    private func extractFromStrong(_ html: String) -> String {
        guard let start = html.range(of: "<strong>"),
              let end = html.range(of: "</strong>") else { return "" }
        return String(html[start.upperBound..<end.lowerBound])
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func extractMarkets(from html: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: #"tickercode text12">(\w+)<"#) else { return [] }
        let matches = regex.matches(in: html, range: NSRange(html.startIndex..., in: html))
        return matches.compactMap { match -> String? in
            guard let range = Range(match.range(at: 1), in: html) else { return nil }
            return String(html[range])
        }
    }

    private func stripTags(_ html: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: "<[^>]+>") else { return html }
        let result = regex.stringByReplacingMatches(
            in: html,
            range: NSRange(html.startIndex..., in: html),
            withTemplate: ""
        )
        return result
    }
}
