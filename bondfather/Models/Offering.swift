import CryptoKit
import Foundation

nonisolated enum MarketFamiliarity: String, Codable, Hashable, CaseIterable, Sendable {
    case household, established, niche
}

nonisolated enum OversubscriptionLikelihood: String, Codable, Hashable, CaseIterable, Sendable {
    case critical, moderate, unlikely
}

/// AI-generated issuer profile returned by Gemini.
nonisolated struct OfferingEnrichment: Codable, Hashable, Sendable {
    let sector: String
    let businessSummary: String
    let companyAgeYears: Int?
    let marketFamiliarity: MarketFamiliarity
    let relativeRiskScore: Int?
    let oversubscriptionLikelihood: OversubscriptionLikelihood
}

/// Fields scraped from an offering's announcement page.
nonisolated struct OfferingDetails: Hashable, Sendable {
    var interestRate: Double?
    var isin: String?
    var priceOfSecurity: String?
    var minimumInvestment: String?
    var settlementDate: String?
}

nonisolated struct Offering: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let ticker: String?
    let issuerName: String
    let subscriptionStart: Date?
    let subscriptionEnd: Date?
    let markets: [String]
    var interestRate: Double?
    var isin: String?
    var priceOfSecurity: String?
    var minimumInvestment: String?
    var settlementDate: String?
    var enrichment: OfferingEnrichment?

    init(
        ticker: String?,
        issuerName: String,
        subscriptionStart: Date?,
        subscriptionEnd: Date?,
        markets: [String]
    ) {
        let ticker = ticker?.isEmpty == false ? ticker : nil
        self.id = Self.makeId(ticker: ticker, issuerName: issuerName)
        self.ticker = ticker
        self.issuerName = issuerName
        self.subscriptionStart = subscriptionStart
        self.subscriptionEnd = subscriptionEnd
        self.markets = markets
    }

    /// Offerings are keyed by ticker. Without one, a SHA-256 hash of the issuer name is used.
    static func makeId(ticker: String?, issuerName: String) -> String {
        if let ticker, !ticker.isEmpty { return ticker }
        let digest = SHA256.hash(data: Data(issuerName.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    mutating func apply(_ details: OfferingDetails) {
        interestRate = details.interestRate
        isin = details.isin
        priceOfSecurity = details.priceOfSecurity
        minimumInvestment = details.minimumInvestment
        settlementDate = details.settlementDate
    }
}

// MARK: - Display formatting

nonisolated extension Offering {
    /// "Nov 9, 2026 – Nov 30, 2026", the start date alone, or nil when the start date is unknown.
    var subscriptionPeriodText: String? {
        guard let subscriptionStart else { return nil }
        let start = subscriptionStart.formatted(date: .abbreviated, time: .omitted)
        guard let subscriptionEnd else { return start }
        return "\(start) – \(subscriptionEnd.formatted(date: .abbreviated, time: .omitted))"
    }

    /// Interest rate as a locale-aware percentage with two decimals, e.g. "10.00%".
    var interestRateText: String? {
        interestRate.map { ($0 / 100).formatted(.percent.precision(.fractionLength(2))) }
    }
}
