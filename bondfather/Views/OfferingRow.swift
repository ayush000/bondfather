import SwiftUI

struct OfferingRow: View {
    let offering: Offering

    private static let displayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(offering.issuerName)
                .font(.headline)
            Text(subscriptionPeriodText)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }

    private var subscriptionPeriodText: String {
        let fmt = Self.displayFormatter
        switch (offering.subscriptionStart, offering.subscriptionEnd) {
        case let (start?, end?): return "\(fmt.string(from: start)) – \(fmt.string(from: end))"
        case let (start?, nil): return fmt.string(from: start)
        default: return "Subscription dates TBD"
        }
    }
}
