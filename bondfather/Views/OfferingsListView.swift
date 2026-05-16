import SwiftUI

struct OfferingsListView: View {
    @State private var viewModel = OfferingsViewModel()
    @State private var showingSettings = false
    @AppStorage("hasSeenSettingsPrompt") private var hasSeenSettingsPrompt = false

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Estonian IPOs")
                .navigationDestination(for: Offering.self) { offering in
                    OfferingDetailView(offering: offering)
                }
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            showingSettings = true
                        } label: {
                            Image(systemName: "gearshape")
                        }
                    }
                }
                .sheet(isPresented: $showingSettings) {
                    SettingsView(onSave: {
                        Task { await viewModel.load() }
                    })
                }
        }
        .task {
            await viewModel.load()
            if !hasSeenSettingsPrompt, Secrets.geminiAPIKey == nil {
                hasSeenSettingsPrompt = true
                showingSettings = true
            }
        }
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
