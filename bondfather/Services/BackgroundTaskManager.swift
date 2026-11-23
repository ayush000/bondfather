import BackgroundTasks
import os

/// Runs a daily background check for new offerings and notifies about any it hasn't seen.
final class BackgroundTaskManager {
    static let taskIdentifier = "com.bondfather.refresh"

    private let service = OfferingService()
    private let store = OfferingStore()
    private let notifications = NotificationManager()

    func registerBackgroundTask() {
        // Deliver the launch handler on the main queue, where the rest of the app's state lives.
        BGTaskScheduler.shared.register(forTaskWithIdentifier: Self.taskIdentifier, using: .main) { [weak self] task in
            guard let task = task as? BGProcessingTask else { return }
            MainActor.assumeIsolated {
                self?.handleRefresh(task: task)
            }
        }
    }

    func scheduleNextRefresh() {
        let request = BGProcessingTaskRequest(identifier: Self.taskIdentifier)
        request.requiresNetworkConnectivity = true
        request.earliestBeginDate = Self.nextRunDate(after: .now)
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            Logger.background.error("Couldn't schedule refresh: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// The next 06:00 local time after the given date.
    nonisolated static func nextRunDate(after date: Date, calendar: Calendar = .current) -> Date? {
        calendar.nextDate(after: date, matching: DateComponents(hour: 6, minute: 0), matchingPolicy: .nextTime)
    }

    private func handleRefresh(task: BGProcessingTask) {
        let work = Task {
            defer { scheduleNextRefresh() }
            do {
                let offerings = try await service.fetchOfferings()
                let newOfferings = store.newOfferings(from: offerings)
                store.markAsSeen(offerings)
                await notifications.notifyAboutNewOfferings(newOfferings)
                task.setTaskCompleted(success: true)
            } catch {
                Logger.background.error("Background refresh failed: \(error.localizedDescription, privacy: .public)")
                task.setTaskCompleted(success: false)
            }
        }

        task.expirationHandler = {
            work.cancel()
        }
    }
}
