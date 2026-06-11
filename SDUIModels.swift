import Foundation

// MARK: - ScreenLayout

/// Describes the complete layout of a single screen, as delivered by the server.
struct ScreenLayout: Codable {
    let screenId: String           // "today", "archive", "quiz", "settings"
    let version: Int               // Schema version for forward compatibility
    let sections: [SectionDescriptor]
}

// MARK: - SectionDescriptor

/// Describes one section (component) to render on a screen.
/// The `componentType` maps to a pre-built SwiftUI view via `ComponentRegistry`.
struct SectionDescriptor: Codable, Identifiable {
    let id: String
    let componentType: String      // "word_hero", "etymology", "ad_slot", etc.
    let properties: [String: String]
    let isVisible: Bool
    let position: Int

    // MARK: - Property helpers

    func stringProp(_ key: String) -> String? {
        properties[key]
    }

    func intProp(_ key: String) -> Int? {
        guard let val = properties[key] else { return nil }
        return Int(val)
    }

    func boolProp(_ key: String) -> Bool {
        guard let val = properties[key] else { return false }
        return val == "true" || val == "1"
    }
}

// MARK: - RenderContext

/// Runtime data passed to components during rendering.
/// This bridges the gap between server-described layout and live app state.
struct RenderContext {
    let store: WordStore
    let todayEntry: WordEntry?
    let streakCount: Int

    init(store: WordStore) {
        self.store = store
        self.todayEntry = store.todayEntry
        self.streakCount = store.streakCount
    }
}
