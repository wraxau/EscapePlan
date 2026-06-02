import Foundation

// MARK: - Service Errors

enum GeminiError: LocalizedError {
    case networkError(String)
    case apiError(String)
    case emptyResponse
    case missingAPIKey

    var errorDescription: String? {
        switch self {
        case .networkError(let msg): return "Ошибка сети: \(msg)"
        case .apiError(let msg):     return "Ошибка Groq: \(msg)"
        case .emptyResponse:         return "Пустой ответ. Попробуй ещё раз."
        case .missingAPIKey:         return "AI-ассистент временно недоступен."
        }
    }
}

// MARK: - API Models

private struct DSMessage: Codable {
    let role: String
    let content: String
}

private struct DSRequest: Encodable {
    let model: String
    let messages: [DSMessage]
    let temperature: Double
    let maxTokens: Int

    enum CodingKeys: String, CodingKey {
        case model, messages, temperature
        case maxTokens = "max_tokens"
    }
}

private struct DSChoice: Decodable {
    struct DSInnerMessage: Decodable { let content: String }
    let message: DSInnerMessage
}

private struct DSResponse: Decodable {
    let choices: [DSChoice]?
}

// MARK: - Groq Service

final class GeminiService {

    static let shared = GeminiService()
    private var apiKey: String? {
        guard let key = Bundle.main.infoDictionary?["GROQ_API_KEY"] as? String,
              !key.isEmpty else {
            return nil
        }
        return key
    }

    private let chatURL = "https://api.groq.com/openai/v1/chat/completions"
    private let model   = "llama-3.3-70b-versatile"

    private let systemPrompt = """
    Ты — умный туристический ассистент в приложении TripPlanner. \
    Помогаешь пользователям планировать поездки: рассказываешь о климате, транспорте, \
    достопримечательностях, местных традициях, безопасности, связи, \
    обмене валют и даёшь практические советы по бюджету. \
    Отвечай кратко и по делу. Используй эмодзи умеренно, максимум 2 эмодзи в ответе. Если ответ короче 100 символов, то можно использовать только один эмодзи \
    Если упоминается конкретная страна или город — давай советы именно для этого места. \
    Всегда отвечай на языке вопроса.
    """

    private init() {}

    // MARK: - Send Message

    func send(
        userMessage: String,
        history: [(role: String, text: String)]
    ) async throws -> String {

        guard let key = apiKey else {
            throw GeminiError.missingAPIKey
        }

        guard let url = URL(string: chatURL) else {
            throw GeminiError.networkError("Некорректный URL")
        }

        var messages: [DSMessage] = [DSMessage(role: "system", content: systemPrompt)]
        messages += history.map { DSMessage(role: $0.role, content: $0.text) }
        messages.append(DSMessage(role: "user", content: userMessage))

        let body = DSRequest(model: model, messages: messages, temperature: 0.8, maxTokens: 1000)

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)
        request.timeoutInterval = 30

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? 0
            let body = String(data: data, encoding: .utf8) ?? ""
            throw GeminiError.apiError("HTTP \(code). \(body.prefix(120))")
        }

        let decoded = try JSONDecoder().decode(DSResponse.self, from: data)

        guard let text = decoded.choices?.first?.message.content,
              !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw GeminiError.emptyResponse
        }

        return text
    }
}
