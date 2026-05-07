import Foundation
import CryptoKit

enum OfferingServiceError: Error {
    case invalidURL
    case parseFailure
}

struct OfferingService {
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
        return parseOfferings(from: html).filter { $0.markets.contains("TLN") }
    }

    private func buildURL() throws -> URL {
        let today = Date.now
        guard let nextYear = Calendar.current.date(byAdding: .year, value: 1, to: today) else {
            throw OfferingServiceError.invalidURL
        }
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
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

    private func parseOfferings(from html: String) -> [Offering] {
        guard let tbodyStart = html.range(of: "<tbody>"),
              let tbodyEnd = html.range(of: "</tbody>") else { return [] }
        let tbody = String(html[tbodyStart.upperBound..<tbodyEnd.lowerBound])
        return extractRows(from: tbody).compactMap { parseRow($0) }
    }

    private func extractRows(from tbody: String) -> [String] {
        var rows: [String] = []
        var remaining = tbody
        while let trStart = remaining.range(of: "<tr>"),
              let trEnd = remaining.range(of: "</tr>") {
            rows.append(String(remaining[trStart.upperBound..<trEnd.lowerBound]))
            remaining = String(remaining[trEnd.upperBound...])
        }
        return rows
    }

    private func parseRow(_ row: String) -> Offering? {
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
        guard !ticker.isEmpty || !issuerName.isEmpty else { return nil }

        return Offering(
            id: Offering.makeId(ticker: ticker.isEmpty ? nil : ticker, issuerName: issuerName),
            issuerName: issuerName,
            subscriptionStart: subStart,
            subscriptionEnd: subEnd,
            markets: markets
        )
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
