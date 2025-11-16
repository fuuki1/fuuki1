// StartView.swift
import SwiftUI
import UIKit
import SwiftData

// MARK: - Haptics Helper
private enum Haptics {
    static func tick() {
        let g = UIImpactFeedbackGenerator(style: .medium)
        g.impactOccurred()
    }
    static func prepare() {
        UIImpactFeedbackGenerator(style: .medium).prepare()
    }
    static func success() {
        let n = UINotificationFeedbackGenerator()
        n.notificationOccurred(.success)
    }
}

// MARK: - Start View
struct StartView: View {
    var onStart: @Sendable () -> Void = {}
    var onContinueExisting: @Sendable () -> Void = {}
    
    @State private var showAuthSheet: Bool = false
    @State private var showWelcome: Bool = false
    @State private var showOnboarding: Bool = false
    @StateObject private var dataModel = DataModel()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        NavigationStack {
            ZStack {
                HeroBackground()
                LinearGradient(
                    colors: [Color.black.opacity(0.25), Color.black.opacity(0.55)],
                    startPoint: .top, endPoint: .bottom
                )
                .ignoresSafeArea()

                VStack(alignment: .leading, spacing: 16) {
                    Spacer(minLength: 0)

                    // 見出しブロック
                    VStack(alignment: .leading, spacing: 10) {
                        Text("自宅トレーニングを")
                            .font(.system(size: 34, weight: .heavy))
                            .kerning(0.5)
                            .foregroundStyle(.white)
                        Text("あなたに最適化。")
                            .font(.system(size: 34, weight: .heavy))
                            .kerning(0.5)
                            .foregroundStyle(.white.opacity(0.95))

                        StartBrand(text: "SYNC FITNESS")
                            .padding(.top, 8)
                    }

                    Spacer()

                    // プライマリ CTA
                    StartPrimaryButton(title: "開始") {
                        Haptics.tick()
                        onStart()
                        showWelcome = true
                    }
                    .accessibilityIdentifier("start_primary")

                    // セカンダリアクション
                    VStack(spacing: 10) {
                        HStack(spacing: 12) {
                            Rectangle()
                                .fill(Color.white.opacity(0.12))
                                .frame(height: 1)
                                .frame(maxWidth: .infinity)
                            Text("本アプリは既にご利用いただいてますか?")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(.white.opacity(0.7))
                                .multilineTextAlignment(.center)
                                .fixedSize(horizontal: false, vertical: true)
                                .lineLimit(2)
                                .layoutPriority(1)
                                .accessibilityIdentifier("start_continue_prompt")
                            Rectangle()
                                .fill(Color.white.opacity(0.12))
                                .frame(height: 1)
                                .frame(maxWidth: .infinity)
                        }
                        .padding(.horizontal, 12)

                        Button(action: {
                            Haptics.tick()
                            onContinueExisting()
                            showAuthSheet = true
                        }) {
                            HStack(spacing: 6) {
                                Text("既存アカウントで続行する")
                                    .multilineTextAlignment(.center)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .lineLimit(2)
                                    .layoutPriority(1)

                                Image(systemName: "chevron.right")
                                    .font(.subheadline.weight(.semibold))
                            }
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.9))
                        }
                        .frame(maxWidth: .infinity)
                        .accessibilityIdentifier("start_continue")
                        .padding(.bottom, 8)
                    }
                }
                .padding(.horizontal, 24)
                .safeAreaPadding(.bottom, 28)

            }
            .statusBarHidden(false)
            .navigationDestination(isPresented: $showWelcome) {
                OnboardingWelcomeView(onProceed: {
                    Haptics.success()
                    Task { @MainActor in
                        try? await Task.sleep(nanoseconds: 300_000_000)
                        showOnboarding = true
                    }
                })
            }
            .fullScreenCover(isPresented: $showOnboarding) {
                ImprovedOnboardingFlowView()
                    .environmentObject(dataModel)
            }
            .sheet(isPresented: $showAuthSheet) {
                AuthSheetView(
                    onClose: { showAuthSheet = false },
                    onApple: { /* TODO: hook Apple Sign In */ },
                    onICloud: { /* TODO: hook iCloud flow */ },
                    onGoogle: { /* TODO: hook Google Sign-In */ }
                )
                .presentationDetents([.height(280)])
                .presentationBackground(Color(.systemGray6))
                .presentationDragIndicator(.visible)
            }
        }
    }
}

