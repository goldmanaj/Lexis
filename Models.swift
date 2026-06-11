import Foundation
import Combine

enum LexisDemoMode {
    static var isEnabled: Bool {
        ProcessInfo.processInfo.arguments.contains("-lexisInvestorDemo")
    }
}

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
    private let seenWordsKey = "lexis.seenWords"
    private let quizAnswerDateKey = "lexis.quizAnswerDate"
    private let quizAnswerSelectedKey = "lexis.quizAnswerSelected"

    /// Every word ever shown, persisted to prevent repeats.
    private(set) var seenWords: Set<String> = []

    init() {
        loadArchive()
        loadSeenWords()
        loadTodayEntryFromCache()
    }

    // MARK: - Fetching

    func fetchTodayWordIfNeeded() async {
        if let entry = todayEntry, Calendar.current.isDateInToday(entry.date) {
            return
        }
        await MainActor.run { isLoading = true; errorMessage = nil }
        do {
            let entry = try await Analytics.shared.measure("FetchWord") {
                try await WordService.fetchWord(excluding: Array(self.seenWords))
            }
            await MainActor.run {
                guard !self.hasSeenWord(entry.word) else {
                    self.errorMessage = "Could not fetch today's word."
                    self.isLoading = false
                    Analytics.shared.logError(
                        NSError(
                            domain: "Lexis.WordStore",
                            code: 1,
                            userInfo: [NSLocalizedDescriptionKey: "Received duplicate word: \(entry.word)"]
                        ),
                        context: "FetchTodayWord_Duplicate"
                    )
                    print("[WordStore] Rejected duplicate word for user: \(entry.word)")
                    return
                }
                self.todayEntry = entry
                self.saveTodayEntry(entry)
                self.addToArchive(entry)
                self.addSeenWord(entry.word)
                self.isLoading = false
            }
        } catch {
            Analytics.shared.logError(error, context: "FetchTodayWord")
            await MainActor.run {
                self.errorMessage = "Could not fetch today's word."
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

    // MARK: - Seen words (deduplication)

    private func loadSeenWords() {
        if let saved = defaults.stringArray(forKey: seenWordsKey) {
            seenWords = Set(saved)
        }
        // Backfill from existing archive so words already shown are never repeated
        for entry in archive {
            seenWords.insert(entry.word.lowercased())
        }
    }

    func addSeenWord(_ word: String) {
        seenWords.insert(word.lowercased())
        defaults.set(Array(seenWords), forKey: seenWordsKey)
    }

    func hasSeenWord(_ word: String) -> Bool {
        seenWords.contains(word.lowercased())
    }

    // MARK: - Investor demo

    @MainActor
    func seedInvestorDemoData() {
        let calendar = Calendar.current
        let today = Date()

        func entry(_ source: WordEntry, daysAgo: Int) -> WordEntry {
            WordEntry(
                id: source.id,
                word: source.word,
                phonetic: source.phonetic,
                partOfSpeech: source.partOfSpeech,
                definition: source.definition,
                etymology: source.etymology,
                exampleSentence: source.exampleSentence,
                wrongAnswers: source.wrongAnswers,
                date: calendar.date(byAdding: .day, value: -daysAgo, to: today) ?? today
            )
        }

        let demoEntries = Array(WordBank.words.prefix(5).enumerated()).map { index, source in
            entry(source, daysAgo: index)
        }

        guard let current = demoEntries.first else { return }

        todayEntry = current
        archive = demoEntries
        seenWords = Set(demoEntries.map { $0.word.lowercased() })
        isLoading = false
        errorMessage = nil

        saveTodayEntry(current)
        if let archiveData = try? JSONEncoder().encode(demoEntries) {
            defaults.set(archiveData, forKey: archiveKey)
        }
        defaults.set(Array(seenWords), forKey: seenWordsKey)
        defaults.removeObject(forKey: quizAnswerDateKey)
        defaults.removeObject(forKey: quizAnswerSelectedKey)
        defaults.set(calendar.startOfDay(for: today).timeIntervalSince1970, forKey: "lexis.quizTime")
        defaults.set(true, forKey: "lexis.wordNotifEnabled")
        defaults.set(true, forKey: "lexis.quizNotifEnabled")
    }
}

// MARK: - WordBank

struct WordBank {
    static let words: [WordEntry] = [
        WordEntry(
            id: UUID(),
            word: "Apricity",
            phonetic: "/əˈprɪsɪti/",
            partOfSpeech: "noun",
            definition: "The warmth of the sun in winter.",
            etymology: "From Latin apricitas, meaning 'sunshine'.",
            exampleSentence: "Despite the snow, the brief apricity offered a comforting respite.",
            wrongAnswers: [
                "A rare type of frost that forms on window panes",
                "The smell of impending rain in an arid region",
                "A sudden feeling of nostalgia for an unknown place"
            ],
            date: Date()
        ),
        WordEntry(
            id: UUID(),
            word: "Velleity",
            phonetic: "/vəˈliːɪti/",
            partOfSpeech: "noun",
            definition: "A wish or inclination not strong enough to lead to action.",
            etymology: "From Latin velle, meaning 'to wish'.",
            exampleSentence: "His ambition had faded into a mere velleity, leaving him motionless on the couch.",
            wrongAnswers: [
                "A gentle, undulating movement characteristic of waves",
                "A state of complete emotional detachment",
                "An obscure legal term for an unfulfilled promise"
            ],
            date: Date()
        ),
        WordEntry(
            id: UUID(),
            word: "Numinous",
            phonetic: "/ˈnjuːmɪnəs/",
            partOfSpeech: "adjective",
            definition: "Having a strong religious or spiritual quality; indicating or suggesting the presence of a divinity.",
            etymology: "From Latin numen, meaning 'divine will'.",
            exampleSentence: "Standing beneath the ancient, towering redwoods, she felt a numinous awe.",
            wrongAnswers: [
                "Characterized by complex and intricate patterns",
                "Emitting a faint, steady light in the dark",
                "Pertaining to the study of ancient coins"
            ],
            date: Date()
        ),
        WordEntry(
            id: UUID(),
            word: "Apothegm",
            phonetic: "/ˈæpəθɛm/",
            partOfSpeech: "noun",
            definition: "A concise, universally accepted saying or maxim.",
            etymology: "From Greek apophthegma, meaning 'to speak out'.",
            exampleSentence: "He often relied on the old apothegm, 'actions speak louder than words'.",
            wrongAnswers: [
                "A theoretical cure-all for spiritual ailments",
                "The highest point in the development of something",
                "A geometric term for a line segment from the center to a side"
            ],
            date: Date()
        ),
        WordEntry(
            id: UUID(),
            word: "Lacuna",
            phonetic: "/ləˈkjuːnə/",
            partOfSpeech: "noun",
            definition: "An unfilled space or interval; a gap.",
            etymology: "From Latin lacuna, meaning 'pit, hole, pool'.",
            exampleSentence: "The historian was frustrated by a significant lacuna in the archival records.",
            wrongAnswers: [
                "A shallow body of water separated from a larger body",
                "A sudden loss of short-term memory",
                "The dark side of the moon"
            ],
            date: Date()
        ),
        WordEntry(
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
    ]
    
    /// Returns a random word that hasn't been seen before.
    /// If all words have been seen, resets and allows repeats.
    static func getRandomWord(excluding seen: Set<String> = []) -> WordEntry {
        let available = words.filter { !seen.contains($0.word.lowercased()) }
        if let pick = available.randomElement() {
            return pick
        }
        // All words exhausted — allow repeats
        print("WordBank: all \(words.count) words exhausted, resetting pool.")
        return words.randomElement() ?? words[0]
    }
}
