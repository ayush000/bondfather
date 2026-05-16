import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    var onSave: () -> Void

    @State private var apiKey: String = Secrets.geminiAPIKey ?? ""
    @State private var hasExistingKey: Bool = Secrets.geminiAPIKey != nil

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    SecureField("AIza…", text: $apiKey)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                } header: {
                    Text("Gemini API Key")
                } footer: {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Used to generate the issuer insights shown on each bond. The key is stored only on this device, in the iOS Keychain.")
                        Link("Get a free key at aistudio.google.com",
                             destination: URL(string: "https://aistudio.google.com/apikey")!)
                    }
                }

                if hasExistingKey {
                    Section {
                        Button("Remove key", role: .destructive) {
                            Secrets.clearGeminiAPIKey()
                            apiKey = ""
                            hasExistingKey = false
                            onSave()
                        }
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Secrets.setGeminiAPIKey(apiKey)
                        onSave()
                        dismiss()
                    }
                    .disabled(apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}
