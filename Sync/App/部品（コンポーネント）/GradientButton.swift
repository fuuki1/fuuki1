import SwiftUI

// MARK: - Gradient Button Components

/// A pressable glass capsule button style with gradient background
struct PressableGlassCapsuleStyle: ButtonStyle {
    var gradient: LinearGradient = .brandGradient

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(maxWidth: .infinity, minHeight: 64)
            .padding(.horizontal, 8)
            .foregroundStyle(.white)
            .contentShape(Capsule())
            .background(
                Capsule(style: .circular)
                    .fill(gradient)
            )
            .shadow(
                color: Color.black.opacity(configuration.isPressed ? 0.18 : 0.28),
                radius: configuration.isPressed ? 8 : 18,
                x: 0,
                y: configuration.isPressed ? 4 : 10
            )
            .scaleEffect(configuration.isPressed ? 0.985 : 1.0)
            .animation(
                .spring(response: 0.25, dampingFraction: 0.9, blendDuration: 0.15),
                value: configuration.isPressed
            )
    }
}

/// A large gradient button with haptic feedback
struct LargeGradientButton: View {
    var title: String
    var action: () -> Void

    var body: some View {
        Button(action: {
            Haptics.tick()
            action()
        }) {
            Text(title)
                .font(.title3.weight(.semibold))
        }
        .buttonStyle(PressableGlassCapsuleStyle())
        .padding(.bottom, 12)
    }
}
