<img src="bondfather/Assets.xcassets/AppIcon.appiconset/AppIcon.png" alt="Bondfather app icon" width="96" align="right">

# Bondfather

An iOS app that tracks upcoming public bond offerings on Nasdaq Tallinn and notifies you when a new one shows up.

## Features

- **Upcoming offerings:** reads the [Nasdaq Baltic calendar](https://nasdaqbaltic.com/statistics/en/calendar) for the next 12 months, keeps offerings listed on the Tallinn market, and sorts them by subscription start date. Each row shows the issuer, the subscription period, and the interest rate.
- **Bond details:** opens each offering's announcement and pulls out the ISIN, price per security, minimum investment, interest rate, and settlement date.
- **Issuer insights (optional):** if you add a Gemini API key, each issuer gets a short AI-generated profile: sector, a business summary, company age, how well known it is, a relative risk score from 1 to 5, and how likely the offering is to be oversubscribed. Pull to refresh on the detail screen to regenerate it.
- **New-offering alerts:** a background task checks once a day, from 06:00 at the earliest, and sends a local notification for any offering it hasn't seen before. iOS decides exactly when the task runs.

## Install

Bondfather isn't on the App Store. Builds are published on the [Releases](https://github.com/ayush000/bondfather/releases) page and through an [AltStore](https://altstore.io) source:

1. Install AltStore on your iPhone or iPad.
2. In AltStore, open **Sources**, tap **+**, and add:

   ```
   https://raw.githubusercontent.com/ayush000/bondfather/main/altstore-source.json
   ```

3. Install Bondfather from that source.

On first launch the app asks for permission to send notifications, then opens Settings so you can add a Gemini API key. The key is optional. Without it you still get the list, the bond details, and the alerts, just not the issuer insights.

## Gemini API key

Get a free key at [aistudio.google.com/apikey](https://aistudio.google.com/apikey) and paste it into Settings (the gear icon). The key stays on the device, in the iOS Keychain.

To generate insights, the app sends each issuer's name and ticker to Google's Gemini API (`gemini-4-hydrogen`). If that model is unavailable to your key, out of quota, overloaded, or returns an unusable answer, the app retries once with `gemini-3.8-flash`. The key goes in a request header, not the URL. Results are cached on the device, so each offering is looked up once unless you refresh it.

## Build from source

You need Xcode 26.4 or later. The deployment target is iOS 26.4, and there are no third-party dependencies.

1. Open `bondfather.xcodeproj`.
2. Under **Signing & Capabilities**, pick your own team. If Xcode can't register the bundle identifier `icedev.bondfather`, change it to one of your own.
3. Run the `bondfather` scheme.

To build an IPA for sideloading, set `teamID` in `ExportOptions.plist` to your team ID, archive the app:

```bash
xcodebuild -project bondfather.xcodeproj -scheme bondfather -configuration Release -archivePath build/bondfather.xcarchive -allowProvisioningUpdates archive
```

then export the IPA:

```bash
xcodebuild -exportArchive -archivePath build/bondfather.xcarchive -exportOptionsPlist ExportOptions.plist -exportPath build/ipa -allowProvisioningUpdates
```

`-allowProvisioningUpdates` lets Xcode create or renew the development provisioning profile. Without it, the archive fails if no valid profile is cached. The IPA ends up at `build/ipa/bondfather.ipa`. To publish a release, upload it to a GitHub release and add a matching entry to `versions` in `altstore-source.json`, with the version, the date, the download URL, and the file size in bytes.

### Tests and linting

Unit tests use Swift Testing and cover the HTML parsing, the Gemini request and response, and the stores. Run them on any iOS 26.4+ simulator:

```bash
xcodebuild test -project bondfather.xcodeproj -scheme bondfather -destination 'platform=iOS Simulator,name=iPhone 17' CODE_SIGNING_ALLOWED=NO
```

Code style is checked with `swift-format`, which ships with Xcode. The settings are in `.swift-format`:

```bash
xcrun swift-format lint --strict --recursive bondfather bondfatherTests
```

To fix formatting in place, run `xcrun swift-format format --in-place --recursive bondfather bondfatherTests`. GitHub Actions runs the lint and the tests on every push to `main` and on pull requests.

### Triggering the background refresh

iOS won't run the daily task on demand. To test it, run the app from Xcode, pause the debugger, and enter:

```
e -l objc -- (void)[[BGTaskScheduler sharedScheduler] _simulateLaunchForTaskWithIdentifier:@"com.bondfather.refresh"]
```

Then resume the app. To get a notification, there has to be an offering the app hasn't recorded yet.

## How it works

```
bondfather/
├── Models/          Offering and AI enrichment types
├── Services/
│   ├── OfferingService         loads the calendar and announcement pages, attaches enrichment
│   ├── OfferingParser          parses the calendar and announcement HTML
│   ├── GeminiService           issuer insights via Gemini structured JSON output
│   ├── EnrichmentCache         cached Gemini results, stored in UserDefaults
│   ├── BackgroundTaskManager   daily BGProcessingTask (com.bondfather.refresh)
│   ├── OfferingStore           IDs of offerings already seen, used to detect new ones
│   ├── NotificationManager     local notifications
│   ├── KeychainStore, Secrets  Gemini API key storage
│   └── Logging                 os.Logger categories
├── ViewModels/      list loading state
└── Views/           SwiftUI list, detail, and settings screens
bondfatherTests/     unit tests
```

- Offerings are keyed by ticker. If an offering has no ticker, a SHA-256 hash of the issuer name is used instead.
- The calendar and announcement pages are parsed with regular expressions, so a layout change on nasdaqbaltic.com can break parsing. The parser tests use markup taken from the live pages.
- Errors are logged with `os.Logger` under the app's bundle identifier. Filter by it in Console.app to debug a device.
- The original design spec and implementation plan are in [`docs/superpowers`](docs/superpowers). The code has since moved on from them in places.

## Disclaimer

Issuer insights are generated by an LLM from public knowledge and may be wrong or out of date. They aren't investment advice. Read the offering's prospectus before you invest.
