import Foundation
import Combine

// MARK: - WordEntry

struct WordEntry: Codable, Identifiable {
    let id: UUID
    let word: String
    let phonetic: String
    let partOfSpeech: String
    let definition: String
    let etymology: String
    let exampleSentence: String
    let wrongAnswers: [String]
    let date: Date

    var allAnswers: [String] {
        var answers = wrongAnswers
        answers.append(definition)
        return answers.shuffled()
    }
}

// MARK: - WordStore

class WordStore: ObservableObject {
    @Published var todayEntry: WordEntry?
    @Published var archive: [WordEntry] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let defaults = UserDefaults.standard
    private let todayKey = "lexis.todayEntry"
    private let archiveKey = "lexis.archive"
    private let quizAnswerDateKey = "lexis.quizAnswerDate"
    private let quizAnswerSelectedKey = "lexis.quizAnswerSelected"

    init() {
        loadArchive()
        loadTodayEntryFromCache()
    }

    // MARK: - Fetching

    func fetchTodayWordIfNeeded() async {
        if let entry = todayEntry, Calendar.current.isDateInToday(entry.date) {
            return
        }
        await MainActor.run { isLoading = true; errorMessage = nil }
        do {
            let pastWords = archive.prefix(50).map { $0.word }
            let entry = try await WordService.fetchWord(excluding: pastWords)
            await MainActor.run {
                self.todayEntry = entry
                self.saveTodayEntry(entry)
                self.addToArchive(entry)
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Could not fetch today's word. Check your API key and internet connection."
                self.isLoading = false
            }
        }
    }

    // MARK: - Quiz state

    var hasAnsweredToday: Bool {
        guard let lastDate = defaults.object(forKey: quizAnswerDateKey) as? Date else { return false }
        return Calendar.current.isDateInToday(lastDate)
    }

    var todaySelectedAnswer: String? {
        guard hasAnsweredToday else { return nil }
        return defaults.string(forKey: quizAnswerSelectedKey)
    }

    func recordQuizAnswer(_ answer: String) {
        defaults.set(Date(), forKey: quizAnswerDateKey)
        defaults.set(answer, forKey: quizAnswerSelectedKey)
        objectWillChange.send()
    }

    // MARK: - Streak

    var streakCount: Int {
        var streak = 0
        var checkDate = Calendar.current.startOfDay(for: Date())
        for entry in archive.sorted(by: { $0.date > $1.date }) {
            let entryDay = Calendar.current.startOfDay(for: entry.date)
            if entryDay == checkDate {
                streak += 1
                checkDate = Calendar.current.date(byAdding: .day, value: -1, to: checkDate)!
            } else {
                break
            }
        }
        return streak
    }

    // MARK: - Persistence

    private func loadTodayEntryFromCache() {
        guard let data = defaults.data(forKey: todayKey),
              let entry = try? JSONDecoder().decode(WordEntry.self, from: data),
              Calendar.current.isDateInToday(entry.date) else { return }
        todayEntry = entry
    }

    private func saveTodayEntry(_ entry: WordEntry) {
        if let data = try? JSONEncoder().encode(entry) {
            defaults.set(data, forKey: todayKey)
        }
    }

    private func loadArchive() {
        guard let data = defaults.data(forKey: archiveKey),
              let entries = try? JSONDecoder().decode([WordEntry].self, from: data) else { return }
        archive = entries
    }

    private func addToArchive(_ entry: WordEntry) {
        let alreadyExists = archive.contains {
            Calendar.current.isDate($0.date, inSameDayAs: entry.date)
        }
        guard !alreadyExists else { return }
        archive.insert(entry, at: 0)
        if let data = try? JSONEncoder().encode(archive) {
            defaults.set(data, forKey: archiveKey)
        }
    }
}
