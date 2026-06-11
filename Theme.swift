import SwiftUI

extension Color {
    static let lexisBg        = Color(hex: "0f0e0d")
    static let lexisText      = Color(hex: "f0ece4")
    static let lexisGold      = Color(hex: "c4a96b")
    static let lexisMuted     = Color(hex: "7a6f5e")
    static let lexisSubtle    = Color(hex: "5a5650")
    static let lexisSurface   = Color(hex: "1a1815")
    static let lexisBorder    = Color(hex: "2a2825")
    static let lexisDimmed    = Color(hex: "1e1c18")
    static let lexisGreen     = Color(hex: "6dba8f")
    static let lexisCream     = Color(hex: "c8bfb0")
    static let lexisArchive   = Color(hex: "e0d8cc")

    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255
        let g = Double((int >> 8) & 0xFF) / 255
        let b = Double(int & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}

extension Font {
    static func lexisSerif(_ size: CGFloat) -> Font {
        .custom("Georgia", size: size)
    }
}

struct SectionLabel: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .medium))
            .kerning(1.6)
            .foregroundColor(.lexisSubtle)
    }
}

struct PosBadge: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.system(size: 10))
            .foregroundColor(.lexisGold)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Color.lexisDimmed)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(Color.lexisBorder, lineWidth: 0.5))
    }
}

struct AppTitle: View {
    var body: some View {
        Text("LEXIS")
            .font(.system(size: 11, weight: .regular))
            .kerning(4)
            .foregroundColor(.lexisSubtle)
    }
}
