import Foundation

struct MacroEstimate: Decodable {
    var name: String?
    var calories: Double
    var protein: Double
    var carbs: Double
    var fat: Double
    var fiber: Double
    var explanation: String?

    var macros: Macros {
        Macros(calories: calories, protein: protein, carbs: carbs, fat: fat, fiber: fiber)
    }
}

enum MacroServiceError: LocalizedError {
    case server(String)
    case rateLimited
    case unreadableResponse

    var errorDescription: String? {
        switch self {
        case .server(let message):
            message
        case .rateLimited:
            "Too many requests. Wait a minute and try again."
        case .unreadableResponse:
            "Got an unexpected response. Please try again."
        }
    }
}

/// Gets macro estimates from the Netlify function, which owns the model, prompt and limits
/// (see lib/macro-api.mjs).
enum MacroService {
    // Must match LIMITS in lib/macro-api.mjs.
    static let maxDescriptionLength = 500
    static let maxRequestLength = 300
    private static let maxNameLength = 100

    private static let endpoint = URL(string: AppSettings.serverURL + "/api/chat")!

    static func estimate(_ description: String) async throws -> MacroEstimate {
        try await call(["type": "estimate", "description": description])
    }

    static func adjust(name: String, macros: Macros, request: String) async throws -> MacroEstimate {
        try await call([
            "type": "adjust",
            "name": String(name.prefix(maxNameLength)),
            "request": request,
            "macros": [
                "calories": macros.calories,
                "protein": macros.protein,
                "carbs": macros.carbs,
                "fat": macros.fat,
                "fiber": macros.fiber,
            ],
        ])
    }

    private static func call(_ payload: [String: Any]) async throws -> MacroEstimate {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        request.timeoutInterval = 60

        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard status == 200 else {
            if status == 429 { throw MacroServiceError.rateLimited }
            let message = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])?["error"] as? String
            throw MacroServiceError.server(message ?? "Something went wrong (\(status)). Please try again.")
        }
        guard let estimate = try? JSONDecoder().decode(MacroEstimate.self, from: data) else {
            throw MacroServiceError.unreadableResponse
        }
        return estimate
    }
}
