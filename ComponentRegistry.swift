import SwiftUI

// MARK: - ComponentRegistry

/// Maps server-described component types to pre-built SwiftUI views.
/// Unknown component types are silently skipped via EmptyView, ensuring
/// older app versions gracefully handle new server-side components.
struct ComponentRegistry {

    @ViewBuilder
    static func resolve(
        _ descriptor: SectionDescriptor,
        context: RenderContext
    ) -> some View {
        switch descriptor.componentType {

        // --- Layout primitives ---

        case "app_title":
            AppTitle()

        case "section_label":
            SectionLabel(text: descriptor.stringProp("text") ?? "")
                .padding(.bottom, CGFloat(descriptor.intProp("bottomPadding") ?? 10))

        case "divider":
            Divider()
                .background(Color.lexisBorder)
                .padding(.bottom, CGFloat(descriptor.intProp("bottomPadding") ?? 18))

        // --- Today screen components ---

        case "header":
            HeaderSection(streakCount: context.streakCount)

        case "word_hero":
            if let entry = context.todayEntry {
                WordHeroSection(entry: entry)
            }

        case "pronunciation":
            if let entry = context.todayEntry {
                PronunciationSection(entry: entry)
            }

        case "pos_badge":
            if let entry = context.todayEntry {
                PosBadge(text: entry.partOfSpeech)
                    .padding(.bottom, 18)
            }

        case "definition":
            if let entry = context.todayEntry {
                DefinitionSection(entry: entry)
            }

        case "etymology":
            if let entry = context.todayEntry {
                EtymologySection(entry: entry)
            }

        case "example":
            if let entry = context.todayEntry {
                ExampleSection(entry: entry)
            }

        case "streak":
            StreakView(count: context.streakCount)

        // --- Ad components ---

        case "ad_slot":
            AdSlotView(
                placement: descriptor.stringProp("placement") ?? "",
                compact: descriptor.boolProp("compact")
            )
            .padding(.bottom, CGFloat(descriptor.intProp("bottomPadding") ?? 40))

        // --- Archive screen components ---

        case "archive_header":
            ArchiveHeaderSection(count: context.store.archive.count)

        case "archive_list":
            ArchiveListSection(entries: context.store.archive)

        case "archive_empty_state":
            ArchiveEmptyStateSection()

        // --- Fallback ---

        default:
            // Unknown component types are skipped. This lets the server
            // reference future components without crashing older app versions.
            EmptyView()
        }
    }
}

// MARK: - Extracted Section Components

/// The header row with app title and streak dots.
struct HeaderSection: View {
    let streakCount: Int

    var body: some View {
        HStack {
            AppTitle()
            Spacer()
            StreakView(count: streakCount)
        }
        .padding(.bottom, 24)
    }
}

/// The hero word display.
struct WordHeroSection: View {
    let entry: WordEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionLabel(text: "today's word")
                .padding(.bottom, 10)

            Text(entry.word)
                .font(.lexisSerif(34))
                .foregroundColor(.lexisText)
                .padding(.bottom, 8)
        }
    }
}

/// Pronunciation button and phonetic text.
struct PronunciationSection: View {
    let entry: WordEntry

    var body: some View {
        HStack(spacing: 10) {
            PlayButton {
                Analytics.shared.logEvent("PronunciationTapped")
                SpeechService.shared.speak(entry.word)
            }
            Text(entry.phonetic)
                .font(.system(size: 13).italic())
                .foregroundColor(.lexisMuted)
        }
        .padding(.bottom, 14)
    }
}

/// The definition text block.
struct DefinitionSection: View {
    let entry: WordEntry

    var body: some View {
        Text(entry.definition)
            .font(.lexisSerif(15))
            .foregroundColor(.lexisCream)
            .lineSpacing(6)
            .padding(.bottom, 22)
    }
}

/// Etymology label and text.
struct EtymologySection: View {
    let entry: WordEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionLabel(text: "etymology")
                .padding(.bottom, 6)
            Text(entry.etymology)
                .font(.system(size: 13).italic())
                .foregroundColor(.lexisMuted)
                .lineSpacing(4)
                .padding(.bottom, 18)
        }
    }
}

/// Example sentence with a vertical bar accent.
struct ExampleSection: View {
    let entry: WordEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
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
    }
}

// MARK: - Archive Section Components

/// Header for the archive screen with total word count.
struct ArchiveHeaderSection: View {
    let count: Int

    var body: some View {
        HStack {
            AppTitle()
            Spacer()
            Text("\(count) words")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.lexisSubtle)
        }
        .padding(.bottom, 20)
    }
}

/// The list of past words in the archive.
/// Note: This component doesn't handle the sheet presentation directly
/// but triggers an event that the parent view handles.
struct ArchiveListSection: View {
    let entries: [WordEntry]

    // We use a Notification to communicate the selection back to ArchiveView
    // since we want to keep components decoupled from specific state management.
    static let selectionNotification = Notification.Name("LexisArchiveSelection")

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                Button(action: {
                    Analytics.shared.logEvent("ArchiveWordTapped")
                    NotificationCenter.default.post(name: Self.selectionNotification, object: entry)
                }) {
                    HStack(alignment: .center) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(entry.word)
                                .font(.lexisSerif(17))
                                .foregroundColor(.lexisArchive)
                            Text(entry.partOfSpeech)
                                .font(.system(size: 13).italic())
                                .foregroundColor(.lexisMuted)
                        }
                        Spacer()
                        Text(archiveDate(entry.date))
                            .font(.system(size: 13))
                            .foregroundColor(.lexisSubtle)
                    }
                    .padding(.vertical, 12)
                }
                .buttonStyle(.plain)

                Divider()
                    .background(Color.lexisDimmed)

                // Interstitial ad every 5 entries
                if (index + 1) % 5 == 0 {
                    AdSlotView(placement: "archive_interstitial", compact: true)
                        .padding(.vertical, 8)
                    Divider()
                        .background(Color.lexisDimmed)
                }
            }
        }
    }

    private func archiveDate(_ date: Date) -> String {
        if Calendar.current.isDateInToday(date) { return "Today" }
        if Calendar.current.isDateInYesterday(date) { return "Yesterday" }
        return date.formatted(.dateTime.month(.abbreviated).day())
    }
}

/// Empty state for when the archive is empty.
struct ArchiveEmptyStateSection: View {
    var body: some View {
        VStack(spacing: 10) {
            Text("No words yet")
                .font(.lexisSerif(17))
                .foregroundColor(.lexisMuted)
            Text("Your archive builds up one word at a time.")
                .font(.system(size: 13))
                .foregroundColor(.lexisSubtle)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 100)
    }
}
