# Bondfather Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build an iOS app that displays upcoming Estonian public offerings from NASDAQ Baltic and fires a daily local notification when new ones appear.

**Architecture:** A SwiftUI list view backed by an `OfferingsViewModel` fetches data live from `OfferingService`, which parses the NASDAQ Baltic calendar page (HTML via SwiftSoup, or JSON if a hidden API is found). A `BGProcessingTask` runs nightly while charging, diffs new offerings against a `UserDefaults`-persisted ID snapshot via `OfferingStore`, and fires a local notification via `NotificationManager` if new ones are found.

**Tech Stack:** Swift 5.9+, SwiftUI, BackgroundTasks framework, UNUserNotificationCenter, SwiftSoup (SPM), iOS 17+

---

## File Map

| File | Responsibility |
|------|---------------|
| `bondfather/Models/Offering.swift` | `Offering` struct — data model |
| `bondfather/Services/OfferingService.swift` | Fetch + parse NASDAQ Baltic calendar, filter for Tallinn |
| `bondfather/Services/OfferingStore.swift` | Persist known offering IDs in UserDefaults, compute diffs |
| `bondfather/Services/NotificationManager.swift` | Request permission, fire local notifications |
| `bondfather/Services/BackgroundTaskManager.swift` | Register + handle `BGProcessingTask`, schedule next run |
| `bondfather/ViewModels/OfferingsViewModel.swift` | `@Observable` VM — drives list view state |
| `bondfather/Views/OfferingRow.swift` | Single row: issuer name, subscription period, listing date |
| `bondfather/Views/OfferingsListView.swift` | Main list view with loading/empty/error states |
| `bondfather/bondfatherApp.swift` | App entry — register BG task, request notification permission |

---

## Task 1: Investigate the data source

**Files:** None created.

- [ ] **Step 1: Fetch the raw HTML**

Run in Terminal:
```bash
curl -s "https://nasdaqbaltic.com/statistics/en/calendar?filter=1&period=&from=2026-05-01&to=2026-12-31&category=227&issuer=" | head -300
```

- [ ] **Step 2: Check for a JSON endpoint**

Run:
```bash
curl -s -H "Accept: application/json" -H "X-Requested-With: XMLHttpRequest" \
  "https://nasdaqbaltic.com/statistics/en/calendar?filter=1&period=&from=2026-05-01&to=2026-12-31&category=227&issuer=" | head -100
```

If the response starts with `{` or `[`, it is JSON — skip SwiftSoup (Task 2) and implement JSON decoding in Task 4 instead.

- [ ] **Step 3: If HTML — identify the table structure**

Open `https://nasdaqbaltic.com/statistics/en/calendar?filter=1&period=&from=2026-05-01&to=2026-12-31&category=227&issuer=` in Safari, right-click a calendar row → Inspect Element. Note:

- The CSS selector for the table (e.g. `table.table`, `#resultsTable`)
- The column order: which `<td>` index (0-based) is issuer name, subscription period, ISIN, listing date, market/exchange

You will substitute these into Task 4.

- [ ] **Step 4: Check for XHR/Fetch calls**

In Safari DevTools → Network tab → reload the page → filter by Fetch/XHR. If a JSON endpoint appears (e.g. `/api/calendar`), use that URL in `OfferingService.buildURL()` instead of the HTML calendar URL.

---

## Task 2: Add SwiftSoup dependency

**Files:** `bondfather.xcodeproj` (via Xcode UI)

Skip this task if a JSON API was found in Task 1.

- [ ] **Step 1: Add SwiftSoup via SPM**

In Xcode: **File → Add Package Dependencies…** → enter:
```
https://github.com/scinfu/SwiftSoup
```
Set version rule to **Up to Next Major Version** from `2.7.0` → click **Add Package** → add to the `bondfather` target.

- [ ] **Step 2: Verify build**

Build (⌘B). Expected: `Build Succeeded` with no errors.

- [ ] **Step 3: Commit**

```bash
git add bondfather.xcodeproj/project.pbxproj
git commit -m "chore: add SwiftSoup dependency"
```

---

## Task 3: Create the Offering model

**Files:**
- Create: `bondfather/Models/Offering.swift`

- [ ] **Step 1: Create the file**

