import Foundation
import Security

/// How the app reaches Claude.
enum ConnectionMode: String, CaseIterable, Identifiable {
    /// Through the existing Netlify function (`/api/chat`), which holds the API key server-side.
    case server
    /// Directly to the Anthropic API with a key stored in this device's Keychain.
    case apiKey

    var id: String { rawValue }
    var title: String {
        switch self {
        case .server: "My Netlify site"
        case .apiKey: "My own API key"
        }
    }
}

enum AppSettings {
    static let modeKey = "connectionMode"
    static let serverURLKey = "serverURL"
    static let apiKeyAccount = "anthropicAPIKey"

    static var mode: ConnectionMode {
        ConnectionMode(rawValue: UserDefaults.standard.string(forKey: modeKey) ?? "") ?? .server
    }

    static var serverURL: String {
        UserDefaults.standard.string(forKey: serverURLKey) ?? ""
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
        attributes[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        SecItemAdd(attributes as CFDictionary, nil)
    }
}
