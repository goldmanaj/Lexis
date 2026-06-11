import Foundation
import AVFoundation
import UserNotifications

#if canImport(FoundationModels)
import FoundationModels
#endif

// MARK: - WordService

struct WordService {

    static func fetchWord(excluding pastWords: [String] = []) async throws -> WordEntry {
        let excludedWords = Set(pastWords.map { $0.lowercased() })

        #if canImport(FoundationModels)
        if #available(iOS 18.2, *) {
            for attempt in 1...3 {
                do {
                    let session = LanguageModelSession()
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

                    let response = try await session.respond(to: prompt)
                    let text = response.content

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

                    if excludedWords.contains(w.lowercased()) {
                        print("LanguageModelSession returned duplicate excluded word '\(w)' on attempt \(attempt). Retrying.")
                        continue
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
                    print("LanguageModelSession generation failed on attempt \(attempt): \(error).")
                }
            }

            print("LanguageModelSession generation exhausted retries. Falling back to WordBank.")
            return WordBank.getRandomWord(excluding: excludedWords)
        }
        #endif
        
        print("Apple Intelligence unsupported. Falling back to WordBank.")
        return WordBank.getRandomWord(excluding: excludedWords)
    }
}

// MARK: - Errors

enum LexisError: LocalizedError {
    case parseError

    var errorDescription: String? {
        switch self {
        case .parseError: return "Could not parse the generated word data."
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
