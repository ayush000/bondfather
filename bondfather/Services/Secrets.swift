import Foundation

enum Secrets {
    static var geminiAPIKey: String? {
        guard let url = Bundle.main.url(forResource: "Secrets", withExtension: "plist"),
              let data = try? Data(contentsOf: url),
              let dict = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
              let key = dict["GEMINI_API_KEY"] as? String,
              !key.isEmpty,
              key != "YOUR_GEMINI_API_KEY"
        else { return nil }
        return key
    }
}
