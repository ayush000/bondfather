import SwiftUI

struct OfferingsListView: View {
    @State private var viewModel = OfferingsViewModel()

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Estonian IPOs")
                .navigationDestination(for: Offering.self) { offering in
                    OfferingDetailView(offering: offering)
                }
        }
        .task { await viewModel.load() }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.loadState {
        case .loading:
            ProgressView()
        case .loaded(let offerings):
            if offerings.isEmpty {
                List {
                    ContentUnavailableView(
                        "No Upcoming Offerings",
                        systemImage: "chart.line.uptrend.xyaxis",
                        description: Text("No Estonian public offerings found for the next year.")
                    )
                }
                .refreshable { await viewModel.load() }
            } else {
                List(offerings) { offering in
                    NavigationLink(value: offering) {
                        OfferingRow(offering: offering)
                    }
                }
                .refreshable { await viewModel.load() }
            }
        case .error:
            List {
                ContentUnavailableView(
                    "Could not load offerings",
                    systemImage: "exclamationmark.triangle",
                    description: Text("Pull to refresh.")
                )
            }
            .refreshable { await viewModel.load() }
        }
    }
}
