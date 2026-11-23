import Foundation
import Testing

@testable import bondfather

@MainActor
struct OfferingStoreTests {
    private let defaults: UserDefaults
    private let store: OfferingStore

    init() throws {
        // A fresh suite per test keeps tests isolated from each other and from the app's own data.
        defaults = try #require(UserDefaults(suiteName: "OfferingStoreTests.\(UUID().uuidString)"))
        store = OfferingStore(defaults: defaults)
    }

    private func offering(_ ticker: String, startingOn day: Int? = 6) -> Offering {
        let start = day.flatMap {
            Calendar(identifier: .gregorian).date(from: DateComponents(year: 2026, month: 11, day: $0))
        }
        return Offering(ticker: ticker, issuerName: ticker, subscriptionStart: start, subscriptionEnd: nil, markets: [])
    }

    @Test func treatsEverythingAsNewInitially() {
        let offerings = [offering("A"), offering("B")]
        #expect(store.newOfferings(from: offerings) == offerings)
    }

    @Test func remembersSeenOfferings() {
        store.markAsSeen([offering("A")])
        #expect(store.newOfferings(from: [offering("A"), offering("B")]).map(\.id) == ["B"])
    }

    @Test func keepsOfferingsThatDropOffTheCalendar() {
        store.markAsSeen([offering("A")])
        store.markAsSeen([offering("B")])
        #expect(store.newOfferings(from: [offering("A"), offering("B")]).isEmpty)
    }

    @Test func treatsLaterOfferingUnderSameTickerAsNew() {
        store.markAsSeen([offering("SKN1T", startingOn: 6)])
        #expect(store.newOfferings(from: [offering("SKN1T", startingOn: 6)]).isEmpty)
        #expect(store.newOfferings(from: [offering("SKN1T", startingOn: 20)]).count == 1)
    }

    @Test func remembersOfferingsWithoutDates() {
        store.markAsSeen([offering("A", startingOn: nil)])
        #expect(store.newOfferings(from: [offering("A", startingOn: nil)]).isEmpty)
    }

    @Test func migratesIdsSavedByEarlierVersions() {
        let legacyKey = "com.bondfather.knownOfferingIds"
        defaults.set(["A"], forKey: legacyKey)
        let current = [offering("A"), offering("B")]

        #expect(store.newOfferings(from: current).map(\.id) == ["B"])
        store.markAsSeen(current)
        #expect(defaults.stringArray(forKey: legacyKey) == nil)
        #expect(store.newOfferings(from: current).isEmpty)
        #expect(store.newOfferings(from: [offering("A", startingOn: 20)]).count == 1)
    }
}

@MainActor
struct EnrichmentCacheTests {
    @Test func roundTripsEnrichment() throws {
        let suiteName = "EnrichmentCacheTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let cache = EnrichmentCache(defaults: defaults)
        #expect(cache.load().isEmpty)

        let enrichment = try #require(Offering.preview.enrichment)
        cache.save(["PNPBOND_13": enrichment])
        #expect(cache.load() == ["PNPBOND_13": enrichment])
    }
}

@MainActor
struct OfferingServiceTests {
    @Test func buildsCalendarURLForTheNextYear() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "Europe/Tallinn"))
        let date = try #require(
            calendar.date(from: DateComponents(year: 2026, month: 11, day: 23, hour: 23, minute: 30)))

        let url = try OfferingService.calendarURL(from: date, calendar: calendar)
        let components = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))
        let query = Dictionary(uniqueKeysWithValues: (components.queryItems ?? []).map { ($0.name, $0.value ?? "") })

        #expect(components.host == "nasdaqbaltic.com")
        #expect(components.path == "/statistics/en/calendar")
        #expect(query["from"] == "2026-11-23")
        #expect(query["to"] == "2027-11-23")
        #expect(query["category"] == "227")
    }
}

struct BackgroundScheduleTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Tallinn")!
        return calendar
    }

    @Test(arguments: [
        (
            DateComponents(year: 2026, month: 11, day: 23, hour: 3),
            DateComponents(year: 2026, month: 11, day: 23, hour: 6)
        ),
        (
            DateComponents(year: 2026, month: 11, day: 23, hour: 6),
            DateComponents(year: 2026, month: 11, day: 24, hour: 6)
        ),
        (
            DateComponents(year: 2026, month: 11, day: 23, hour: 18),
            DateComponents(year: 2026, month: 11, day: 24, hour: 6)
        ),
    ])
    func schedulesNextSixAM(now: DateComponents, expected: DateComponents) throws {
        let date = try #require(calendar.date(from: now))
        let next = try #require(BackgroundTaskManager.nextRunDate(after: date, calendar: calendar))
        #expect(
            calendar.dateComponents([.year, .month, .day, .hour, .minute], from: next)
                == DateComponents(year: expected.year, month: expected.month, day: expected.day, hour: 6, minute: 0))
    }
}

struct NotificationMessageTests {
    private func offerings(_ names: String...) -> [Offering] {
        names.map { Offering(ticker: $0, issuerName: $0, subscriptionStart: nil, subscriptionEnd: nil, markets: []) }
    }

    @Test func singleOffering() {
        let message = NotificationManager.message(for: offerings("PN Project"))
        #expect(message.title == "New Estonian Public Offering")
        #expect(message.body == "PN Project has a new public offering.")
    }

    @Test func twoOfferings() {
        #expect(NotificationManager.message(for: offerings("A", "B")).body == "A, B.")
    }

    @Test func manyOfferings() {
        let message = NotificationManager.message(for: offerings("A", "B", "C", "D"))
        #expect(message.title == "New Estonian Public Offerings")
        #expect(message.body == "A, B and 2 more.")
    }
}
