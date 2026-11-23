import Foundation
import Testing

@testable import bondfather

struct OfferingTests {
    @Test func usesTickerAsId() {
        #expect(Offering.makeId(ticker: "SKN1T", issuerName: "Nordic Fibreboard") == "SKN1T")
    }

    @Test(arguments: [nil, ""])
    func hashesIssuerNameWithoutTicker(ticker: String?) {
        let id = Offering.makeId(ticker: ticker, issuerName: "Nordic Fibreboard")
        #expect(id.count == 64)
        #expect(id == Offering.makeId(ticker: nil, issuerName: "Nordic Fibreboard"))
        #expect(id != Offering.makeId(ticker: nil, issuerName: "PN Project"))
    }

    @Test func treatsEmptyTickerAsMissing() {
        let offering = Offering(
            ticker: "",
            issuerName: "PN Project",
            subscriptionStart: nil,
            subscriptionEnd: nil,
            markets: []
        )
        #expect(offering.ticker == nil)
    }

    @Test func formatsMissingPeriodAsNil() {
        let offering = Offering(
            ticker: "X",
            issuerName: "X",
            subscriptionStart: nil,
            subscriptionEnd: .now,
            markets: []
        )
        #expect(offering.subscriptionPeriodText == nil)
        #expect(offering.interestRateText == nil)
    }

    @Test func formatsPeriodWithEndDate() throws {
        let text = try #require(Offering.preview.subscriptionPeriodText)
        #expect(text.contains(" – "))
    }

    @Test func appliesDetails() {
        var offering = Offering(ticker: "X", issuerName: "X", subscriptionStart: nil, subscriptionEnd: nil, markets: [])
        offering.apply(OfferingDetails(interestRate: 8.5, isin: "EE0000000000"))
        #expect(offering.interestRate == 8.5)
        #expect(offering.isin == "EE0000000000")
        #expect(offering.settlementDate == nil)
    }
}
