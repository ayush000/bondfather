import Foundation

enum LoadState {
    case loading
    case loaded([Offering])
    case error
}

@Observable
final class OfferingsViewModel {
    var loadState: LoadState = .loading
    private let service = OfferingService()

    func load() async {
        if case .loaded = loadState {} else { loadState = .loading }
        do {
            let offerings = try await service.fetchOfferings()
            loadState = .loaded(offerings.sorted {
                switch ($0.subscriptionStart, $1.subscriptionStart) {
                case let (a?, b?): return a < b
                case (nil, _): return false
                case (_, nil): return true
                }
            })
        } catch {
            loadState = .error
        }
    }
}
