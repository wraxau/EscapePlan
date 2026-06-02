import SwiftUI
import Combine

// MARK: - Chat Message Model

struct ChatMessage: Identifiable {
    let id = UUID()
    let role: MessageRole
    let text: String
    let timestamp: Date = Date()

    enum MessageRole {
        case user, assistant
    }
}

// MARK: - AIAssistantViewModel

@MainActor
final class AIAssistantViewModel: ObservableObject {

    @Published var messages: [ChatMessage] = []
    @Published var inputText: String = ""
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil

    let suggestions: [String] = [
        "Что взять в поездку в Японию? 🗾",
        "Советы по бюджету в Европе 💶",
        "Как выгодно обменять валюту?",
        "Что нужно знать о визах?",
        "Лучшее время для поездки в Таиланд 🌴",
    ]

    private let gemini = GeminiService.shared
    private let maxHistoryCount = 20

    // MARK: - Send Message

    func send() async {
        let text = inputText.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty, !isLoading else { return }

        inputText = ""
        errorMessage = nil

        messages.append(ChatMessage(role: .user, text: text))
        isLoading = true

        let historyForAPI = messages
            .dropLast()
            .suffix(maxHistoryCount)
            .map { (role: $0.role == .user ? "user" : "assistant", text: $0.text) }

        do {
            let reply = try await gemini.send(userMessage: text, history: historyForAPI)
            messages.append(ChatMessage(role: .assistant, text: reply))
        } catch {
            let nsError = error as NSError
            errorMessage = "\(error.localizedDescription) [code: \(nsError.code)]"
        }

        isLoading = false
    }

    func sendSuggestion(_ suggestion: String) async {
        inputText = suggestion
        await send()
    }

    func clearChat() {
        messages.removeAll()
        errorMessage = nil
        inputText = ""
    }
}
