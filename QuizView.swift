import SwiftUI
import Combine

struct QuizView: View {
    @EnvironmentObject var store: WordStore

    // Shuffled answers are computed once and stored in state so they
    // don't re-shuffle every time the view re-renders.
    @State private var shuffledAnswers: [String] = []
    @State private var selectedAnswer: String? = nil

    // A timer that checks every 30 seconds whether the quiz has unlocked.
    let timer = Timer.publish(every: 30, on: .main, in: .common).autoconnect()

    // MARK: - Quiz lock logic

    var quizUnlockTime: Date {
        let interval = UserDefaults.standard.double(forKey: "lexis.quizTime")
        if interval > 0 {
            return Date(timeIntervalSince1970: interval)
        }
        // Default: 7:00 PM
        return Calendar.current.date(bySettingHour: 19, minute: 0, second: 0, of: Date())!
    }

    var isUnlocked: Bool {
        let cal = Calendar.current
        let now = cal.dateComponents([.hour, .minute], from: Date())
        let unlock = cal.dateComponents([.hour, .minute], from: quizUnlockTime)
        let nowMins = (now.hour ?? 0) * 60 + (now.minute ?? 0)
        let unlockMins = (unlock.hour ?? 0) * 60 + (unlock.minute ?? 0)
        return nowMins >= unlockMins
    }

    var unlockTimeFormatted: String {
        quizUnlockTime.formatted(.dateTime.hour().minute())
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            Color.lexisBg.ignoresSafeArea()

            if !isUnlocked {
                lockedView
            } else if store.todayEntry == nil {
                noWordView
            } else if store.hasAnsweredToday {
                resultView
            } else {
                quizView
            }
        }
        .onReceive(timer) { _ in
            // Force a re-render so the lock check refreshes
            // SwiftUI will re-evaluate isUnlocked automatically
        }
        .onAppear { prepareAnswers() }
        .onChange(of: store.todayEntry?.id) { _ in prepareAnswers() }
    }

    // MARK: - Locked

    var lockedView: some View {
        VStack(spacing: 0) {
            AppTitle()
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 24)
                .padding(.top, 24)

            Spacer()

            VStack(spacing: 16) {
                LockIcon()

                Text("Quiz not yet available")
                    .font(.lexisSerif(18))
                    .foregroundColor(Color(hex: "3a3228"))
                    .multilineTextAlignment(.center)

                Text("Come back after your scheduled quiz time.")
                    .font(.system(size: 13))
                    .foregroundColor(Color(hex: "2e2c28"))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)

                VStack(spacing: 4) {
                    Text("unlocks at")
                        .font(.system(size: 10))
                        .kerning(1)
                        .foregroundColor(.lexisSubtle)
                    Text(unlockTimeFormatted)
                        .font(.lexisSerif(20))
                        .foregroundColor(.lexisMuted)
                }
                .padding(.top, 8)
            }

            Spacer()
        }
    }

    // MARK: - No word yet

    var noWordView: some View {
        VStack(spacing: 10) {
            Text("Today's word isn't ready yet.")
                .font(.lexisSerif(17))
                .foregroundColor(.lexisMuted)
            Text("Check the Today tab first.")
                .font(.system(size: 13))
                .foregroundColor(.lexisSubtle)
        }
    }

    // MARK: - Active quiz

    var quizView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                AppTitle()
                    .padding(.bottom, 24)

                if let entry = store.todayEntry {
                    Text("what does this word mean?")
                        .font(.system(size: 10))
                        .kerning(1)
                        .foregroundColor(.lexisSubtle)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.bottom, 10)

                    Text(entry.word)
                        .font(.lexisSerif(30))
                        .foregroundColor(.lexisText)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.bottom, 6)

                    Text(entry.phonetic)
                        .font(.system(size: 12).italic())
                        .foregroundColor(.lexisMuted)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.bottom, 28)

                    VStack(spacing: 8) {
                        ForEach(shuffledAnswers, id: \.self) { answer in
                            AnswerButton(
                                text: answer,
                                state: buttonState(answer, correct: entry.definition),
                                onTap: {
                                    selectedAnswer = answer
                                    store.recordQuizAnswer(answer)
                                }
                            )
                        }
                    }
                }

                Spacer(minLength: 40)
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)
        }
    }

    // MARK: - Completed quiz result

    var resultView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                AppTitle()
                    .padding(.bottom, 24)

                if let entry = store.todayEntry,
                   let selected = store.todaySelectedAnswer {

                    Text("today's quiz")
                        .font(.system(size: 10))
                        .kerning(1)
                        .foregroundColor(.lexisSubtle)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.bottom, 10)

                    Text(entry.word)
                        .font(.lexisSerif(30))
                        .foregroundColor(.lexisText)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.bottom, 6)

                    Text(entry.phonetic)
                        .font(.system(size: 12).italic())
                        .foregroundColor(.lexisMuted)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.bottom, 28)

                    VStack(spacing: 8) {
                        ForEach(shuffledAnswers, id: \.self) { answer in
                            AnswerButton(
                                text: answer,
                                state: buttonState(answer, correct: entry.definition),
                                onTap: {}
                            )
                        }
                    }

                    Divider().background(Color.lexisBorder).padding(.vertical, 20)

                    let correct = selected == entry.definition
                    Text(correct ? "Correct — well done" : "Not quite — see the correct answer above")
                        .font(.system(size: 13))
                        .foregroundColor(correct ? .lexisGreen : .lexisMuted)
                        .frame(maxWidth: .infinity, alignment: .center)

                    Text("Come back tomorrow for a new word.")
                        .font(.system(size: 11))
                        .foregroundColor(.lexisSubtle)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 6)
                }

                Spacer(minLength: 40)
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)
        }
    }

    // MARK: - Helpers

    func prepareAnswers() {
        guard let entry = store.todayEntry, shuffledAnswers.isEmpty else { return }
        shuffledAnswers = entry.allAnswers
    }

    func buttonState(_ answer: String, correct: String) -> AnswerButtonState {
        let answered = store.hasAnsweredToday
        let selected = store.todaySelectedAnswer

        if !answered && selectedAnswer == nil { return .idle }
        if answer == correct { return .correct }
        if answer == selected && answer != correct { return .wrong }
        return .idle
    }
}

