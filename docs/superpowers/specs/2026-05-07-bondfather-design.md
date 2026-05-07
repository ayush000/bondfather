# Bondfather — Design Spec

**Date:** 2026-05-07
**Status:** Approved

## Overview

An iOS app that fetches upcoming public offerings from the NASDAQ Baltic calendar, displays Estonian-market offerings in a list, and fires a daily local notification when new offerings appear.

## Data Source

URL: `https://nasdaqbaltic.com/statistics/en/calendar?filter=1&period=&from=<today>&to=<today+1yr>&category=227&issuer=`

The page is fetched via `URLSession`. If the site exposes a JSON API endpoint (detectable by inspecting network traffic in Safari DevTools during implementation), that is preferred over HTML scraping. Otherwise, **SwiftSoup** parses the HTML calendar table.

Displayed fields: issuer name, subscription period (start + end), listing date (nullable).

Market filter: keep only rows where the market/exchange field contains `"Tallinn"`.

## Data Model

```swift
struct Offering: Codable, Identifiable {
    let id: String           // ISIN, or SHA256(issuerName + listingDate) if ISIN absent
    let issuerName: String
    let subscriptionStart: Date?
    let subscriptionEnd: Date?
    let listingDate: Date?
    let market: String       // e.g. "Nasdaq Tallinn"
}
```

## Architecture

Four layers, each with a single responsibility:

### 1. OfferingService
- Fetches the calendar URL for today → today+1 year
- Parses the response (JSON or HTML) into `[Offering]`
- Filters to Estonian market only
- Returns `[Offering]` or throws on unrecoverable error

### 2. OfferingStore
- Persists the last-seen set of offering `id`s in `UserDefaults`
- `diff(newOfferings:) -> [Offering]` returns offerings whose `id` was not in the stored set
- `save(_ offerings:)` replaces the stored set

### 3. NotificationManager
- Wraps `UNUserNotificationCenter`
- Requests permission on first app launch
- `scheduleNewOfferingsNotification(offerings:)` fires an immediate local notification listing new issuer names

### 4. BackgroundTaskManager
- Registers `BGProcessingTask` with identifier `com.bondfather.refresh`
- On execution: calls `OfferingService` → `OfferingStore.diff` → `OfferingStore.save` → `NotificationManager` if diff is non-empty
- On completion (success or failure): reschedules for `earliestBeginDate = next occurrence of 06:00`
- Expiry handler: cancels in-flight network request, reschedules

## UI

Single `NavigationView` with a `List` of offering rows. Each row shows:
- **Issuer name** (bold title)
- Subscription period: `"May 12 – May 23"` (or `"—"` if absent)
- Listing date: `"Listing: June 3"` or `"Listing: TBD"` if nil

List is sorted by listing date ascending (nil dates at the end).

**States:**
| State | Behaviour |
|-------|-----------|
| Loading | `ProgressView` centred on screen |
| Loaded (non-empty) | List of `OfferingRow` |
| Loaded (empty) | "No upcoming Estonian public offerings" message |
| Error | "Could not load offerings. Pull to refresh." |

Pull-to-refresh triggers a fresh fetch in all states.
Notification permission prompt shown on first launch via `NotificationManager`.
No settings screen — no user-configurable options.

## Background Task Configuration

`Info.plist` key `BGTaskSchedulerPermittedIdentifiers`:
```xml
<array>
    <string>com.bondfather.refresh</string>
</array>
```

Task type: `BGProcessingTask` (preferred over `BGAppRefreshTask` for longer runtime and charging-device preference).

Scheduling: `earliestBeginDate` = next 06:00 local time. iOS may delay beyond that; this is acceptable for a daily morning check.

## Error Handling

| Context | Behaviour |
|---------|-----------|
| Network failure (background) | Silent no-op; stored snapshot unchanged; rescheduled normally |
| Parse failure (background) | Silent no-op; same as above |
| Network/parse failure (foreground) | Error state shown; pull-to-refresh retries |

No alerting, no crash reporting in this iteration.

## Testing

No automated tests in this iteration. Manual background task simulation via Xcode debugger:

```
e -l objc -- (void)[[BGTaskScheduler sharedScheduler] _simulateLaunchForTaskWithIdentifier:@"com.bondfather.refresh"]
```

## Dependencies

- **SwiftSoup** (Swift Package Manager) — HTML parsing, only needed if no JSON API is found
- No other third-party dependencies
