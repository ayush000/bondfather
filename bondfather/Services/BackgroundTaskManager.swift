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
