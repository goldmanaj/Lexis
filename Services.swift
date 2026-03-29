import Foundation
import AVFoundation
import UserNotifications

// MARK: - WordService

struct WordService {

    // Key is stored in Secrets.swift (which is git ignored)
    static let apiKey = Secrets.claudeApiKey

    static func fetchWord(excluding pastWords: [String] = []) async throws -> WordEntry {
        do {
            guard let url = URL(string: "https://api.anthropic.com/v1/messages") else {
                throw LexisError.invalidURL
            }

            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
            request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")

            var prompt = """
            You are a vocabulary curator for highly educated readers.

            Return a single JSON object with NO other text, no markdown, no code fences.
            The JSON must have exactly these keys:

            {
              "word": "a rare, genuinely obscure English word most educated adults do not know",
              "phonetic": "IPA pronunciation wrapped in forward slashes, e.g. /ˈwɜːd/",
              "partOfSpeech": "noun, verb, adjective, etc.",
              "definition": "a clear, precise definition in one or two sentences",
              "etymology": "the word's origin in one concise sentence",
              "exampleSentence": "a sophisticated, natural example sentence using the word",
              "wrongAnswers": [
                "a plausible but incorrect definition",
                "another plausible but incorrect definition",
                "a third plausible but incorrect definition"
              ]
            }

            Standards for the word you choose:
            - Must be genuinely obscure. Not known by most well-read adults.
            - Too common (do not use): ephemeral, ubiquitous, ambiguous, pragmatic, didactic, esoteric.
            - Good examples of the right level: vellichor, apricity, noctilucent, velleity, sonder, apothegm, petrichor, hiraeth, lacuna, numinous.
            - Vary across different domains: linguistics, philosophy, natural history, literature, science.
            """

            if !pastWords.isEmpty {
                let excludedStr = pastWords.joined(separator: ", ")
                prompt += "\n\nCRITICAL: Do NOT under any circumstances return any of these words: \(excludedStr)."
            }
            prompt += "\n\nRandom seed: \(UUID().uuidString)"

            let body: [String: Any] = [
                "model": "claude-3-5-sonnet-20241022",
                "max_tokens": 800,
                "messages": [
                    [
                        "role": "user",
                        "content": [
                            ["type": "text", "text": prompt]
                        ]
                    ]
                ]
            ]

            request.httpBody = try JSONSerialization.data(withJSONObject: body)

            let (data, response) = try await URLSession.shared.data(for: request)

            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
                let serverMessage = String(data: data, encoding: .utf8) ?? ""
                print("Anthropic API error \(httpResponse.statusCode): \(serverMessage)")
                throw LexisError.apiError
            }

            let apiResponse = try JSONDecoder().decode(AnthropicResponse.self, from: data)

            // Concatenate all text blocks (Anthropic may return multiple)
            let text = apiResponse.content.compactMap { $0.text }.joined(separator: "\n")
            guard !text.isEmpty else {
                throw LexisError.emptyResponse
            }

            // Clean and normalize quotes the model might emit
            let cleaned = text
                .replacingOccurrences(of: "```json", with: "")
                .replacingOccurrences(of: "```", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let normalized = cleaned
                .replacingOccurrences(of: "“", with: "\"")
                .replacingOccurrences(of: "”", with: "\"")
                .replacingOccurrences(of: "’", with: "'")

            // Try to isolate the JSON object if the model added extra prose
            let candidate: String
            if let start = normalized.firstIndex(of: "{"), let end = normalized.lastIndex(of: "}") {
                candidate = String(normalized[start...end])
            } else {
                candidate = normalized
            }

            guard let jsonData = candidate.data(using: .utf8),
                  let raw = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
                print("Failed to parse JSON from model output:\n\(cleaned)")
                throw LexisError.parseError
            }

            // Helper to coerce values to String
            func str(_ value: Any?) -> String? {
                if let s = value as? String { return s }
                if let n = value as? NSNumber { return n.stringValue }
                if let v = value { return String(describing: v) }
                return nil
            }

            // Extract with fallbacks for alternate key spellings
            let word = str(raw["word"]) ?? str(raw["term"]) ?? str(raw["Word"]) // permissive
            let phonetic = str(raw["phonetic"]) ?? str(raw["pronunciation"]) ?? "/—/"
            let partOfSpeech = str(raw["partOfSpeech"]) ?? str(raw["part_of_speech"]) ?? "noun"
            let definition = str(raw["definition"]) ?? str(raw["meaning"]) // must exist
            let etymology = str(raw["etymology"]) ?? "Origin unknown."
            let example = str(raw["exampleSentence"]) ?? str(raw["example"]) ?? str(raw["example_sentence"]) ?? "—"

            var wrong: [String] = []
            if let arr = raw["wrongAnswers"] as? [Any] {
                wrong = arr.compactMap { str($0) }
            } else if let arr = raw["wrong_answers"] as? [Any] {
                wrong = arr.compactMap { str($0) }
            } else if let arr = raw["distractors"] as? [Any] {
                wrong = arr.compactMap { str($0) }
            }

            if wrong.count < 3 {
                let fillers = [
                    "a type of small songbird",
                    "an ancient Roman coin",
                    "a geological formation"
                ]
                wrong.append(contentsOf: fillers.prefix(3 - wrong.count))
            } else if wrong.count > 3 {
                wrong = Array(wrong.prefix(3))
            }

            guard let w = word, let def = definition, !w.isEmpty, !def.isEmpty else {
                throw LexisError.parseError
            }

            return WordEntry(
                id: UUID(),
                word: w,
                phonetic: phonetic,
                partOfSpeech: partOfSpeech,
                definition: def,
                etymology: etymology,
                exampleSentence: example,
                wrongAnswers: wrong,
                date: Date()
            )
        } catch {
            #if DEBUG
            print("WordService.fetchWord failed: \(error). Returning sample word in DEBUG.")
            return WordService.sampleWord()
            #else
            throw error
            #endif
        }
    }

    static func sampleWord() -> WordEntry {
        return WordEntry(
            id: UUID(),
            word: "Vellichor",
            phonetic: "/ˈvɛlɪkɔːr/",
            partOfSpeech: "noun",
            definition: "The strange wistfulness of used bookshops, filled with the passage of time and the smell of old pages.",
            etymology: "Coined in the early 21st century; a blend of 'vellum' and 'melancholy'.",
            exampleSentence: "She wandered the aisles in a haze of vellichor, thumbing spines softened by other hands.",
            wrongAnswers: [
                "A medieval musical instrument similar to a lyre",
                "A pigment derived from volcanic ash used in Renaissance paintings",
                "The practice of binding books with untreated calfskin"
            ],
            date: Date()
        )
    }
}

