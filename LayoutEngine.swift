import Foundation
import Combine
import CloudKit

// MARK: - LayoutEngine

/// Fetches screen layouts from CloudKit, caches them locally, and provides
/// section descriptors for each screen. Falls back to hardcoded default layouts
/// that match the current app behavior when CloudKit is unreachable.
class LayoutEngine: ObservableObject {

    @Published var layouts: [String: ScreenLayout] = [:]

    private let database = CKContainer.default().publicCloudDatabase
    private let cacheKey = "lexis.cachedLayouts"
    private let defaults = UserDefaults.standard

    init() {
        loadCachedLayouts()
    }

    // MARK: - Fetching

    /// Fetches all ScreenLayout records from CloudKit and caches them.
    func fetchLayouts() async {
        do {
            let fetched: [ScreenLayout] = try await Analytics.shared.measure("FetchLayouts") {
                let query = CKQuery(recordType: "ScreenLayout", predicate: NSPredicate(value: true))
                let (results, _) = try await self.database.records(matching: query)
                return results.compactMap { _, result in
                    guard let record = try? result.get() else { return nil }
                    return self.screenLayout(from: record)
                }
            }
            await MainActor.run {
                for layout in fetched {
                    self.layouts[layout.screenId] = layout
                }
                self.cacheLayouts()
            }
        } catch {
            Analytics.shared.logError(error, context: "FetchLayouts")
            // Keep using cached or default layouts on failure
        }
    }

    // MARK: - Querying

    /// Returns the section descriptors for a screen, sorted by position.
    /// Falls back to the hardcoded default layout if no remote layout exists.
    func sections(for screenId: String) -> [SectionDescriptor] {
        if let layout = layouts[screenId] {
            return layout.sections
                .filter { $0.isVisible }
                .sorted { $0.position < $1.position }
        }
        return Self.defaultLayout(for: screenId)
    }

    /// Whether a remote layout has been loaded for a given screen.
    func hasRemoteLayout(for screenId: String) -> Bool {
        layouts[screenId] != nil
    }

    // MARK: - CloudKit → Model

    private func screenLayout(from record: CKRecord) -> ScreenLayout? {
        guard let screenId = record["screenId"] as? String,
              let version = record["version"] as? Int,
              let layoutJSON = record["layoutJSON"] as? String,
              let jsonData = layoutJSON.data(using: .utf8),
              let sections = try? JSONDecoder().decode([SectionDescriptor].self, from: jsonData) else {
            return nil
        }
        return ScreenLayout(screenId: screenId, version: version, sections: sections)
    }

    // MARK: - Caching

    private func loadCachedLayouts() {
        guard let data = defaults.data(forKey: cacheKey),
              let cached = try? JSONDecoder().decode([ScreenLayout].self, from: data) else { return }
        for layout in cached {
            layouts[layout.screenId] = layout
        }
    }

    private func cacheLayouts() {
        let all = Array(layouts.values)
        if let data = try? JSONEncoder().encode(all) {
            defaults.set(data, forKey: cacheKey)
        }
    }

    // MARK: - Default Layouts

    /// Hardcoded default layouts that exactly reproduce the current app behavior.
    /// Used when no remote layout has been fetched (offline, first launch, etc.).
    static func defaultLayout(for screenId: String) -> [SectionDescriptor] {
        switch screenId {
        case "today":
            return [
                SectionDescriptor(id: "header", componentType: "header", properties: [:], isVisible: true, position: 0),
                SectionDescriptor(id: "word_hero", componentType: "word_hero", properties: [:], isVisible: true, position: 1),
                SectionDescriptor(id: "pronunciation", componentType: "pronunciation", properties: [:], isVisible: true, position: 2),
                SectionDescriptor(id: "pos_badge", componentType: "pos_badge", properties: [:], isVisible: true, position: 3),
                SectionDescriptor(id: "definition", componentType: "definition", properties: [:], isVisible: true, position: 4),
                SectionDescriptor(id: "divider_1", componentType: "divider", properties: [:], isVisible: true, position: 5),
                SectionDescriptor(id: "etymology", componentType: "etymology", properties: [:], isVisible: true, position: 6),
                SectionDescriptor(id: "example", componentType: "example", properties: [:], isVisible: true, position: 7),
                SectionDescriptor(id: "ad_today", componentType: "ad_slot", properties: ["placement": "today_footer"], isVisible: true, position: 8),
            ]
        case "archive":
            return [
                SectionDescriptor(id: "archive_header", componentType: "archive_header", properties: [:], isVisible: true, position: 0),
                SectionDescriptor(id: "archive_label", componentType: "section_label", properties: ["text": "past words"], isVisible: true, position: 1),
                SectionDescriptor(id: "archive_list", componentType: "archive_list", properties: [:], isVisible: true, position: 2),
            ]
        default:
            return []
        }
    }
}
