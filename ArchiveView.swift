import SwiftUI

struct ArchiveView: View {
    @EnvironmentObject var store: WordStore
    @State private var selectedEntry: WordEntry?

    var body: some View {
        ZStack {
            Color.lexisBg.ignoresSafeArea()

            if store.archive.isEmpty {
                emptyState
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        HStack {
                            AppTitle()
                            Spacer()
                            Text("\(store.archive.count) words")
                                .font(.system(size: 11))
                                .foregroundColor(.lexisSubtle)
                        }
                        .padding(.bottom, 20)

                        SectionLabel(text: "past words")
                            .padding(.bottom, 14)

                        ForEach(store.archive) { entry in
                            Button(action: { selectedEntry = entry }) {
                                HStack(alignment: .center) {
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(entry.word)
                                            .font(.lexisSerif(17))
                                            .foregroundColor(.lexisArchive)
                                        Text(entry.partOfSpeech)
                                            .font(.system(size: 11).italic())
                                            .foregroundColor(.lexisMuted)
                                    }
                                    Spacer()
                                    Text(archiveDate(entry.date))
                                        .font(.system(size: 11))
                                        .foregroundColor(.lexisSubtle)
                                }
                                .padding(.vertical, 12)
                            }
                            .buttonStyle(.plain)

                            Divider()
                                .background(Color.lexisDimmed)
                        }

                        Spacer(minLength: 40)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 24)
                }
            }
        }
        .sheet(item: $selectedEntry) { entry in
            WordDetailView(entry: entry)
        }
    }

    // MARK: - Empty state

    var emptyState: some View {
        VStack(spacing: 10) {
            Text("No words yet")
                .font(.lexisSerif(17))
                .foregroundColor(.lexisMuted)
            Text("Your archive builds up one word at a time.")
                .font(.system(size: 13))
                .foregroundColor(.lexisSubtle)
        }
    }

    // MARK: - Date formatting

    func archiveDate(_ date: Date) -> String {
        if Calendar.current.isDateInToday(date) { return "Today" }
        if Calendar.current.isDateInYesterday(date) { return "Yesterday" }
        return date.formatted(.dateTime.month(.abbreviated).day())
    }
}
