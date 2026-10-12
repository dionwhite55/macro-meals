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
    case notConfigured
    case server(status: Int, message: String)
    case refused
    case unreadableResponse

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            "Set up a connection in Settings first."
        case .server(let status, let message):
            "Server error (\(status)): \(message)"
        case .refused:
            "Claude couldn't estimate that one. Try describing it differently."
        case .unreadableResponse:
            "Got an unexpected response. Please try again."
        }
    }
}

/// Talks to Claude to estimate and adjust macros. Same requests the web app makes,
/// plus fiber, using structured outputs so the reply is always valid JSON.
enum MacroService {
    static let model = "claude-haiku-5-5"

    private static let guidance = """
    The user wants a reasonable ballpark, not lab precision. Assume typical portions \
    unless they say otherwise, and round to whole numbers.
    """

    static func estimate(_ description: String) async throws -> MacroEstimate {
        let prompt = """
        Estimate the nutrition for this meal: "\(description)"

        \(guidance) Give it a short, plain meal name.
        """
        return try await send(prompt: prompt, includeName: true, includeExplanation: false)
    }

    static func adjust(name: String, macros: Macros, request: String) async throws -> MacroEstimate {
        let prompt = """
        Meal: \(name)
        Current estimate:
        - Calories: \(macros.calories)
        - Protein: \(macros.protein)g
        - Carbs: \(macros.carbs)g
        - Fat: \(macros.fat)g
        - Fiber: \(macros.fiber)g

        User adjustment: "\(request)"

        Recalculate the macros with this adjustment. \(guidance) \
        In explanation, briefly say what changed in one sentence.
        """
        return try await send(prompt: prompt, includeName: false, includeExplanation: true)
    }

    // MARK: - Request plumbing

    private static func schema(includeName: Bool, includeExplanation: Bool) -> [String: Any] {
        var properties: [String: Any] = [:]
        var required: [String] = []
        if includeName {
            properties["name"] = ["type": "string"]
            required.append("name")
        }
        for key in ["calories", "protein", "carbs", "fat", "fiber"] {
            properties[key] = ["type": "number"]
            required.append(key)
        }
        if includeExplanation {
            properties["explanation"] = ["type": "string"]
            required.append("explanation")
        }
        return [
            "type": "object",
            "properties": properties,
            "required": required,
            "additionalProperties": false,
        ]
    }

    private static func send(prompt: String, includeName: Bool, includeExplanation: Bool) async throws -> MacroEstimate {
        let body: [String: Any] = [
            "model": model,
            "max_tokens": 4000,
            "output_config": [
                "effort": "low",
                "format": [
                    "type": "json_schema",
                    "schema": schema(includeName: includeName, includeExplanation: includeExplanation),
                ],
            ],
            "messages": [["role": "user", "content": prompt]],
        ]

        var request = try makeRequest()
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        request.timeoutInterval = 60

        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard status == 200 else {
            throw MacroServiceError.server(status: status, message: errorMessage(from: data))
        }

        let message = try JSONDecoder().decode(APIMessage.self, from: data)
        if message.stopReason == "refusal" { throw MacroServiceError.refused }

        let text = message.content
            .filter { $0.type == "text" }
            .compactMap(\.text)
            .joined()
        guard message.stopReason != "max_tokens",
              let json = text.data(using: .utf8),
              let estimate = try? JSONDecoder().decode(MacroEstimate.self, from: json)
        else { throw MacroServiceError.unreadableResponse }
        return estimate
    }

    private static func makeRequest() throws -> URLRequest {
        switch AppSettings.mode {
        case .server:
            var base = AppSettings.serverURL.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !base.isEmpty else { throw MacroServiceError.notConfigured }
            if !base.contains("://") { base = "https://" + base }
            while base.hasSuffix("/") { base.removeLast() }
            guard let url = URL(string: base + "/api/chat") else { throw MacroServiceError.notConfigured }
            return URLRequest(url: url)

        case .apiKey:
            guard let key = AppSettings.apiKey, !key.isEmpty else { throw MacroServiceError.notConfigured }
            var request = URLRequest(url: URL(string: "https://api.anthropic.com/v1/messages")!)
            request.setValue(key, forHTTPHeaderField: "x-api-key")
            request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
            return request
        }
    }

    private static func errorMessage(from data: Data) -> String {
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            if let error = json["error"] as? [String: Any], let message = error["message"] as? String {
                return message
            }
            if let message = json["error"] as? String { return message }
        }
        return String(data: data, encoding: .utf8).map { String($0.prefix(200)) } ?? "Unknown error"
    }

    private struct APIMessage: Decodable {
        struct Block: Decodable {
            var type: String
            var text: String?
        }

        var content: [Block]
        var stopReason: String?

        enum CodingKeys: String, CodingKey {
            case content
            case stopReason = "stop_reason"
        }
    }
}
