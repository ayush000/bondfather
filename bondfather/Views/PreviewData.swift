import Foundation

/// Sample data for SwiftUI previews.
nonisolated extension Offering {
    static var preview: Offering {
        var offering = Offering(
            ticker: "PNPBOND_13",
            issuerName: "PN Project",
            subscriptionStart: Calendar.current.date(byAdding: .day, value: -3, to: .now),
            subscriptionEnd: Calendar.current.date(byAdding: .day, value: 18, to: .now),
            markets: ["TLN", "RIG", "VLN"]
        )
        offering.apply(
            OfferingDetails(
                interestRate: 10,
                isin: "LV0000104271",
                priceOfSecurity: "EUR 1004.2662 (100.42662%)",
                minimumInvestment: "EUR 1004.2662 (1 bond)",
                settlementDate: "02.12.2026"
            ))
        offering.enrichment = OfferingEnrichment(
            sector: "Real Estate",
            businessSummary: "Develops and manages residential and commercial property.",
            companyAgeYears: 12,
            marketFamiliarity: .niche,
            relativeRiskScore: 4,
            oversubscriptionLikelihood: .moderate
        )
        return offering
    }
}
