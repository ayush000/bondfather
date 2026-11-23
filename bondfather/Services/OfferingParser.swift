import Foundation

/// Parses the Nasdaq Baltic calendar and announcement pages.
///
/// The pages are scraped with regular expressions, so a layout change on nasdaqbaltic.com
/// can break parsing. The unit tests pin the markup this parser expects.
nonisolated enum OfferingParser {
    struct CalendarEntry: Hashable, Sendable {
        let offering: Offering
        let announcementURL: URL?
    }

    /// Parses the rows of the calendar table.
    ///
    /// Returns nil when the page has no table body, which usually means an error page or a
    /// layout change rather than an empty calendar.
    static func parseCalendar(html: String, baseURL: URL? = nil) -> [CalendarEntry]? {
        guard let bodyStart = html.range(of: "<tbody>"),
            let bodyEnd = html.range(of: "</tbody>", range: bodyStart.upperBound..<html.endIndex)
        else { return nil }
        let body = html[bodyStart.upperBound..<bodyEnd.lowerBound]
        return body.matches(of: /(?s)<tr[^>]*>(.*?)<\/tr>/).compactMap { parseRow($0.1, baseURL: baseURL) }
    }

    /// Extracts the bond terms from an offering's announcement page.
    static func parseDetails(html: String) -> OfferingDetails {
        let text =
            html
            .replacing(/<[^>]+>/, with: " ")
            .replacing(/\s+/, with: " ")

        // Each free-text value runs until the next known field label.
        let nextLabel =
            #"(?=\s+(?:Price of one security|Minimum investment|Interest rate|Offering period|Settlement date|ISIN code)\b|$)"#

        var details = OfferingDetails()
        if let rate = firstCapture(in: text, pattern: #"Interest rate[\s:]*([0-9]+(?:[.,][0-9]+)?)\s*%"#) {
            details.interestRate = Double(rate.replacing(",", with: "."))
        }
        details.isin = firstCapture(in: text, pattern: #"ISIN code[\s:]*([A-Z]{2}[A-Z0-9]{9}[0-9])"#)
        details.priceOfSecurity = firstCapture(in: text, pattern: #"Price of one security[\s:]*(.+?)"# + nextLabel)
        details.minimumInvestment = firstCapture(
            in: text, pattern: #"Minimum investment amount[\s:]*(.+?)"# + nextLabel)
        details.settlementDate = firstCapture(
            in: text, pattern: #"Settlement date[\s:]*([0-9]{2}\.[0-9]{2}\.[0-9]{4})"#)
        return details
    }

    // MARK: - Calendar rows

    private static func parseRow(_ row: Substring, baseURL: URL?) -> CalendarEntry? {
        let cells = row.matches(of: /(?s)<td[^>]*>(.*?)<\/td>/).map(\.1)
        guard cells.count >= 4 else { return nil }

        let dates = cells[0].matches(of: /(\d{2})\.(\d{2})\.(\d{4})/).compactMap { match in
            date(day: match.1, month: match.2, year: match.3)
        }

        // The issuer cell looks like `Issuer Name<br><strong>TICKER</strong>`. The name can be blank.
        let issuerCell = cells[1]
        let ticker = issuerCell.firstMatch(of: /(?s)<strong>(.*?)<\/strong>/).map { plainText($0.1) } ?? ""
        let issuerName: String
        if let lineBreak = issuerCell.range(of: "<br>") {
            let name = plainText(issuerCell[..<lineBreak.lowerBound])
            issuerName = name.isEmpty ? ticker : name
        } else {
            issuerName = plainText(issuerCell)
        }
        guard !issuerName.isEmpty else { return nil }

        let markets = cells[3].matches(of: /tickercode[^"]*">(\w+)</).map { String($0.1) }
        let announcementURL = cells[2].firstMatch(of: /href="([^"]+)"/).flatMap { match in
            URL(string: decodeEntities(String(match.1)), relativeTo: baseURL)?.absoluteURL
        }

        let offering = Offering(
            ticker: ticker,
            issuerName: issuerName,
            subscriptionStart: dates.first,
            subscriptionEnd: dates.dropFirst().first,
            markets: markets
        )
        return CalendarEntry(offering: offering, announcementURL: announcementURL)
    }

    // MARK: - Helpers

    private static func firstCapture(in text: String, pattern: String) -> String? {
        guard let regex = try? Regex(pattern, as: (Substring, Substring).self).ignoresCase(),
            let match = text.firstMatch(of: regex)
        else { return nil }
        return match.1.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Calendar dates are Gregorian `dd.MM.yyyy`, interpreted as midnight in the device's time zone.
    private static func date(day: Substring, month: Substring, year: Substring) -> Date? {
        guard let day = Int(day), let month = Int(month), let year = Int(year) else { return nil }
        return Calendar(identifier: .gregorian).date(from: DateComponents(year: year, month: month, day: day))
    }

    private static func plainText(_ html: Substring) -> String {
        decodeEntities(String(html).replacing(/<[^>]+>/, with: ""))
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func decodeEntities(_ text: String) -> String {
        text
            .replacing("&quot;", with: "\"")
            .replacing("&#039;", with: "'")
            .replacing("&#39;", with: "'")
            .replacing("&lt;", with: "<")
            .replacing("&gt;", with: ">")
            .replacing("&nbsp;", with: " ")
            .replacing("&amp;", with: "&")
    }
}
