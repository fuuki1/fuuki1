import SwiftUI

// MARK: - Color Extensions

extension Color {
    /// Creates a Color from a hexadecimal string.
    /// Supports 3, 6, or 8 character hex strings (with or without #)
    /// - Parameter hex: Hexadecimal color string (e.g., "#FF0000", "00FF00", "0000FF80")
    init(hex: String) {
        let cleaned = hex
            .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        var int: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch cleaned.count {
        case 3: (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default: (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(.sRGB,
                  red: Double(r) / 255.0,
                  green: Double(g) / 255.0,
                  blue: Double(b) / 255.0,
                  opacity: Double(a) / 255.0)
    }

    // MARK: - Brand Colors

    /// Brand purple color (#7C4DFF)
    static let customPurple = Color(red: 0x7C / 255.0, green: 0x4D / 255.0, blue: 0xFF / 255.0)

    /// Sync green color
    static let syncGreen = Color(red: 99.0/255.0, green: 196.0/255.0, blue: 101.0/255.0)

    // MARK: - Gradient Definitions

    /// Primary brand gradient (purple gradient)
    static let brandGradient = LinearGradient(
        gradient: Gradient(stops: [
            .init(color: Color(red: 107/255, green: 94/255, blue: 255/255), location: 0.0),
            .init(color: Color(red: 124/255, green: 77/255, blue: 255/255), location: 0.62),
            .init(color: Color(red: 140/255, green: 84/255, blue: 255/255), location: 0.94)
        ]),
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}