// MARK: - Anthropic response shape

private struct AnthropicResponse: Codable {
    let content: [ContentBlock]
    struct ContentBlock: Codable {
        let type: String
        let text: String?
    }
}

// MARK: - Errors

enum LexisError: LocalizedError {
    case invalidURL
    case apiError
    case emptyResponse
    case parseError

    var errorDescription: String? {
        switch self {
        case .invalidURL:     return "Invalid API URL."
        case .apiError:       return "The API returned an error. Check your API key."
        case .emptyResponse:  return "The API returned an empty response."
        case .parseError:     return "Could not parse the word data."
        }
    }
}

// MARK: - SpeechService

class SpeechService {
    static let shared = SpeechService()
    private let synthesizer = AVSpeechSynthesizer()

    func speak(_ word: String) {
        synthesizer.stopSpeaking(at: .immediate)
        let utterance = AVSpeechUtterance(string: word)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-GB")
        utterance.rate = 0.38
        utterance.pitchMultiplier = 1.0
        synthesizer.speak(utterance)
    }
}

// MARK: - NotificationManager

class NotificationManager {
    static let shared = NotificationManager()

    func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }

    func scheduleWordNotification(enabled: Bool, time: Date) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ["lexis.word"])
        guard enabled else { return }

        let content = UNMutableNotificationContent()
        content.title = "Your word is ready"
        content.body = "Tap to see today's advanced word"
        content.sound = .default

        let comps = Calendar.current.dateComponents([.hour, .minute], from: time)
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
        let request = UNNotificationRequest(identifier: "lexis.word", content: content, trigger: trigger)
        center.add(request)
    }

    func scheduleQuizNotification(enabled: Bool, time: Date) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ["lexis.quiz"])
        guard enabled else { return }

        let content = UNMutableNotificationContent()
        content.title = "Quiz time"
        content.body = "Test yourself on today's word"
        content.sound = .default

        let comps = Calendar.current.dateComponents([.hour, .minute], from: time)
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
        let request = UNNotificationRequest(identifier: "lexis.quiz", content: content, trigger: trigger)
        center.add(request)
    }
}