/// バックグラウンド：アセット「start_hero」があれば使用、無ければ安全な代替色
private struct HeroBackground: View {
    var body: some View {
        if let ui = UIImage(named: "start_hero") {
            Image(uiImage: ui)
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()
                .accessibilityHidden(true)
        } else {
            // 代替（審査安全・ブランディング未定でもOK）
            Color(red: 0.05, green: 0.09, blue: 0.18)
                .ignoresSafeArea()
                .accessibilityHidden(true)
        }
    }
}

/// 認証方式のボトムシート
struct AuthSheetView: View {
    var onClose: @MainActor @Sendable () -> Void = {}
    var onApple: @MainActor @Sendable () -> Void = {}
    var onICloud: @MainActor @Sendable () -> Void = {}
    var onGoogle: @MainActor @Sendable () -> Void = {}
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 20) {
            // Header with title and close
            HStack(alignment: .center) {
                Text("次の方法で続行")
                    .font(.system(size: 24, weight: .heavy))
                Spacer()
                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill")
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(
                            colorScheme == .dark ? Color(white: 0.62) : Color(white: 0.88),
                            colorScheme == .dark ? Color(white: 0.18) : Color(white: 0.35)
                        )
                        .font(.title2.weight(.semibold))
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)

            VStack(spacing: 14) {
                // Apple Sign In
                Button(action: onApple) {
                    HStack(spacing: 12) {
                        Image(systemName: "applelogo")
                            .font(.title2.weight(.bold))
                        Text("Appleでサインイン")
                            .font(.system(size: 20, weight: .semibold))
                        Spacer()
                    }
                    .foregroundStyle(.white)
                    .padding(.vertical, 16)
                    .padding(.horizontal, 18)
                    .frame(maxWidth: .infinity)
                    .background(Color(red: 0.18, green: 0.18, blue: 0.19))
                    .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                }
                .accessibilityIdentifier("auth_apple")

                // iCloud
                Button(action: onICloud) {
                    HStack(spacing: 12) {
                        Image(systemName: "icloud.fill")
                            .font(.title2)
                        Text("iCloud")
                            .font(.system(size: 20, weight: .semibold))
                        Spacer()
                    }
                    .foregroundStyle(.white)
                    .padding(.vertical, 16)
                    .padding(.horizontal, 18)
                    .frame(maxWidth: .infinity)
                    .background(
                        LinearGradient(colors: [
                            Color(red: 0.19, green: 0.45, blue: 1.0),
                            Color(red: 0.08, green: 0.35, blue: 0.95)
                        ], startPoint: .leading, endPoint: .trailing)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                }
                .accessibilityIdentifier("auth_icloud")

                // Google
                Button(action: onGoogle) {
                    HStack(spacing: 12) {
                        Image("google")
                            .resizable()
                            .frame(width: 24, height: 24)
                        Text("Google")
                            .font(.system(size: 20, weight: .semibold))
                        Spacer()
                    }
                    .foregroundStyle(.black)
                    .padding(.vertical, 16)
                    .padding(.horizontal, 18)
                    .frame(maxWidth: .infinity)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                }
                .accessibilityIdentifier("auth_google")
            }
            .padding(.horizontal, 20)
        }
        .padding(.bottom, 0)
    }
}

#Preview {
    StartView()
        .modelContainer(for: [
            UserProfileEntity.self,
            WeightLogEntity.self,
            OutboxItemEntity.self,
            AuditLogEntity.self
        ], inMemory: true)
        .environmentObject(DataModel())
}
