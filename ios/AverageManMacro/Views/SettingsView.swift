import SwiftUI

struct SettingsView: View {
    @AppStorage(AppSettings.modeKey) private var mode = ConnectionMode.server
    @AppStorage(AppSettings.serverURLKey) private var serverURL = ""
    @State private var apiKey = Keychain.get(AppSettings.apiKeyAccount) ?? ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Connect through", selection: $mode) {
                        ForEach(ConnectionMode.allCases) { Text($0.title).tag($0) }
                    }
                } header: {
                    Text("Macro estimates")
                } footer: {
                    switch mode {
                    case .server:
                        Text("Uses the same /api/chat function as the web app, so your API key stays on Netlify.")
                    case .apiKey:
                        Text("Calls Claude directly. The key is stored in this device's Keychain. Good for personal use; don't ship an app this way.")
                    }
                }

                switch mode {
                case .server:
                    Section("Site URL") {
                        TextField("your-site.netlify.app", text: $serverURL)
                            .keyboardType(.URL)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    }
                case .apiKey:
                    Section("Anthropic API key") {
                        SecureField("sk-ant-…", text: $apiKey)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .onChange(of: apiKey) { _, newValue in
                                Keychain.set(newValue.trimmingCharacters(in: .whitespacesAndNewlines),
                                             for: AppSettings.apiKeyAccount)
                            }
                    }
                }

                Section {
                    LabeledContent("Model", value: MacroService.model)
                    LabeledContent("Version", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                } header: {
                    Text("About")
                } footer: {
                    Text("Average Man Macro: a good idea of what you're eating, without the obsessing.")
                }
            }
            .navigationTitle("Settings")
        }
    }
}
