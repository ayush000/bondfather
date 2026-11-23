import Foundation
import Testing

@testable import bondfather

struct OfferingParserTests {
    private let baseURL = URL(string: "https://nasdaqbaltic.com/statistics/en/calendar")!

    private func entries() throws -> [OfferingParser.CalendarEntry] {
        try #require(OfferingParser.parseCalendar(html: Fixtures.calendarPage, baseURL: baseURL))
    }

    @Test func parsesEveryCalendarRow() throws {
        #expect(try entries().count == 4)
    }

    @Test func parsesIssuerTickerAndMarkets() throws {
        let offering = try entries()[1].offering
        #expect(offering.issuerName == "PN Project")
        #expect(offering.ticker == "PNPBOND_13")
        #expect(offering.id == "PNPBOND_13")
        #expect(offering.markets == ["TLN", "RIG", "VLN"])
    }

    @Test func parsesSubscriptionPeriodAsLocalDates() throws {
        let offering = try entries()[0].offering
        let calendar = Calendar(identifier: .gregorian)
        let start = try #require(offering.subscriptionStart)
        let end = try #require(offering.subscriptionEnd)
        #expect(
            calendar.dateComponents([.year, .month, .day, .hour], from: start)
                == DateComponents(year: 2026, month: 11, day: 6, hour: 0))
        #expect(
            calendar.dateComponents([.year, .month, .day], from: end)
                == DateComponents(year: 2026, month: 11, day: 27))
    }

    @Test func decodesAmpersandsInAnnouncementURL() throws {
        let url = try #require(try entries()[0].announcementURL)
        #expect(
            url.absoluteString
                == "https://view.news.eu.nasdaq.com/view?id=bfed96fcd25ad82d35acfe24f627ab190&lang=en&src=listed")
    }

    @Test func fallsBackToTickerWhenIssuerNameIsBlank() throws {
        let offering = try entries()[2].offering
        #expect(offering.issuerName == "LKOPBOND950")
        #expect(offering.ticker == "LKOPBOND950")
    }

    @Test func handlesRowWithoutTickerOrEndDate() throws {
        let entry = try entries()[3]
        #expect(entry.offering.issuerName == "Smith & Sons")
        #expect(entry.offering.ticker == nil)
        #expect(entry.offering.id == Offering.makeId(ticker: nil, issuerName: "Smith & Sons"))
        #expect(entry.offering.subscriptionStart != nil)
        #expect(entry.offering.subscriptionEnd == nil)
        #expect(entry.announcementURL?.absoluteString == "https://nasdaqbaltic.com/statistics/en/news/123")
    }

    @Test func returnsNilWhenPageHasNoTable() {
        #expect(OfferingParser.parseCalendar(html: "<html><body>Service unavailable</body></html>") == nil)
    }

    @Test func returnsEmptyListForEmptyTable() {
        #expect(OfferingParser.parseCalendar(html: "<table><tbody>\n</tbody></table>") == [])
    }

    @Test func parsesAnnouncementDetails() {
        let details = OfferingParser.parseDetails(html: Fixtures.announcementPage)
        #expect(details.interestRate == 10)
        #expect(details.isin == "LV0000104271")
        #expect(details.priceOfSecurity == "EUR 1004.2662 (100.42662%)")
        #expect(details.minimumInvestment == "EUR 1004.2662 (1 bond)")
        #expect(details.settlementDate == "02.12.2026")
    }

    @Test func parsesCommaDecimalInterestRate() {
        let details = OfferingParser.parseDetails(html: "<td>Interest rate</td><td>7,25 %</td>")
        #expect(details.interestRate == 7.25)
    }

    @Test func leavesMissingDetailsEmpty() {
        #expect(OfferingParser.parseDetails(html: "<p>No terms here.</p>") == OfferingDetails())
    }
}
