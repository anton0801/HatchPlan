import SwiftUI

struct Theme {
    static let background = Color(hex: "1E1E2C")
    static let card = Color(hex: "2D2D44")
    static let accentYellow = Color(hex: "FFD93D")
    static let accentTeal = Color(hex: "46C2B1")
    static let alertCoral = Color(hex: "FF6B6B")
    static let successLime = Color(hex: "6CFF72")
    static let textPrimary = Color.white
    static let textSecondary = Color.gray.opacity(0.7)

    static func inter(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        Font.custom("Inter_Regular-Regular", size: size).weight(weight)
    }

    static func nunito(_ size: CGFloat, weight: Font.Weight = .bold) -> Font {
        Font.custom("Nunito", size: size).weight(weight)
    }
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "#", with: "")
        var rgb: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&rgb)
        self.init(
            red: Double((rgb >> 16) & 0xFF) / 255.0,
            green: Double((rgb >> 8) & 0xFF) / 255.0,
            blue: Double(rgb & 0xFF) / 255.0
        )
    }
}
