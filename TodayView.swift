import SwiftUI

struct TodayView: View {
    @EnvironmentObject var store: WordStore
    @EnvironmentObject var engine: LayoutEngine

    var body: some View {
        ZStack {
            Color.lexisBg.ignoresSafeArea()

            if store.isLoading {
                loadingView
            } else if let error = store.errorMessage {
                errorView(error)
            } else if store.todayEntry != nil {
                wordView
            } else {
                loadingView
            }
        }
        .safeAreaInset(edge: .bottom) {
            TodayBottomAdSlot()
                .padding(.horizontal, 24)
                .padding(.top, 8)
                .background(Color.lexisBg)
        }
        .onAppear {
            logTodayLayoutAdPlacement()
        }
    }

    // MARK: - Word content (server-driven)

    var wordView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                let sections = contentSections
                ForEach(sections) { section in
                    ComponentRegistry.resolve(
                        section,
                        context: RenderContext(store: store)
                    )
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)
        }
        .onAppear {
            Analytics.shared.logEvent("WordViewed")
        }
    }

    private var contentSections: [SectionDescriptor] {
        engine.sections(for: "today").filter { descriptor in
            !(descriptor.componentType == "ad_slot" && descriptor.stringProp("placement") == "today_footer")
        }
    }

    private func logTodayLayoutAdPlacement() {
        let sections = engine.sections(for: "today")
        let includesTodayFooterAd = sections.contains {
            $0.componentType == "ad_slot" && $0.stringProp("placement") == "today_footer"
        }

        if includesTodayFooterAd {
            print("[TodayView] Layout includes today_footer ad slot; rendering pinned bottom slot only")
        } else {
            print("[TodayView] Layout omitted today_footer ad slot; forcing pinned bottom slot")
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

private struct TodayBottomAdSlot: View {
    var body: some View {
        AdSlotView(placement: "today_footer", compact: true)
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
                .font(.system(size: 12, weight: .medium))
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
                    .font(.system(size: 11, weight: .medium))
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
                        .font(.system(size: 12, weight: .medium))
                        .kerning(0.8)
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
