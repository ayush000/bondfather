import SwiftUI

struct OfferingDetailView: View {
    let offering: Offering
    @State private var enrichment: OfferingEnrichment?
    private let service = OfferingService()

    init(offering: Offering) {
        self.offering = offering
        _enrichment = State(initialValue: offering.enrichment)
    }

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f
    }()

    var body: some View {
        List {
            Section("Offering") {
                detailRow("ISIN", offering.isin)
                detailRow("Price of one security", offering.priceOfSecurity)
                detailRow("Minimum investment amount", offering.minimumInvestment)
                detailRow("Interest rate", offering.interestRate.map { String(format: "%.2f%%", $0) })
                detailRow("Offering period", offeringPeriodText)
                detailRow("Settlement date", offering.settlementDate)
            }

            if let enrichment {
                Section("Issuer") {
                    detailRow("Sector", enrichment.sector)
                    if !enrichment.businessSummary.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Business")
                                .foregroundStyle(.secondary)
                            Text(enrichment.businessSummary)
                        }
                        .padding(.vertical, 2)
                    }
                    detailRow("Company age", enrichment.companyAgeYears.map { "\($0) yrs" })
                    detailRow("Market familiarity", enrichment.marketFamiliarity.rawValue.capitalized)
                    detailRow("Relative risk", enrichment.relativeRiskScore.map { "\($0) / 5" })
                    detailRow("Oversubscription", enrichment.oversubscriptionLikelihood.rawValue.capitalized)
                }
            }
        }
        .navigationTitle(offering.issuerName)
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await refreshEnrichment() }
    }

    private func refreshEnrichment() async {
        guard let updated = try? await service.refreshEnrichment(for: offering) else { return }
        enrichment = updated
    }

    @ViewBuilder
    private func detailRow(_ label: String, _ value: String?) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value ?? "—")
                .multilineTextAlignment(.trailing)
                .foregroundStyle(value == nil ? .secondary : .primary)
        }
    }

    private var offeringPeriodText: String? {
        let fmt = Self.dateFormatter
        switch (offering.subscriptionStart, offering.subscriptionEnd) {
        case let (start?, end?): return "\(fmt.string(from: start)) – \(fmt.string(from: end))"
        case let (start?, nil): return fmt.string(from: start)
        default: return nil
        }
    }
}
