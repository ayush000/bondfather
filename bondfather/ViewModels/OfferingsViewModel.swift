import Foundation
import os

enum LoadState {
    case loading
    case loaded([Offering])
    case failed(message: String)
}

@Observable
final class OfferingsViewModel {
    private(set) var loadState: LoadState = .loading
    private let service = OfferingService()

    func load() async {
        // Keep showing the current list while a pull-to-refresh is in flight.
        if case .loaded = loadState {} else { loadState = .loading }
        do {
            let offerings = try await service.fetchOfferings()
            loadState = .loaded(
                offerings.sorted {
                    ($0.subscriptionStart ?? .distantFuture) < ($1.subscriptionStart ?? .distantFuture)
                })
        } catch is CancellationError {
            // The view went away or a newer refresh started; leave the current state as is.
        } catch {
            Logger.offerings.error("Loading offerings failed: \(error.localizedDescription, privacy: .public)")
            loadState = .failed(message: error.localizedDescription)
        }
    }
}
