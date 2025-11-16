// OnboardingWelcomeView.swift
import SwiftUI
import UIKit

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

#Preview {
    OnboardingWelcomeView()
}
