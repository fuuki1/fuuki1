import SwiftUI

enum Palette {
    static let bg = Color(.systemBackground)
    static let accent = Color(red: 124/255, green: 77/255, blue: 1.0) // #7C4DFF
    static let card = Color(.secondarySystemBackground)
    static let button = accent
    static let disabledFill = Color(uiColor: .systemGray5)
    static let error = Color(red: 1.0, green: 0.28, blue: 0.28)

    static let brand = LinearGradient(
        gradient: Gradient(stops: [
            .init(color: Color(red: 107/255, green: 94/255,  blue: 255/255), location: 0.0),
            .init(color: Color(red: 124/255, green: 77/255,  blue: 255/255), location: 0.62),
            .init(color: Color(red: 140/255, green: 84/255,  blue: 255/255), location: 0.94)
        ]),
        startPoint: .topLeading, endPoint: .bottomTrailing
    )
}