In Xcode: **File → New → File from Template → Swift File** → save to `bondfather/Models/Offering.swift`, ensuring the `bondfather` target is checked.

Paste:
```swift
import Foundation
import CryptoKit

struct Offering: Codable, Identifiable, Hashable {
    let id: String
    let issuerName: String
    let subscriptionStart: Date?
    let subscriptionEnd: Date?
    let listingDate: Date?
    let market: String

    static func makeId(isin: String?, issuerName: String, listingDate: Date?) -> String {
        if let isin, !isin.isEmpty { return isin }
        let raw = "\(issuerName)\(listingDate?.timeIntervalSince1970 ?? 0)"
        let digest = SHA256.hash(data: Data(raw.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
```

- [ ] **Step 2: Build to verify**

Build (⌘B). Expected: `Build Succeeded`.

- [ ] **Step 3: Commit**

```bash
git add bondfather/Models/Offering.swift
git commit -m "feat: add Offering model"
```

---

## Task 4: Implement OfferingService

**Files:**
- Create: `bondfather/Services/OfferingService.swift`

- [ ] **Step 1: Create the file**

In Xcode: **File → New → File from Template → Swift File** → save to `bondfather/Services/OfferingService.swift`, ensuring the `bondfather` target is checked.

Paste:
```swift
import Foundation
import SwiftSoup

enum OfferingServiceError: Error {
    case invalidURL
    case parseFailure
}

struct OfferingService {
    private static let inputFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "dd.MM.yyyy"
        return f
    }()

    func fetchOfferings() async throws -> [Offering] {
        let url = try buildURL()
        let (data, _) = try await URLSession.shared.data(from: url)
        let all = try parse(data: data)
        return all.filter { $0.market.localizedCaseInsensitiveContains("tallinn") }
    }

    private func buildURL() throws -> URL {
        let today = Date.now
        guard let nextYear = Calendar.current.date(byAdding: .year, value: 1, to: today) else {
            throw OfferingServiceError.invalidURL
        }
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        var components = URLComponents()
        components.scheme = "https"
        components.host = "nasdaqbaltic.com"
        components.path = "/statistics/en/calendar"
        components.queryItems = [
            .init(name: "filter", value: "1"),
            .init(name: "period", value: ""),
            .init(name: "from", value: fmt.string(from: today)),
            .init(name: "to", value: fmt.string(from: nextYear)),
            .init(name: "category", value: "227"),
            .init(name: "issuer", value: ""),
        ]
        guard let url = components.url else { throw OfferingServiceError.invalidURL }
        return url
    }

    private func parse(data: Data) throws -> [Offering] {
        guard let html = String(data: data, encoding: .utf8) else {
            throw OfferingServiceError.parseFailure
        }
        let doc = try SwiftSoup.parse(html)
        // ADJUST the CSS selector below based on Task 1 Step 3 findings.
        // Example: "table.table tbody tr" or "#calendarTable tbody tr"
        let rows = try doc.select("table tbody tr")
        return rows.compactMap { parseRow($0) }
    }

    private func parseRow(_ row: Element) -> Offering? {
        guard let cells = try? row.select("td"), cells.count >= 5 else { return nil }

        // ADJUST the column indices below based on Task 1 Step 3 findings.
        // The indices below assume: 0=subscription period, 1=issuer, 2=ISIN, 3=listing date, 4=market
        guard let issuerName = try? cells[1].text(), !issuerName.isEmpty else { return nil }

        let isin = (try? cells[2].text()) ?? ""
        let market = (try? cells[4].text()) ?? ""
        let periodText = (try? cells[0].text()) ?? ""
        let listingText = (try? cells[3].text()) ?? ""

        let (subStart, subEnd) = parseSubscriptionPeriod(periodText)
        let listingDate = Self.inputFormatter.date(from: listingText.trimmingCharacters(in: .whitespaces))

        return Offering(
            id: Offering.makeId(isin: isin.isEmpty ? nil : isin, issuerName: issuerName, listingDate: listingDate),
            issuerName: issuerName,
            subscriptionStart: subStart,
            subscriptionEnd: subEnd,
            listingDate: listingDate,
            market: market
        )
    }

    // Expected input formats: "12.05.2026 - 23.05.2026" or "12.05.2026"
    private func parseSubscriptionPeriod(_ text: String) -> (Date?, Date?) {
        let parts = text.components(separatedBy: " - ")
        let start = parts.first.flatMap {
            Self.inputFormatter.date(from: $0.trimmingCharacters(in: .whitespaces))
        }
        let end = parts.count > 1
            ? Self.inputFormatter.date(from: parts[1].trimmingCharacters(in: .whitespaces))
            : nil
        return (start, end)
    }
}
```

