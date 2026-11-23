import SwiftUI

@main
struct BondfatherApp: App {
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
