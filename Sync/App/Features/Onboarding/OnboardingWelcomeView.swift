// OnboardingWelcomeView.swift
import SwiftUI
import UIKit

// MARK: - Haptics Helper
private enum Haptics {
    static func tick() {
        let g = UIImpactFeedbackGenerator(style: .medium)
        g.impactOccurred()
    }
    static func prepare() {
        UIImpactFeedbackGenerator(style: .medium).prepare()
    }
}


// MARK: - Onboarding Welcome View
struct OnboardingWelcomeView: View {
    var onProceed: () -> Void = {}

    var body: some View {
        ZStack(alignment: .top) {
            Color(UIColor.systemGroupedBackground).ignoresSafeArea()

            VStack(alignment: .leading, spacing: 20) {
                // ヘッダー：挨拶とアバター
                HStack(alignment: .center) {
                    Text("👋")
                        .font(.system(size: 44))
                        .accessibilityHidden(true)
                    Spacer()
                    if let ui = UIImage(named: "coach_avatar") {
                        Image(uiImage: ui)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 120, height: 120)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(Color.black.opacity(0.06), lineWidth: 1))
                            .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 3)
                    } else {
                        Image(systemName: "person.circle.fill")
                            .font(.system(size: 112))
                            .foregroundStyle(.secondary)
                            .accessibilityLabel("コーチのイメージ")
                    }
                }
                .padding(.top, 24)

                // 見出し
                Text("こんにちは！")
                    .font(.system(size: 44, weight: .heavy))
                    .foregroundStyle(.primary)

                // 説明文
                Text("わたしはAIコーチの\(Text("Sync").foregroundStyle(.blue))です! \nあなたの専用プランを作るので、いくつか質問させていただきます。")
                    .font(.title3)
                    .foregroundStyle(.primary)
                    .lineSpacing(14)

                Spacer().frame(height: 40)
            }
            .padding(.horizontal, 24)
            .onAppear { Haptics.prepare() }
        }
        .toolbar(.hidden, for: .navigationBar)
        .safeAreaInset(edge: .top) {
            Color.clear
                .frame(height: 60)
        }
        .safeAreaInset(edge: .bottom) {
            LargeGradientButton(title: "準備ができました") {
                onProceed()
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
        }
    }
}

// MARK: - Custom Button Components

private struct PressableGlassCapsuleStyle: ButtonStyle {
    var gradient: LinearGradient = LinearGradient(
        gradient: Gradient(stops: [
            .init(color: Color(red: 107/255, green: 94/255, blue: 255/255), location: 0.0),
            .init(color: Color(red: 124/255, green: 77/255, blue: 255/255), location: 0.62),
            .init(color: Color(red: 140/255, green: 84/255, blue: 255/255), location: 0.94)
        ]),
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(maxWidth: .infinity, minHeight: 64)
            .padding(.horizontal, 8)
            .foregroundStyle(.white)
            .contentShape(Capsule())
            .background(
                Capsule(style: .circular)
                    .fill(gradient)
                    // .glassEffect() // Note: .glassEffect() is not a standard SwiftUI modifier.
                                     // This might be a custom extension you have.
            )
            .shadow(color: Color.black.opacity(configuration.isPressed ? 0.18 : 0.28),
                    radius: configuration.isPressed ? 8 : 18,
                    x: 0, y: configuration.isPressed ? 4 : 10)
            .scaleEffect(configuration.isPressed ? 0.985 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.9, blendDuration: 0.15),
                       value: configuration.isPressed)
    }
}

private struct LargeGradientButton: View {
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

#Preview {
    OnboardingWelcomeView()
}