- [ ] **Step 2: Build to verify**

Build (⌘B). Expected: `Build Succeeded`.

- [ ] **Step 3: Commit**

```bash
git add bondfather/Services/OfferingService.swift
git commit -m "feat: add OfferingService"
```

---

## Task 5: Implement OfferingStore

**Files:**
- Create: `bondfather/Services/OfferingStore.swift`

- [ ] **Step 1: Create the file**

In Xcode: **File → New → File from Template → Swift File** → save to `bondfather/Services/OfferingStore.swift`, ensuring the `bondfather` target is checked.

Paste:
```swift
import Foundation

struct OfferingStore {
    private static let key = "com.bondfather.knownOfferingIds"

    func knownIds() -> Set<String> {
        let array = UserDefaults.standard.stringArray(forKey: Self.key) ?? []
        return Set(array)
    }

    func save(_ offerings: [Offering]) {
        UserDefaults.standard.set(offerings.map(\.id), forKey: Self.key)
    }

    func newOfferings(from offerings: [Offering]) -> [Offering] {
        let known = knownIds()
        return offerings.filter { !known.contains($0.id) }
    }
}
```

- [ ] **Step 2: Build to verify**

Build (⌘B). Expected: `Build Succeeded`.

- [ ] **Step 3: Commit**

```bash
git add bondfather/Services/OfferingStore.swift
git commit -m "feat: add OfferingStore"
```

---

## Task 6: Implement NotificationManager

**Files:**
- Create: `bondfather/Services/NotificationManager.swift`

- [ ] **Step 1: Create the file**

In Xcode: **File → New → File from Template → Swift File** → save to `bondfather/Services/NotificationManager.swift`, ensuring the `bondfather` target is checked.

Paste:
```swift
import UserNotifications

struct NotificationManager {
    func requestPermission() async {
        try? await UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound, .badge])
    }

    func scheduleNewOfferingsNotification(offerings: [Offering]) async {
        guard !offerings.isEmpty else { return }

        let content = UNMutableNotificationContent()
        if offerings.count == 1 {
            content.title = "New Estonian Public Offering"
            content.body = "\(offerings[0].issuerName) has a new public offering."
        } else {
            let names = offerings.prefix(2).map(\.issuerName).joined(separator: ", ")
            let remainder = offerings.count - 2
            content.title = "New Estonian Public Offerings"
            content.body = remainder > 0 ? "\(names) and \(remainder) more." : "\(names)."
        }
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "com.bondfather.newOfferings.\(Int(Date.now.timeIntervalSince1970))",
            content: content,
            trigger: nil
        )
        try? await UNUserNotificationCenter.current().add(request)
    }
}
```

- [ ] **Step 2: Build to verify**

Build (⌘B). Expected: `Build Succeeded`.

- [ ] **Step 3: Commit**

```bash
git add bondfather/Services/NotificationManager.swift
git commit -m "feat: add NotificationManager"
```

---

## Task 7: Implement BackgroundTaskManager

**Files:**
- Create: `bondfather/Services/BackgroundTaskManager.swift`

- [ ] **Step 1: Create the file**

In Xcode: **File → New → File from Template → Swift File** → save to `bondfather/Services/BackgroundTaskManager.swift`, ensuring the `bondfather` target is checked.

