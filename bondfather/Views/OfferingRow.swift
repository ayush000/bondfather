import SwiftUI

struct OfferingRow: View {
    let offering: Offering

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(offering.issuerName)
                    .font(.headline)
                Text(offering.subscriptionPeriodText ?? "Subscription dates TBD")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            if let rate = offering.interestRateText {
                Text(rate)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.tint)
                    .monospacedDigit()
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    List {
        OfferingRow(offering: .preview)
    }
}
