import Foundation

enum Secrets {
    private static let geminiKey = "gemini_api_key"

    static var geminiAPIKey: String? {
        guard let value = KeychainStore.getString(forKey: geminiKey)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
              !value.isEmpty
        else { return nil }
        return value
    }

    static func setGeminiAPIKey(_ value: String) {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            KeychainStore.delete(forKey: geminiKey)
        } else {
            KeychainStore.setString(trimmed, forKey: geminiKey)
        }
    }

    static func clearGeminiAPIKey() {
        KeychainStore.delete(forKey: geminiKey)
    }
}