// MARK: - Answer button

enum AnswerButtonState { case idle, correct, wrong }

struct AnswerButton: View {
    let text: String
    let state: AnswerButtonState
    let onTap: () -> Void

    var bg: Color {
        switch state {
        case .idle:    return Color.lexisSurface
        case .correct: return Color(hex: "0e1f18")
        case .wrong:   return Color(hex: "1f0e0e")
        }
    }

    var border: Color {
        switch state {
        case .idle:    return Color.lexisBorder
        case .correct: return Color(hex: "1d4a32")
        case .wrong:   return Color(hex: "4a1d1d")
        }
    }

    var textColor: Color {
        switch state {
        case .idle:    return .lexisCream
        case .correct: return .lexisGreen
        case .wrong:   return Color(hex: "ba6b6b")
        }
    }

    var body: some View {
        Button(action: onTap) {
            Text(text)
                .font(.system(size: 13))
                .foregroundColor(textColor)
                .lineSpacing(3)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(bg)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(border, lineWidth: 0.5))
        }
        .buttonStyle(.plain)
        .disabled(state != .idle)
    }
}

// MARK: - Lock icon

struct LockIcon: View {
    var body: some View {
        VStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color(hex: "2a2825"), lineWidth: 2)
                .frame(width: 20, height: 14)
                .offset(y: 4)
            RoundedRectangle(cornerRadius: 5)
                .fill(Color(hex: "1a1815"))
                .overlay(RoundedRectangle(cornerRadius: 5).stroke(Color(hex: "2a2825"), lineWidth: 0.5))
                .frame(width: 32, height: 24)
        }
        .frame(width: 40, height: 44)
    }
}

