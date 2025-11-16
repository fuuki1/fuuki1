import SwiftUI

// MARK: - Part Intro View

/// An introduction view for each part of the onboarding flow with animations
struct PartIntroView: View {
    let partNumber: Int
    let title: String
    let subtitle: String
    /// Closure invoked when the user proceeds to the next step. Marked
    /// `@Sendable` so it can safely be captured in concurrent contexts.
    let onContinue: @MainActor @Sendable () -> Void

    @State private var showPartNumber = false
    @State private var showMainTitle = false
    @State private var showSubtitle = false
    @State private var showArrows = false
    @State private var arrowSlideOut = false
    @State private var autoProgressTask: DispatchWorkItem?

    @State private var backgroundPulse: CGFloat = 1.0
    @State private var lightBandOffset: CGFloat = -1.5
    @State private var containerWidth: CGFloat = 0

    var body: some View {
        ZStack {
            EnhancedAnimatedBackground(
                pulseScale: backgroundPulse,
                lightBandOffset: lightBandOffset
            )

            VStack(spacing: 40) {
                Spacer()

                Text("パート\(partNumber)")
                    .font(.system(size: 24, weight: .semibold, design: .rounded))
                    .foregroundColor(.white.opacity(0.9))
                    .opacity(showPartNumber ? 1 : 0)
                    .offset(y: showPartNumber ? 0 : -30)

                VStack(alignment: .leading, spacing: 8) {
                    Text(title)
                        .font(.system(size: 48, weight: .heavy, design: .rounded))
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                        .allowsTightening(true)
                        .truncationMode(.tail)
                        .scaleEffect(showMainTitle ? 1.0 : 0.9)
                        .opacity(showMainTitle ? 1 : 0)

                    Text(subtitle)
                        .font(.system(size: 32, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                        .opacity(showSubtitle ? 1 : 0)
                        .offset(y: showSubtitle ? 0 : 20)
                }
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 40)

                HStack(spacing: ArrowLayout.groupToPhotoGap) {
                    HStack(spacing: ArrowLayout.dotSpacing) {
                        ForEach(0..<3, id: \.self) { index in
                            AnimatedDotsArrowView()
                                .frame(width: ArrowLayout.dotSize, height: ArrowLayout.dotSize)
                        }
                    }

                    Image("矢印")
                        .renderingMode(.original)
                        .resizable()
                        .scaledToFit()
                        .frame(width: ArrowLayout.photoSize, height: ArrowLayout.photoSize)
                        .accessibilityHidden(true)
                }
                .opacity(showArrows && !arrowSlideOut ? 1 : 0)
                .background(
                    GeometryReader { proxy in
                        Color.clear
                            .onAppear { containerWidth = proxy.size.width }
                            .onChange(of: proxy.size.width) { oldWidth, newWidth in
                                containerWidth = newWidth
                            }
                    }
                )
                .offset(x: arrowSlideOut ? containerWidth : (showArrows ? 0 : -400))

                Spacer()
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { handleContinue() }
        .onAppear {
            startAnimationSequence()
            scheduleArrowSlideOutAndContinue()
        }
        .onDisappear {
            autoProgressTask?.cancel()
            autoProgressTask = nil
        }
    }

    private func startAnimationSequence() {
        withAnimation(.easeInOut(duration: 3.0).repeatForever(autoreverses: true)) {
            backgroundPulse = 1.05
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            withAnimation(.easeOut(duration: 0.5)) {
                showPartNumber = true
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7, blendDuration: 0)) {
                showMainTitle = true
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
            withAnimation(.easeOut(duration: 0.5)) {
                showSubtitle = true
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            withAnimation(.easeOut(duration: 0.8)) {
                showArrows = true
            }
        }
    }

    private func scheduleArrowSlideOutAndContinue() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) {
            withAnimation(.easeInOut(duration: 0.3)) {
                arrowSlideOut = true
            }
        }

        let task = DispatchWorkItem { [onContinue] in onContinue() }
        autoProgressTask = task
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5, execute: task)
    }

    private func handleContinue() {
        autoProgressTask?.cancel()
        autoProgressTask = nil
        onContinue()
    }
}
