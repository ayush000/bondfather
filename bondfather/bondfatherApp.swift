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