Paste:
```swift
import BackgroundTasks

final class BackgroundTaskManager {
    static let taskIdentifier = "com.bondfather.refresh"

    private let service = OfferingService()
    private let store = OfferingStore()
    private let notifications = NotificationManager()

    func registerBackgroundTask() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: Self.taskIdentifier,
            using: nil
        ) { [weak self] task in
            self?.handleRefresh(task: task as! BGProcessingTask)
        }
    }

    func scheduleNextRefresh() {
        let request = BGProcessingTaskRequest(identifier: Self.taskIdentifier)
        request.requiresNetworkConnectivity = true
        request.requiresExternalPower = false
        // Earliest start: tomorrow at 06:00 local time
        var components = Calendar.current.dateComponents([.year, .month, .day], from: Date.now)
        components.day = (components.day ?? 1) + 1
        components.hour = 6
        components.minute = 0
        request.earliestBeginDate = Calendar.current.date(from: components)
        try? BGTaskScheduler.shared.submit(request)
    }

    private func handleRefresh(task: BGProcessingTask) {
        let taskHandle = Task {
            do {
                let offerings = try await service.fetchOfferings()
                let newOnes = store.newOfferings(from: offerings)
                store.save(offerings)
                await notifications.scheduleNewOfferingsNotification(offerings: newOnes)
                task.setTaskCompleted(success: true)
            } catch {
                task.setTaskCompleted(success: false)
            }
            scheduleNextRefresh()
        }

        task.expirationHandler = {
            taskHandle.cancel()
            task.setTaskCompleted(success: false)
            self.scheduleNextRefresh()
        }
    }
}
```

- [ ] **Step 2: Build to verify**

Build (⌘B). Expected: `Build Succeeded`.

- [ ] **Step 3: Commit**

```bash
git add bondfather/Services/BackgroundTaskManager.swift
git commit -m "feat: add BackgroundTaskManager"
```

---

## Task 8: Implement OfferingsViewModel

**Files:**
- Create: `bondfather/ViewModels/OfferingsViewModel.swift`

- [ ] **Step 1: Create the file**

In Xcode: **File → New → File from Template → Swift File** → save to `bondfather/ViewModels/OfferingsViewModel.swift`, ensuring the `bondfather` target is checked.

Paste:
```swift
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
        loadState = .loading
        do {
            let offerings = try await service.fetchOfferings()
            loadState = .loaded(offerings.sorted {
                switch ($0.listingDate, $1.listingDate) {
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
```

- [ ] **Step 2: Build to verify**

Build (⌘B). Expected: `Build Succeeded`.

- [ ] **Step 3: Commit**

```bash
git add bondfather/ViewModels/OfferingsViewModel.swift
git commit -m "feat: add OfferingsViewModel"
```

---

## Task 9: Implement OfferingRow and OfferingsListView

**Files:**
- Create: `bondfather/Views/OfferingRow.swift`
- Create: `bondfather/Views/OfferingsListView.swift`

- [ ] **Step 1: Create OfferingRow.swift**

In Xcode: **File → New → File from Template → Swift File** → save to `bondfather/Views/OfferingRow.swift`, ensuring the `bondfather` target is checked.

Paste:
```swift
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
            Text(listingDateText)
                .font(.caption)
                .foregroundStyle(.tertiary)
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

    private var listingDateText: String {
        guard let date = offering.listingDate else { return "Listing: TBD" }
        return "Listing: \(Self.displayFormatter.string(from: date))"
    }
}
```

- [ ] **Step 2: Create OfferingsListView.swift**

In Xcode: **File → New → File from Template → Swift File** → save to `bondfather/Views/OfferingsListView.swift`, ensuring the `bondfather` target is checked.

Paste:
```swift
import SwiftUI

struct OfferingsListView: View {
    @State private var viewModel = OfferingsViewModel()

    var body: some View {
        NavigationView {
            content
                .navigationTitle("Estonian IPOs")
                .task { await viewModel.load() }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.loadState {
        case .loading:
            ProgressView()
        case .loaded(let offerings):
            if offerings.isEmpty {
                ContentUnavailableView(
                    "No Upcoming Offerings",
                    systemImage: "chart.line.uptrend.xyaxis",
                    description: Text("No Estonian public offerings found for the next year.")
                )
            } else {
                List(offerings) { offering in
                    OfferingRow(offering: offering)
                }
                .refreshable { await viewModel.load() }
            }
        case .error:
            ContentUnavailableView(
                "Could not load offerings",
                systemImage: "exclamationmark.triangle",
                description: Text("Pull to refresh.")
            )
            .refreshable { await viewModel.load() }
        }
    }
}
```

- [ ] **Step 3: Build to verify**

