import SwiftUI

struct SettingsView: View {
    var body: some View {
        NavigationStack {
            Form {
                #if DEBUG
                DeveloperConnectionSection()
                #endif

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

#if DEBUG
/// Lets you point a development build at a local or staging server, or use a personal API key.
/// Not compiled into TestFlight or App Store builds.
private struct DeveloperConnectionSection: View {
    @AppStorage(AppSettings.modeKey) private var mode = ConnectionMode.server
    @AppStorage(AppSettings.serverURLKey) private var serverURL = ""
    @State private var apiKey = Keychain.get(AppSettings.apiKeyAccount) ?? ""

    var body: some View {
        Section {
            Picker("Connect through", selection: $mode) {
                ForEach(ConnectionMode.available) { Text($0.title).tag($0) }
            }
            switch mode {
            case .server:
                TextField(AppSettings.defaultServerURL.isEmpty ? "your-site.netlify.app" : AppSettings.defaultServerURL,
                          text: $serverURL)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            case .apiKey:
                SecureField("sk-ant-…", text: $apiKey)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .onChange(of: apiKey) { _, newValue in
                        Keychain.set(newValue.trimmingCharacters(in: .whitespacesAndNewlines),
                                     for: AppSettings.apiKeyAccount)
                    }
            }
        } header: {
            Text("Developer")
        } footer: {
            switch mode {
            case .server:
                Text("Leave blank to use the built-in server. Only shown in development builds.")
            case .apiKey:
                Text("Calls Claude directly with a key stored in this device's Keychain. Only available in development builds.")
            }
        }
    }
}
#endif
