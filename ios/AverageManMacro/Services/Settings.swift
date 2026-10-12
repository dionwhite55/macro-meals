import Foundation
import Security

/// How the app reaches Claude.
enum ConnectionMode: String, CaseIterable, Identifiable {
    /// Through the Netlify function (`/api/chat`), which holds the API key server-side.
    case server
    /// Directly to the Anthropic API with a key stored in this device's Keychain. Debug builds only.
    case apiKey

    var id: String { rawValue }
    var title: String {
        switch self {
        case .server: "Netlify server"
        case .apiKey: "My own API key"
        }
    }

    /// TestFlight and App Store builds only ever use the server.
    static var available: [ConnectionMode] {
        #if DEBUG
        allCases
        #else
        [.server]
        #endif
    }
}

enum AppSettings {
    /// The deployed Netlify site that hosts `/api/chat`. Set this before shipping a beta,
    /// e.g. "https://your-site.netlify.app".
    static let defaultServerURL = ""

    static let modeKey = "connectionMode"
    static let serverURLKey = "serverURL"
    static let apiKeyAccount = "anthropicAPIKey"

    static var mode: ConnectionMode {
        let stored = ConnectionMode(rawValue: UserDefaults.standard.string(forKey: modeKey) ?? "") ?? .server
        return ConnectionMode.available.contains(stored) ? stored : .server
    }

    /// The server URL override from Settings (debug builds), falling back to the built-in one.
    static var serverURL: String {
        #if DEBUG
        let override = UserDefaults.standard.string(forKey: serverURLKey)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !override.isEmpty { return override }
        #endif
        return defaultServerURL
    }

    static var apiKey: String? {
        Keychain.get(apiKeyAccount)
    }
}

enum Keychain {
    private static let service = "com.dionwhite.AverageManMacro"

    static func get(_ account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func set(_ value: String?, for account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(query as CFDictionary)
        guard let value, !value.isEmpty else { return }
        var attributes = query
        attributes[kSecValueData as String] = Data(value.utf8)
        // Never leaves this device: excluded from backups and device-to-device transfers.
        attributes[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        SecItemAdd(attributes as CFDictionary, nil)
    }
}
