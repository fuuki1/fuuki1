import SwiftUI
import HealthKit
import HealthKitUI

/// A reusable container view that applies a Liquid Glass effect to its
/// content. The effect is composed of a translucent ``Material``
/// backdrop, rounded corners, a subtle border, and glass shadows.
struct LiquidGlassCard<Content: View>: View {
    private let content: Content
    @Environment(\.colorScheme) private var cs

    /// Constructs a new ``LiquidGlassCard`` with the provided content.
    /// - Parameter content: A view builder that produces the card's
    ///   inner content.
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(16)
            // The core of the Liquid Glass effect. `Material` creates a
            // translucent backdrop that blurs whatever is behind the card.
            .background(.ultraThinMaterial)
            // Soft, rounded corners give the card a friendly feel.
            .cornerRadius(24)
            // A subtle adaptive border helps define the card's edges against
            // similarly coloured backgrounds.
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .stroke(cs == .dark ? Color.white.opacity(0.28) : Color.black.opacity(0.08), lineWidth: 1)
            )
            // Apply glass effect shadows for depth
            .glassEffect()
    }
}

// MARK: - HKActivityRingView (SwiftUI wrapper)
struct ActivityRingsView: UIViewRepresentable {
    var move: Double
    var moveGoal: Double
    var exercise: Double
    var exerciseGoal: Double
    var stand: Double
    var standGoal: Double

    func makeUIView(context: Context) -> HKActivityRingView {
        let view = HKActivityRingView()
        view.backgroundColor = .clear
        return view
    }

    func updateUIView(_ uiView: HKActivityRingView, context: Context) {
        let summary = HKActivitySummary()
        summary.activeEnergyBurned = HKQuantity(unit: HKUnit.kilocalorie(), doubleValue: move)
        summary.activeEnergyBurnedGoal = HKQuantity(unit: HKUnit.kilocalorie(), doubleValue: moveGoal)
        summary.appleExerciseTime = HKQuantity(unit: HKUnit.minute(), doubleValue: exercise)
        summary.appleExerciseTimeGoal = HKQuantity(unit: HKUnit.minute(), doubleValue: exerciseGoal)
        summary.appleStandHours = HKQuantity(unit: HKUnit.count(), doubleValue: stand)
        summary.appleStandHoursGoal = HKQuantity(unit: HKUnit.count(), doubleValue: standGoal)
        uiView.setActivitySummary(summary, animated: true)
    }
}

/// A view that mirrors the OtterLife health data permission screen using
/// SwiftUI and Apple's Liquid Glass design language. Metrics are laid
/// out in a grid of cards. Each card displays an icon, a title and
/// metric-specific values. The bottom of the view contains a call to
/// action button.
struct HealthDataAccessView: View {
    @Environment(\.colorScheme) private var colorScheme
    // Two flexible columns create a responsive grid similar to the
    // screenshot. Cards will expand equally across the available width.
    private let columns: [GridItem] = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    @State private var isRequestingAuth = false
    private let healthStore = HKHealthStore()
    /// 許可完了またはスキップ時に次の画面へ進めるためのフック
    var onContinue: (() -> Void)? = nil

    init(onContinue: (() -> Void)? = nil) {
        self.onContinue = onContinue
    }

