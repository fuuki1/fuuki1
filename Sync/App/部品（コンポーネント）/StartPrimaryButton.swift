import SwiftUI

struct StartPrimaryButton: View {
    var title: String
    var action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.isEnabled) private var isEnabled
    @State private var pressed = false

    var body: some View {
        Button {
            Haptics.tick()
            action()
        } label: {
            Text(title)
                .font(.title3.weight(.bold))
                .padding(.vertical, 18)
                .frame(maxWidth: .infinity)
                .foregroundStyle(.white)
                .background(
                    Capsule(style: .circular)
                        .fill(Color(UIColor.systemGray3))
                        .overlay(
                            Capsule(style: .circular)
                                .fill(buttonGradient)
                                .opacity(isEnabled ? 1 : 0)
                        )
                        .glassEffect()
                )
                .overlay(
                    Capsule(style: .circular)
                        .stroke(.white.opacity(0.22), lineWidth: 1)
                )
                .scaleEffect(pressed ? 0.98 : 1.0)
                .animation(reduceMotion ? nil : .spring(response: 0.25, dampingFraction: 0.8), value: pressed)
                .compositingGroup()
        }
        .buttonStyle(.plain)
        .pressEvents(onPress: { pressed = true }, onRelease: { pressed = false })
        .accessibilityAddTraits(.isButton)
    }

    private var buttonGradient: LinearGradient {
        LinearGradient(
            gradient: Gradient(stops: [
                .init(color: Color(red: 107.0/255.0, green: 94.0/255.0,  blue: 255.0/255.0), location: 0.0),  // bluish violet (top‑left)
                .init(color: Color(red: 124.0/255.0, green: 77.0/255.0,  blue: 255.0/255.0), location: 0.62), // brand core #7C4DFF (main)
                .init(color: Color(red: 140.0/255.0, green: 84.0/255.0,  blue: 255.0/255.0), location: 0.94)  // subtle magenta tint (very little)
            ]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        StartPrimaryButton(title: "開始", action: {})
            .padding()
            .accessibilityIdentifier("start_primary")
    }
}
