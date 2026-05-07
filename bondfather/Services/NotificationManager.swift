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
            identifier: "com.bondfather.newOfferings",
            content: content,
            trigger: nil
        )
        try? await UNUserNotificationCenter.current().add(request)
    }
}
