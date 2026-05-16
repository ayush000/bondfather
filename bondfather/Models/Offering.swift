import Foundation
import CryptoKit

enum MarketFamiliarity: String, Codable, Hashable, CaseIterable {
    case household, established, niche
}

enum OversubscriptionLikelihood: String, Codable, Hashable, CaseIterable {
    case critical, moderate, unlikely
}

struct OfferingEnrichment: Codable, Hashable, Sendable {
    let sector: String
    let businessSummary: String
    let companyAgeYears: Int?
    let marketFamiliarity: MarketFamiliarity
    let relativeRiskScore: Int?
    let oversubscriptionLikelihood: OversubscriptionLikelihood
}

struct Offering: Codable, Identifiable, Hashable {
    let id: String
    let issuerName: String
    let subscriptionStart: Date?
    let subscriptionEnd: Date?
    let markets: [String]
    let interestRate: Double?
    let isin: String?
    let priceOfSecurity: String?
    let minimumInvestment: String?
    let settlementDate: String?
    let enrichment: OfferingEnrichment?

    static func makeId(ticker: String?, issuerName: String) -> String {
        if let ticker, !ticker.isEmpty { return ticker }
        let digest = SHA256.hash(data: Data(issuerName.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
