import SwiftUI

struct OfferingsListView: View {
    @State private var viewModel = OfferingsViewModel()
    @State private var showingSettings = false
    @AppStorage("hasSeenSettingsPrompt") private var hasSeenSettingsPrompt = false

    var body: some View {
        NavigationStack {
            content
                .refreshable { await viewModel.load() }
                .navigationTitle("Estonian IPOs")
                .navigationDestination(for: Offering.self) { offering in
                    OfferingDetailView(offering: offering)
                }
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Settings", systemImage: "gearshape") {
                            showingSettings = true
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
        case .loaded(let offerings) where offerings.isEmpty:
            List {
                ContentUnavailableView(
                    "No Upcoming Offerings",
                    systemImage: "chart.line.uptrend.xyaxis",
                    description: Text("No Estonian public offerings found for the next year.")
                )
            }
        case .loaded(let offerings):
            List(offerings) { offering in
                NavigationLink(value: offering) {
                    OfferingRow(offering: offering)
                }
            }
        case .failed(let message):
            List {
                ContentUnavailableView(
                    "Could Not Load Offerings",
                    systemImage: "exclamationmark.triangle",
                    description: Text("\(message)\nPull to refresh.")
                )
            }
        }
    }
}

#Preview {
    OfferingsListView()
}
