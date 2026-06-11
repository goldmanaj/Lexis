import SwiftUI

struct ArchiveView: View {
    @EnvironmentObject var store: WordStore
    @EnvironmentObject var engine: LayoutEngine
    @State private var selectedEntry: WordEntry?

    var body: some View {
        ZStack {
            Color.lexisBg.ignoresSafeArea()

            if store.archive.isEmpty {
                // If empty, we could still use SDUI, but for simplicity
                // we'll use a direct component or server-driven empty state.
                ArchiveEmptyStateSection()
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        let sections = engine.sections(for: "archive")
                        ForEach(sections) { section in
                            ComponentRegistry.resolve(
                                section,
                                context: RenderContext(store: store)
                            )
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
        .onAppear {
            Analytics.shared.logEvent("ArchiveViewed")
        }
        .onReceive(NotificationCenter.default.publisher(for: ArchiveListSection.selectionNotification)) { notification in
            if let entry = notification.object as? WordEntry {
                selectedEntry = entry
            }
        }
    }
}