Build (⌘B). Expected: `Build Succeeded`.

- [ ] **Step 4: Commit**

```bash
git add bondfather/Views/OfferingRow.swift bondfather/Views/OfferingsListView.swift
git commit -m "feat: add OfferingRow and OfferingsListView"
```

---

## Task 10: Wire up the app entry point and configure Background Modes

**Files:**
- Modify: `bondfather/bondfatherApp.swift`
- Delete: `bondfather/ContentView.swift` (no longer used)
- Modify: `bondfather/Info.plist` (via Xcode target settings)

- [ ] **Step 1: Replace bondfatherApp.swift**

Replace the full contents of `bondfather/bondfatherApp.swift`:

```swift
import SwiftUI

@main
struct bondfatherApp: App {
    private let backgroundTaskManager = BackgroundTaskManager()
    private let notificationManager = NotificationManager()

    init() {
        backgroundTaskManager.registerBackgroundTask()
    }

    var body: some Scene {
        WindowGroup {
            OfferingsListView()
                .task {
                    await notificationManager.requestPermission()
                    backgroundTaskManager.scheduleNextRefresh()
                }
        }
    }
}
```

- [ ] **Step 2: Delete ContentView.swift**

In Xcode: right-click `ContentView.swift` → Delete → Move to Trash.

- [ ] **Step 3: Add BGTaskSchedulerPermittedIdentifiers to Info.plist**

In Xcode: select the `bondfather` target → **Info** tab → under "Custom iOS Target Properties", add a new row:

| Key | Type | Value |
|-----|------|-------|
| `BGTaskSchedulerPermittedIdentifiers` | Array | (item 0) `com.bondfather.refresh` |

- [ ] **Step 4: Enable Background Processing capability**

In Xcode: select the `bondfather` target → **Signing & Capabilities** tab → click `+` → add **Background Modes** → check **Background processing** (not background fetch).

- [ ] **Step 5: Build and run on a physical device**

Background tasks do not run in the Simulator. Connect an iPhone, select it as the run destination, build and run (⌘R). Expected: app opens, shows a loading spinner, then either a list of offerings or the empty state.

- [ ] **Step 6: Simulate the background task**

With the app in the foreground and Xcode's debugger attached, pause execution, run in the Xcode console:

```
e -l objc -- (void)[[BGTaskScheduler sharedScheduler] _simulateLaunchForTaskWithIdentifier:@"com.bondfather.refresh"]
```

Resume. Expected: background task fires, fetches data, `store.save()` is called. On the second run (after the store is seeded), no notification fires. To test a notification, clear the store first:

```swift
UserDefaults.standard.removeObject(forKey: "com.bondfather.knownOfferingIds")
```

Then simulate the task again. Expected: a local notification appears immediately.

- [ ] **Step 7: Commit**

```bash
git add bondfather/bondfatherApp.swift
git commit -m "feat: wire up app entry point, background task, and notification permission"
```

---

## Task 11: Verify HTML parsing against live data

**Files:**
- Modify: `bondfather/Services/OfferingService.swift` (selector/index adjustments if needed)

- [ ] **Step 1: Add a temporary debug print**

In `OfferingsListView.swift`, temporarily add inside the `.task` modifier:

```swift
.task {
    await viewModel.load()
    if case .loaded(let offerings) = viewModel.loadState {
        print("Parsed \(offerings.count) offerings")
        offerings.forEach { print($0) }
    }
}
```

- [ ] **Step 2: Run on device and inspect console**

Run the app. In Xcode's console, verify:
- `Parsed N offerings` where N > 0 (if any offerings currently exist on the site)
- Each `Offering` has a non-empty `issuerName` and correct `market` value containing "Tallinn"

If `N == 0` but the site shows offerings, the CSS selector or column indices in `OfferingService.parseRow` are wrong. Open the NASDAQ Baltic page in Safari, inspect the HTML table structure, and update the selector and column indices accordingly.

- [ ] **Step 3: Remove the debug print**

Remove the temporary debug print added in Step 1.

- [ ] **Step 4: Commit any parsing fixes**

```bash
git add bondfather/Services/OfferingService.swift
git commit -m "fix: adjust HTML parsing selectors for live data"
```
