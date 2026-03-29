import SwiftUI

struct TodayView: View {
    @EnvironmentObject var store: WordStore

    var body: some View {
        ZStack {
            Color.lexisBg.ignoresSafeArea()

            if store.isLoading {
                loadingView
            } else if let error = store.errorMessage {
                errorView(error)
            } else if let entry = store.todayEntry {
                wordView(entry)
            } else {
                loadingView
            }
        }
    }

    // MARK: - Word content

    func wordView(_ entry: WordEntry) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {

                // Header
                HStack {
                    AppTitle()
                    Spacer()
                    StreakView(count: store.streakCount)
                }
                .padding(.bottom, 24)

                SectionLabel(text: "today's word")
                    .padding(.bottom, 10)

                // The word
                Text(entry.word)
                    .font(.lexisSerif(34))
                    .foregroundColor(.lexisText)
                    .padding(.bottom, 8)

                // Pronunciation row
                HStack(spacing: 10) {
                    PlayButton { SpeechService.shared.speak(entry.word) }
                    Text(entry.phonetic)
                        .font(.system(size: 13).italic())
                        .foregroundColor(.lexisMuted)
                }
                .padding(.bottom, 14)

                PosBadge(text: entry.partOfSpeech)
                    .padding(.bottom, 18)

                // Definition
                Text(entry.definition)
                    .font(.lexisSerif(15))
                    .foregroundColor(.lexisCream)
                    .lineSpacing(6)
                    .padding(.bottom, 22)

                Divider()
                    .background(Color.lexisBorder)
                    .padding(.bottom, 18)

                // Etymology
                SectionLabel(text: "etymology")
                    .padding(.bottom, 6)
                Text(entry.etymology)
                    .font(.system(size: 13).italic())
                    .foregroundColor(.lexisMuted)
                    .lineSpacing(4)
                    .padding(.bottom, 18)

                // Example
                SectionLabel(text: "example")
                    .padding(.bottom, 8)
                HStack(alignment: .top, spacing: 0) {
                    Rectangle()
                        .fill(Color.lexisBorder)
                        .frame(width: 1.5)
                    Text(entry.exampleSentence)
                        .font(.system(size: 13))
                        .foregroundColor(Color(hex: "9a9088"))
                        .lineSpacing(4)
                        .padding(.leading, 10)
                }
                .padding(.bottom, 40)
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)
        }
    }

    // MARK: - Loading

    var loadingView: some View {
        VStack(spacing: 14) {
            ProgressView()
                .tint(.lexisGold)
            Text("Fetching today's word...")
                .font(.system(size: 13))
                .foregroundColor(.lexisSubtle)
        }
    }

    // MARK: - Error

    func errorView(_ message: String) -> some View {
        VStack(spacing: 16) {
            Text("Something went wrong")
                .font(.lexisSerif(17))
                .foregroundColor(.lexisMuted)
            Text(message)
                .font(.system(size: 12))
                .foregroundColor(.lexisSubtle)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Button(action: {
                Task { await store.fetchTodayWordIfNeeded() }
            }) {
                Text("Try again")
                    .font(.system(size: 14))
                    .foregroundColor(.lexisGold)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.lexisBorder, lineWidth: 0.5))
            }
        }
        .padding()
    }
}

// MARK: - Streak view

struct StreakView: View {
    let count: Int
    private let maxDots = 7

    var body: some View {
        HStack(spacing: 5) {
            ForEach(0..<maxDots, id: \.self) { i in
                Circle()
                    .fill(i < count ? Color.lexisGold : Color.lexisBorder)
                    .frame(width: 6, height: 6)
            }
            Text("\(count) day streak")
                .font(.system(size: 10))
                .foregroundColor(.lexisSubtle)
                .padding(.leading, 4)
        }
    }
}

// MARK: - Play button

struct PlayButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(Color.lexisDimmed)
                    .frame(width: 30, height: 30)
                    .overlay(Circle().stroke(Color.lexisBorder, lineWidth: 0.5))
                Image(systemName: "play.fill")
                    .font(.system(size: 9))
                    .foregroundColor(.lexisGold)
                    .padding(.leading, 2)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Word detail (used by ArchiveView)

struct WordDetailView: View {
    let entry: WordEntry
    @Environment(\.dismiss) var dismiss

    var body: some View {
        ZStack {
            Color.lexisBg.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        Spacer()
                        Button("Done") { dismiss() }
                            .font(.system(size: 14))
                            .foregroundColor(.lexisGold)
                    }
                    .padding(.bottom, 24)

                    Text(entry.date.formatted(.dateTime.month(.wide).day().year()))
                        .font(.system(size: 10))
                        .kerning(1)
                        .foregroundColor(.lexisSubtle)
                        .padding(.bottom, 10)

                    Text(entry.word)
                        .font(.lexisSerif(30))
                        .foregroundColor(.lexisText)
                        .padding(.bottom, 8)

                    HStack(spacing: 10) {
                        PlayButton { SpeechService.shared.speak(entry.word) }
                        Text(entry.phonetic)
                            .font(.system(size: 13).italic())
                            .foregroundColor(.lexisMuted)
                    }
                    .padding(.bottom, 14)

                    PosBadge(text: entry.partOfSpeech)
                        .padding(.bottom, 18)

                    Text(entry.definition)
                        .font(.lexisSerif(15))
                        .foregroundColor(.lexisCream)
                        .lineSpacing(6)
                        .padding(.bottom, 22)

                    Divider().background(Color.lexisBorder).padding(.bottom, 18)

                    SectionLabel(text: "etymology").padding(.bottom, 6)
                    Text(entry.etymology)
                        .font(.system(size: 13).italic())
                        .foregroundColor(.lexisMuted)
                        .lineSpacing(4)
                        .padding(.bottom, 18)

                    SectionLabel(text: "example").padding(.bottom, 8)
                    HStack(alignment: .top, spacing: 0) {
                        Rectangle().fill(Color.lexisBorder).frame(width: 1.5)
                        Text(entry.exampleSentence)
                            .font(.system(size: 13))
                            .foregroundColor(Color(hex: "9a9088"))
                            .lineSpacing(4)
                            .padding(.leading, 10)
                    }
                    .padding(.bottom, 40)
                }
                .padding(.horizontal, 24)
                .padding(.top, 24)
            }
        }
    }
}
