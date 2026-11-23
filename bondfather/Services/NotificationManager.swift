import UserNotifications
import os

struct NotificationManager {
    private static let newOfferingsIdentifier = "com.bondfather.newOfferings"

    func requestPermission() async {
        do {
            _ = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            Logger.notifications.error(
                "Notification permission request failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    func notifyAboutNewOfferings(_ offerings: [Offering]) async {
        guard !offerings.isEmpty else { return }

        let content = UNMutableNotificationContent()
        (content.title, content.body) = Self.message(for: offerings)
        content.sound = .default

        // Reusing the identifier replaces an older alert instead of stacking them.
        let request = UNNotificationRequest(identifier: Self.newOfferingsIdentifier, content: content, trigger: nil)
        do {
            try await UNUserNotificationCenter.current().add(request)
        } catch {
            Logger.notifications.error(
                "Couldn't schedule notification: \(error.localizedDescription, privacy: .public)")
        }
    }

    nonisolated static func message(for offerings: [Offering]) -> (title: String, body: String) {
        if offerings.count == 1 {
            return ("New Estonian Public Offering", "\(offerings[0].issuerName) has a new public offering.")
        }
        let names = offerings.prefix(2).map(\.issuerName).joined(separator: ", ")
        let remainder = offerings.count - 2
        return ("New Estonian Public Offerings", remainder > 0 ? "\(names) and \(remainder) more." : "\(names).")
    }
}
