import SwiftUI

struct SettingsView: View {
    private var version: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = info?["CFBundleVersion"] as? String ?? "1"
        return "\(short) (\(build))"
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    LabeledContent("Version", value: version)
                } header: {
                    Text("About")
                } footer: {
                    Text("Average Man Macro: a good idea of what you're eating, without the obsessing.")
                }

                Section("How estimates work") {
                    Text("When you describe a meal or ask for an adjustment, that text is sent to Anthropic's Claude AI to estimate its nutrition. Nothing else about you is sent, and your meal log and favorites stay on this phone.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text("Estimates are ballparks, not medical or dietary advice.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Settings")
        }
    }
}