    private var readTypes: Set<HKObjectType> {
        var s = Set<HKObjectType>()
        // 身体データ（Part2/JIT用）
        if let height = HKObjectType.quantityType(forIdentifier: .height) { s.insert(height) }
        if let bodyMass = HKObjectType.quantityType(forIdentifier: .bodyMass) { s.insert(bodyMass) }
        // アクティビティ/ダッシュボード用（Part3用）
        if let steps = HKObjectType.quantityType(forIdentifier: .stepCount) { s.insert(steps) }
        if let active = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned) { s.insert(active) }
        if let exercise = HKObjectType.quantityType(forIdentifier: .appleExerciseTime) { s.insert(exercise) }
        if let heart = HKObjectType.quantityType(forIdentifier: .heartRate) { s.insert(heart) }
        if let hrv = HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN) { s.insert(hrv) }
        if let resting = HKObjectType.quantityType(forIdentifier: .restingHeartRate) { s.insert(resting) }
        if let standHour = HKObjectType.categoryType(forIdentifier: .appleStandHour) { s.insert(standHour) }
        s.insert(HKObjectType.workoutType())
        s.insert(HKObjectType.activitySummaryType())
        if let sleep = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) { s.insert(sleep) }
        if let energy = HKObjectType.quantityType(forIdentifier: .dietaryEnergyConsumed) { s.insert(energy) }
        if let protein = HKObjectType.quantityType(forIdentifier: .dietaryProtein) { s.insert(protein) }
        if let fatTotal = HKObjectType.quantityType(forIdentifier: .dietaryFatTotal) { s.insert(fatTotal) }
        if let carbs = HKObjectType.quantityType(forIdentifier: .dietaryCarbohydrates) { s.insert(carbs) }
        if let water = HKObjectType.quantityType(forIdentifier: .dietaryWater) { s.insert(water) }
        // Stand のリング値は HKActivitySummary.appleStandHours（Quantity）から取得する（専用 QuantityTypeIdentifier は存在しない）。
        // 許可対象: activitySummaryType, activeEnergyBurned, appleExerciseTime, stepCount, workoutType, heartRate, heartRateVariabilitySDNN, restingHeartRate, sleepAnalysis (+ appleStandHour category for hourly events)

        return s
    }

    private func shouldRequestAuth() async -> Bool {
        await withCheckedContinuation { cont in
            healthStore.getRequestStatusForAuthorization(toShare: [], read: readTypes) { status, _ in
                cont.resume(returning: status == .shouldRequest)
            }
        }
    }

    private func requestAuthorization() async throws {
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            healthStore.requestAuthorization(toShare: [], read: readTypes) { ok, err in
                if let err = err { cont.resume(throwing: err); return }
                if ok { cont.resume(returning: ()) }
                else {
                    cont.resume(throwing: NSError(domain: "HealthKitAuth", code: 1, userInfo: [NSLocalizedDescriptionKey: "ユーザーが許可しませんでした"]))
                }
            }
        }
    }

    @State private var autoPrompted = false

    private func promptAuthIfNeeded() async {
        guard !autoPrompted else { return }
        autoPrompted = true
        guard HKHealthStore.isHealthDataAvailable() else { return }
        do {
            try await requestAuthorization()
        } catch {
            #if DEBUG
            print("[HealthKit] auto auth error: \(error)")
            #endif
        }
    }

    var body: some View {
        ZStack {
            // App-wide background (JP tuned; auto light/dark)
            LinearGradient(
                colors: (colorScheme == .dark
                         ? [
                            Color(red: 20/255, green: 18/255, blue: 31/255),
                            Color(red: 26/255, green: 20/255, blue: 45/255),
                            Color(red: 34/255, green: 22/255, blue: 66/255)
                           ]
                         : [
                            Color(red: 0.88, green: 0.89, blue: 0.96),
                            Color(red: 0.94, green: 0.92, blue: 0.98),
                            Color(red: 0.96, green: 0.94, blue: 1.00)
                           ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Title
                    Text("ヘルスケアデータのアクセス許可")
                        .font(.system(size: 26, weight: .bold)) // 日本語に最適化（rounded指定を外す）
                        .foregroundStyle(.primary)
                        .accessibilityAddTraits(.isHeader)

                    // Subtitle
                    Text("分析レポート作成のため、以下のヘルスケアデータの読み取り許可が必要です。あとから［設定］で変更できます。")
                        .font(.system(size: 15))
                        .foregroundStyle(.secondary)
                        .lineSpacing(2)
                    .foregroundStyle(.secondary)

                    // Cards grid
                    LazyVGrid(columns: columns, spacing: 12) {
                        // 目標
                        LiquidGlassCard {
                            VStack(alignment: .leading, spacing: 10) {
                                HStack(alignment: .center, spacing: 8) {
                                    Image(systemName: "target")
                                        .imageScale(.medium)
                                        .foregroundStyle(.primary)
                                    Text("目標")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundStyle(.primary)
                                    Spacer()
                                    // Circular progress indicator
                                    ZStack {
                                        Circle()
                                            .stroke(Color.purple.opacity(0.2), lineWidth: 4.5)
                                            .frame(width: 22, height: 22)
                                        Circle()
                                            .trim(from: 0, to: 0.25)
                                            .stroke(Color.purple, style: StrokeStyle(lineWidth: 4.5, lineCap: .round, lineJoin: .round))
                                            .frame(width: 22, height: 22)
                                            .rotationEffect(.degrees(-90))
                                    }
                                }
                                Text("1/4")
                                    .font(.system(size: 40, weight: .bold, design: .rounded))
                                    .foregroundStyle(.primary)
                            }
                        }

                        // 睡眠
                        LiquidGlassCard {
                            VStack(alignment: .leading, spacing: 10) {
                                HStack(spacing: 8) {
                                    Image(systemName: "bed.double.fill")
                                        .imageScale(.medium)
                                    Text("睡眠")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundStyle(.primary)
                                    Spacer()
                                    ZStack {
                                        Circle()
                                            .stroke(Color.blue.opacity(0.2), lineWidth: 4.5)
                                            .frame(width: 22, height: 22)
                                        Circle()
                                            .trim(from: 0, to: 0.9)
                                            .stroke(Color.blue, style: StrokeStyle(lineWidth: 4.5, lineCap: .round, lineJoin: .round))
                                            .frame(width: 22, height: 22)
                                            .rotationEffect(.degrees(-90))
                                    }
                                }
                                // Custom formatting for hours and minutes
                                HStack(alignment: .firstTextBaseline, spacing: 6) {
                                    Text("6")
                                        .font(.system(size: 36, weight: .bold, design: .rounded))
                                        .monospacedDigit()
                                        .foregroundStyle(.primary)
                                    Text("時間")
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundStyle(.secondary)
                                    Text("54")
                                        .font(.system(size: 36, weight: .bold, design: .rounded))
                                        .monospacedDigit()
                                        .foregroundStyle(.primary)
                                    Text("分")
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }

                        // ストレス
                        LiquidGlassCard {
                            VStack(alignment: .leading, spacing: 10) {
                                HStack(spacing: 8) {
                                    Image(systemName: "waveform.path.ecg")
                                        .imageScale(.medium)
                                    Text("ストレス")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundStyle(.primary)
                                }
                                HStack(alignment: .firstTextBaseline, spacing: 4) {
                                    Text("39")
                                        .font(.system(size: 40, weight: .bold, design: .rounded))
                                        .foregroundStyle(.primary)
                                    Text("ms")
                                        .font(.system(size: 18, weight: .medium))
                                        .foregroundStyle(.secondary)
                                }
                                // A horizontal progress bar to represent stress level
                                GeometryReader { geometry in
                                    ZStack(alignment: .leading) {
                                        Capsule()
                                            .fill(colorScheme == .dark ? Color.white.opacity(0.12) : Color.black.opacity(0.08))
                                            .frame(height: 8)
                                        
                                        Capsule()
                                            .fill(LinearGradient(
                                                gradient: Gradient(stops: [
                                                    .init(color: Color(red: 107.0/255.0, green: 94.0/255.0,  blue: 255.0/255.0), location: 0.0),  // bluish violet (top‑left)
                                                    .init(color: Color(red: 124.0/255.0, green: 77.0/255.0,  blue: 255.0/255.0), location: 0.62), // brand core #7C4DFF (main)
                                                    .init(color: Color(red: 140.0/255.0, green: 84.0/255.0,  blue: 255.0/255.0), location: 0.94)  // subtle magenta tint (very little)
                                                ]),
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            ))
                                            .frame(width: geometry.size.width * 0.39, height: 8)
                                    }
                                }
                                .frame(height: 8)
                            }
                        }

                        // アクティビティリング
                        LiquidGlassCard {
                            VStack(alignment: .leading, spacing: 10) {
                                HStack(alignment: .center, spacing: 4) {
                                    Image(systemName: "figure.run")
                                        .imageScale(.medium)
                                    Text("フィットネス")
                                        .font(.system(size: 15, weight: .semibold))
                                        .lineLimit(1)
                                        .truncationMode(.tail)
                                        .minimumScaleFactor(0.75)
                                        .allowsTightening(true)
                                        .tracking(-0.2)
                                        .layoutPriority(2)
                                        .foregroundStyle(.primary)
                                    Spacer(minLength: 0)
                                    ActivityRingsView(
                                        move: 198, moveGoal: 300,
                                        exercise: 30, exerciseGoal: 30,
                                        stand: 8, standGoal: 12
                                    )
                                    .frame(width: 44, height: 44)
                                }
                                VStack(alignment: .leading, spacing: 2) {
                                    HStack(spacing: 4) {
                                        Text("198")
                                            .font(.system(size: 20, weight: .bold, design: .rounded))
                                            .foregroundColor(.red)
                                        Text("/300")
                                            .font(.system(size: 20, weight: .bold, design: .rounded))
                                            .foregroundColor(.red.opacity(0.6))
                                        Spacer()
                                        Text("kcal")
                                            .font(.system(size: 14, weight: .medium))
                                            .foregroundColor(.secondary)
                                    }
                                    HStack(spacing: 4) {
                                        Text("30")
                                            .font(.system(size: 20, weight: .bold, design: .rounded))
                                            .foregroundColor(.green)
                                        Text("/30")
                                            .font(.system(size: 20, weight: .bold, design: .rounded))
                                            .foregroundColor(.green.opacity(0.6))
                                        Spacer()
                                        Text("min")
                                            .font(.system(size: 14, weight: .medium))
                                            .foregroundColor(.secondary)
                                    }
                                    HStack(spacing: 4) {
                                        Text("8")
                                            .font(.system(size: 20, weight: .bold, design: .rounded))
                                            .foregroundColor(.blue)
                                        Text("/12")
                                            .font(.system(size: 20, weight: .bold, design: .rounded))
                                            .foregroundColor(.blue.opacity(0.6))
                                        Spacer()
                                        Text("時間")
                                            .font(.system(size: 14, weight: .medium))
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                        }

                        // 飲み物
                        LiquidGlassCard {
                            VStack(alignment: .leading, spacing: 10) {
                                HStack(spacing: 8) {
                                    Image(systemName: "drop.fill")
                                        .imageScale(.medium)
                                    Text("飲み物")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundStyle(.primary)
                                }
                                HStack(alignment: .firstTextBaseline, spacing: 4) {
                                    Text("1,250")
                                        .font(.system(size: 40, weight: .bold, design: .rounded))
                                        .foregroundStyle(.primary)
                                    Text("ml")
                                        .font(.system(size: 18, weight: .medium))
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }

                        // 歩数
                        LiquidGlassCard {
                            VStack(alignment: .leading, spacing: 10) {
                                HStack(spacing: 8) {
                                    Image(systemName: "figure.walk")
                                        .imageScale(.medium)
                                    Text("歩数")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundStyle(.primary)
                                }
                                HStack(alignment: .firstTextBaseline, spacing: 4) {
                                    Text("24,531")
                                        .font(.system(size: 32, weight: .bold, design: .rounded))
                                        .foregroundStyle(.primary)
                                    Text("歩")
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }

                        // 正念
                        LiquidGlassCard {
                            VStack(alignment: .leading, spacing: 10) {
                                HStack(spacing: 8) {
                                    Image(systemName: "calendar")
                                        .imageScale(.medium)
                                    Text("生理周期")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundStyle(.primary)
                                    Spacer()
                                    ZStack {
                                        Circle()
                                            .stroke(Color.pink.opacity(0.2), lineWidth: 4.5)
                                            .frame(width: 22, height: 22)
                                        Circle()
                                            .trim(from: 0, to: 0.4)
                                            .stroke(Color.pink, style: StrokeStyle(lineWidth: 4.5, lineCap: .round, lineJoin: .round))
                                            .frame(width: 22, height: 22)
                                            .rotationEffect(.degrees(-90))
                                    }
                                }
                                Text("次の期間まで")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(.secondary)
                                HStack(alignment: .firstTextBaseline, spacing: 4) {
                                    Text("10")
                                        .font(.system(size: 36, weight: .bold, design: .rounded))
                                        .foregroundStyle(.primary)
                                    Text("日目")
                                        .font(.system(size: 18, weight: .medium))
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }

                        // カロリー
                        LiquidGlassCard {
                            VStack(alignment: .leading, spacing: 10) {
                                HStack(spacing: 8) {
                                    Image(systemName: "flame.fill")
                                        .imageScale(.medium)
                                    Text("カロリー")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundStyle(.primary)
                                    Spacer()
                                    ZStack {
                                        Circle()
                                            .stroke(Color.green.opacity(0.2), lineWidth: 4.5)
                                            .frame(width: 22, height: 22)
                                        Circle()
                                            .trim(from: 0, to: 0.7)
                                            .stroke(Color.green, style: StrokeStyle(lineWidth: 4.5, lineCap: .round, lineJoin: .round))
                                            .frame(width: 22, height: 22)
                                            .rotationEffect(.degrees(-90))
                                    }
                                }
                                HStack(alignment: .firstTextBaseline, spacing: 4) {
                                    Text("残り")
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundStyle(.secondary)
                                    Text("786")
                                        .font(.system(size: 36, weight: .bold, design: .rounded))
                                        .foregroundStyle(.primary)
                                    Text("kcal")
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }

                }
                .padding(.horizontal, 16)
                .padding(.vertical, 32)
            }
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 0) {
                    Divider()
                        .opacity(colorScheme == .dark ? 0.25 : 0.12)
                    StartPrimaryButton(title: "次へ") {
                        Task { @MainActor in
                            guard HKHealthStore.isHealthDataAvailable() else {
                                onContinue?()
                                return
                            }
                            isRequestingAuth = true
                            defer { isRequestingAuth = false }
                            do {
                                try await requestAuthorization()
                            } catch {
                                #if DEBUG
                                print("[HealthKit] auth error: \(error)")
                                #endif
                            }
                            onContinue?()
                        }
                    }
                    .disabled(isRequestingAuth)
                    .contentShape(Rectangle())
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 12)
                }
                .zIndex(10)
                .background(.clear)
            }
            .task { await promptAuthIfNeeded() }
        }
    }
}

#if DEBUG
#Preview("Light") {
    NavigationStack {
        HealthDataAccessView()
            .environment(\.colorScheme, .light)
    }
}

#Preview("Dark") {
    NavigationStack {
        HealthDataAccessView()
            .environment(\.colorScheme, .dark)
    }
}

#Preview("Hit Test Debug") {
    NavigationStack {
        HealthDataAccessView()
            .overlay(alignment: .bottom) {
                // 可視化のための補助オーバーレイ（ヒットテストには影響しません）
                Rectangle()
                    .stroke(style: StrokeStyle(lineWidth: 1, dash: [6, 4]))
                    .foregroundStyle(.secondary)
                    .frame(height: 1)
                    .padding(.bottom, 84)
                    .allowsHitTesting(false)
            }
    }
}
#endif
