import Foundation
import os

nonisolated extension Logger {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "bondfather"

    static let offerings = Logger(subsystem: subsystem, category: "offerings")
    static let gemini = Logger(subsystem: subsystem, category: "gemini")
    static let background = Logger(subsystem: subsystem, category: "background")
    static let notifications = Logger(subsystem: subsystem, category: "notifications")
    static let keychain = Logger(subsystem: subsystem, category: "keychain")
}
