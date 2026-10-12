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
    case server(String)
    case rateLimited
    case refused
    case unreadableResponse

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            "The estimate service isn't set up yet."
        case .server(let message):
            message
        case .rateLimited:
            "Too many requests. Wait a minute and try again."
        case .refused:
            "Claude couldn't estimate that one. Try describing it differently."
        case .unreadableResponse:
            "Got an unexpected response. Please try again."
        }
    }
}

/// Gets macro estimates from Claude. Normally goes through the Netlify function, which
/// owns the model, prompt and limits (see lib/macro-api.mjs). Debug builds can instead call
/// the Anthropic API directly with a personal key, mirroring the server's request.
enum MacroService {
    static let model = "claude-haiku-5-5"

    // Must match LIMITS in lib/macro-api.mjs.
    static let maxDescriptionLength = 500
    static let maxRequestLength = 300
    private static let maxNameLength = 100

    static func estimate(_ description: String) async throws -> MacroEstimate {
        switch AppSettings.mode {
        case .server:
            return try await callServer(["type": "estimate", "description": description])
        case .apiKey:
            let prompt = """
            Estimate the nutrition for this meal: "\(description)"

            \(guidance) Give it a short, plain meal name.
            """
            return try await callClaude(prompt: prompt, includeName: true, includeExplanation: false)
        }
    }

    static func adjust(name: String, macros: Macros, request: String) async throws -> MacroEstimate {
        let name = String(name.prefix(maxNameLength))
        switch AppSettings.mode {
        case .server:
            return try await callServer([
                "type": "adjust",
                "name": name,
                "request": request,
                "macros": [
                    "calories": macros.calories,
                    "protein": macros.protein,
                    "carbs": macros.carbs,
                    "fat": macros.fat,
                    "fiber": macros.fiber,
                ],
            ])
        case .apiKey:
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
            In explanation, tell the user in one short sentence what changed, speaking to them as "you".
            """
            return try await callClaude(prompt: prompt, includeName: false, includeExplanation: true)
        }
    }

    // MARK: - Netlify server

    private static func callServer(_ payload: [String: Any]) async throws -> MacroEstimate {
        var base = AppSettings.serverURL
        guard !base.isEmpty else { throw MacroServiceError.notConfigured }
        if !base.contains("://") { base = "https://" + base }
        while base.hasSuffix("/") { base.removeLast() }
        guard let url = URL(string: base + "/api/chat") else { throw MacroServiceError.notConfigured }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        request.timeoutInterval = 60

        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard status == 200 else {
            if status == 429 { throw MacroServiceError.rateLimited }
            throw MacroServiceError.server(errorMessage(from: data) ?? "Something went wrong (\(status)). Please try again.")
        }
        guard let estimate = try? JSONDecoder().decode(MacroEstimate.self, from: data) else {
            throw MacroServiceError.unreadableResponse
        }
        return estimate
    }

    // MARK: - Direct to Anthropic (debug builds)

    private static let guidance = """
    The user wants a reasonable ballpark, not lab precision. Assume typical portions \
    unless they say otherwise, and round to whole numbers.
    """

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

    private static func callClaude(prompt: String, includeName: Bool, includeExplanation: Bool) async throws -> MacroEstimate {
        guard let key = AppSettings.apiKey, !key.isEmpty else { throw MacroServiceError.notConfigured }

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

        var request = URLRequest(url: URL(string: "https://api.anthropic.com/v1/messages")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(key, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        request.timeoutInterval = 60

        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard status == 200 else {
            if status == 429 { throw MacroServiceError.rateLimited }
            throw MacroServiceError.server("Anthropic error (\(status)): \(errorMessage(from: data) ?? "unknown")")
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

    private static func errorMessage(from data: Data) -> String? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        if let error = json["error"] as? [String: Any], let message = error["message"] as? String {
            return message
        }
        return json["error"] as? String
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
