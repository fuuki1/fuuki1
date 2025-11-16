import SwiftUI
import Foundation


public struct PlanOption: Identifiable {
    public var id: String { difficulty.rawValue }
    public let difficulty: PlanDifficulty
    public let weeklyRateKg: Double       // 週あたりの体重変化 (kg)。減量は負値
    public let dailyCalorieIntake: Double // 摂取カロリー (kcal/日)
    public let weeksNeeded: Double        // 達成に必要な週数
    public let title: String              // 表示名（簡単・普通・難しい）
}

public struct GoalPlanCalculator {
    /// BMR を計算する
    private static func calculateBMR(weightKg: Double, heightCm: Double, age: Int, gender: Gender) -> Double {
        switch gender {
        case .male:
            return 10 * weightKg + 6.25 * heightCm - 5 * Double(age) + 5
        case .female:
            return 10 * weightKg + 6.25 * heightCm - 5 * Double(age) - 161
        case .unspecified:
            // 男女の平均差（+5 と -161 の平均）= -78 を用いる
            return 10 * weightKg + 6.25 * heightCm - 5 * Double(age) - 78
        }
    }

    /// 体型による補正係数を返す
    private static func bodyFactor(_ type: BodyTypeModel) -> Double {
        switch type {
        case .lean:     return 1.05
        case .standard: return 1.0
        case .muscular: return 1.10
        case .chubby:   return 0.95
        }
    }

    /// 活動レベルによる補正係数を返す
    private static func activityFactor(_ level: ActivityLevelModel) -> Double {
        switch level {
        case .sedentary:    return 1.2
        case .light:        return 1.375
        case .moderate:     return 1.55
        case .active:       return 1.725
        case .professional: return 1.9
        }
    }

    /// 性別による最低カロリー下限
    private static func minCalorie(for gender: Gender) -> Double {
        switch gender {
        case .male:        return 1500
        case .female:      return 1200
        case .unspecified: return 1350
        }
    }

    /// プランを計算する
    public static func computePlans(currentWeight: Double,
                                    targetWeight: Double,
                                    bodyType: BodyTypeModel,
                                    activityLevel: ActivityLevelModel,
                                    age: Int,
                                    gender: Gender,
                                    heightCm: Double) -> [PlanOption] {
        // 基本パラメータ
        let bmr = calculateBMR(weightKg: currentWeight, heightCm: heightCm, age: age, gender: gender)
        let tdee = bmr * bodyFactor(bodyType) * activityFactor(activityLevel)
        let weightDiff = targetWeight - currentWeight
        let diffKg = abs(weightDiff)

        // 目標が現在と同じなら変化なし
        if diffKg < 0.001 {
            return []
        }

        // 週当たりの変化量
        let rates: [Double]
        if weightDiff < 0 {
            // 減量用 (簡単〜難しい)
            rates = [0.25, 0.5, 0.75]
        } else {
            // 増量用 (簡単〜難しい)
            rates = [0.2, 0.4, 0.6]
        }

        var plans: [PlanOption] = []
        for (index, rate) in rates.enumerated() {
            let weeklyCalorieChange = rate * 7500.0
            let dailyChange = weeklyCalorieChange / 7.0
            // 摂取カロリー計算 (減量なら引き算、増量なら足し算)
            let rawIntake = (weightDiff < 0) ? (tdee - dailyChange) : (tdee + dailyChange)
            // 下限チェック
            let intake = max(rawIntake, minCalorie(for: gender))
            // 必要週数
            let weeks = diffKg / rate
            let difficulty: PlanDifficulty = (index == 0 ? .easy : (index == 1 ? .normal : .hard))
            let title: String
            switch difficulty {
            case .easy:   title = "簡単"
            case .normal: title = "普通"
            case .hard:   title = "難しい"
            }
            plans.append(PlanOption(
                difficulty: difficulty,
                weeklyRateKg: weightDiff < 0 ? -rate : rate,
                dailyCalorieIntake: intake,
                weeksNeeded: weeks,
                title: title
            ))
        }
        return plans
    }
}

// MARK: - PlanOption to GoalPlanSelection Conversion

extension PlanOption {
    /// PlanOptionをGoalPlanSelectionに変換する
    func toGoalPlanSelection() -> GoalPlanSelection {
        GoalPlanSelection(
            difficulty: difficulty,
            weeklyRateKg: weeklyRateKg,
            dailyCalorieIntake: dailyCalorieIntake,
            weeksNeeded: weeksNeeded,
            selectedAt: Date(),
            planTitle: title
        )
    }
}

// MARK: - View Components

private extension Color {
    static let brandPurple = Color(red: 124/255, green: 77/255, blue: 255/255) // #7C4DFF
}

private func formatKg(_ x: Double) -> String { String(format: "%.1f", x) }

private func planSubtitle(_ plan: PlanOption) -> String {
    let weekly = abs(plan.weeklyRateKg)
    let weeks  = Int(ceil(plan.weeksNeeded))
    let verb   = plan.weeklyRateKg >= 0 ? "増量し" : "減量し"
    return "毎週\(formatKg(weekly))kg\(verb)、\(weeks)週間で完了"
}

private struct PlanCard: View {
    let plan: PlanOption
    let isSelected: Bool
    let tap: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    var subtitle: String { planSubtitle(plan) }

    var body: some View {
        Button(action: tap) {
            HStack(spacing: 16) {
                VStack(alignment: .center, spacing: 4) {
                    Text(plan.title)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.center)

                    Text(subtitle)
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, alignment: .center)
            }
            .padding(18)
            .frame(maxWidth: .infinity, minHeight: 80, alignment: .center)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        // ベース背景(常に表示)
        .background(
            Capsule(style: .circular)
                .fill(Color(.systemBackground))
                .overlay(
                    Capsule(style: .circular)
                        .strokeBorder(.white.opacity(colorScheme == .dark ? 0.28 : 0.18), lineWidth: 1)
                )
        )
        // 選択時のグラデーション背景(上に重ねる)
        .background(
            Capsule(style: .circular)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 95/255, green: 134/255, blue: 1.0),
                            Color(red: 124/255, green:  77/255, blue: 1.0)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .opacity(isSelected ? (colorScheme == .dark ? 0.18 : 0.10) : 0)
        )
        // 選択時のグラデーション枠
        .overlay(
            Capsule(style: .circular)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            Color(red: 95/255, green: 134/255, blue: 1.0),
                            Color(red: 124/255, green:  77/255, blue: 1.0)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    lineWidth: 2
                )
                .opacity(isSelected ? 1 : 0)
        )
        // 影で立体感
        .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 4)
        .animation(.snappy, value: isSelected)
        .sensoryFeedback(.selection, trigger: isSelected)
    }
}

// MARK: - Main View

struct GoalPlanStepView: View {
    @State private var plans: [PlanOption] = []
    @State private var selected: PlanOption?
    @State private var errorMessage: String? = nil
    @State private var isSaving: Bool = false
    @State private var showResult: Bool = false
    @State private var resultPrefill: GoalPlanResultPrefill? = nil
    
    // 依存関係
    let repository: any SyncingProfileRepository
    let user: UserProfile
    let targetWeight: Double
    var onContinue: () -> Void = {}

    private var recalcKey: String {
        let w  = user.weightKg.map { String($0) } ?? "nil"
        let h  = user.heightCm.map { String($0) } ?? "nil"
        let a  = user.age.map { String($0) } ?? "nil"
        let al = user.activityLevel?.rawValue ?? "nil"
        let g  = user.gender?.rawValue ?? "nil"
        let t  = String(targetWeight)
        return [w, h, a, al, g, t].joined(separator: "|")
    }

    private var primaryButtonColor: Color {
        selected == nil ? Color(.systemGray3) : .brandPurple
    }

    private func regeneratePlans() {
        print("[GoalPlan] regeneratePlans recalcKey=\(recalcKey)")
        guard let current = user.weightKg else {
            self.plans = []
            self.errorMessage = "現在の体重が未入力です。前のステップで入力してください。"
            return
        }
        let tgt = targetWeight
        let body = user.bodyType ?? .standard
        let level = user.activityLevel ?? .moderate
        let age = user.age ?? 30
        let gender = user.gender ?? .unspecified
        let height = user.heightCm ?? 170

        let result = GoalPlanCalculator.computePlans(
            currentWeight: current,
            targetWeight: tgt,
            bodyType: body,
            activityLevel: level,
            age: age,
            gender: gender,
            heightCm: height
        )
        self.plans = result
        print("[GoalPlan] computed plans count=\(result.count)")
        if result.isEmpty {
            if abs(tgt - current) < 0.01 {
                self.errorMessage = "目標体重が現在と同じです。目標体重を変更してください。"
            } else {
                self.errorMessage = "必要なデータが不足しています。前のステップを確認してください。"
            }
        } else {
            self.errorMessage = nil
        }
    }
    
    /// 選択されたプランを保存する
    private func savePlan(_ plan: PlanOption) async throws {
        // 1. PlanOption → GoalPlanSelection
        let planSelection = plan.toGoalPlanSelection()

        // 2. 目標達成予定日（現在日時 + 必要週数）
        let targetDate = Calendar.current.date(
            byAdding: .weekOfYear,
            value: Int(ceil(plan.weeksNeeded)),
            to: Date()
        )

        // 3. 既存のGoalタイプを尊重（未設定なら暫定で .loseFat）
        let profile = try await repository.getProfile()
        let goalType = profile.goal?.type ?? .loseFat

        // 4. 新しいGoalProfileを構築して保存
        let savedGoal = GoalProfile(
            type: goalType,
            goalWeightKg: targetWeight,
            planSelection: planSelection,
            targetDate: targetDate
        )
        try await repository.updateGoal(savedGoal)
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 24) {
                // Title
                Text("希望するプランを選択")
                    .font(.system(size: 32, weight: .bold))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 8)

                // Current / Target stats
                HStack(spacing: 24) {
                    // Current weight column
                    VStack(alignment: .center, spacing: 6) {
                        Text("現在の体重").font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
                        VStack(spacing: 2) {
                            Text(formatKg(user.weightKg ?? 0))
                                .font(.system(size: 54, weight: .heavy))
                                .foregroundStyle(Color.brandPurple)
                            Text("kg")
                                .font(.title3).bold()
                                .foregroundStyle(.primary)
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                    }
                    .frame(maxWidth: .infinity, alignment: .center)

                    // Target weight column
                    VStack(alignment: .center, spacing: 6) {
                        Text("目標体重").font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
                        VStack(spacing: 2) {
                            Text(formatKg(targetWeight))
                                .font(.system(size: 54, weight: .heavy))
                                .foregroundStyle(Color.brandPurple)
                            Text("kg")
                                .font(.title3).bold()
                                .foregroundStyle(.primary)
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                }
                .padding(.top, 8)

                // Plan cards
                Group {
                    if plans.isEmpty {
                        VStack(spacing: 8) {
                            Text(errorMessage ?? "プランを表示できませんでした")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                    } else {
                        VStack(spacing: 18) {
                            ForEach(plans, id: \.id) { plan in
                                PlanCard(
                                    plan: plan,
                                    isSelected: selected?.difficulty == plan.difficulty,
                                    tap: { selected = plan }
                                )
                            }
                        }
                        .padding(.top, 8)
                    }
                }

                Spacer(minLength: 0)

            }
            .padding(.horizontal, 20)
            .padding(.bottom, 120)
        }
        .onAppear { regeneratePlans() }
        .task(id: recalcKey) {
            regeneratePlans()
        }
        .safeAreaInset(edge: .bottom) {
            // 固定フッター: 次へボタン
            StartPrimaryButton(title: "次へ") {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                print("[GoalPlan] NEXT tapped. selected=\(String(describing: selected)), isSaving=\(isSaving)")

                guard let plan = selected else { return }

                // Ensure state mutations happen on MainActor
                Task { @MainActor in
                    isSaving = true
                }

                Task {
                    defer {
                        Task { @MainActor in isSaving = false }
                    }

                    do {
                        try await savePlan(plan)
                    } catch {
                        await MainActor.run {
                            errorMessage = "保存に失敗しました: \(error.localizedDescription)"
                        }
                    }

                    // Fire-and-forget remote sync (do not block navigation)
                    Task { await repository.syncWithRemote() }

                    await MainActor.run {
                        print("[GoalPlan] continue()")
                        onContinue()
                    }
                }
            }
            .contentShape(Rectangle())
            .allowsHitTesting(true)
            .zIndex(10)
            .disabled(selected == nil || isSaving)
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 8)
        }
    }
}

// MARK: - Previews

#Preview("GoalPlan (減量・ライト)") {
    let sample = UserProfile(
        name: "プレビュー",
        age: 28,
        gender: .male,
        bodyType: .standard,
        heightCm: 173,
        weightKg: 70,
        activityLevel: .moderate,
        goal: GoalProfile(type: .loseFat, goalWeightKg: 65)
    )
    let repo = DefaultSyncingProfileRepository.makePreview()
    return GoalPlanStepView(repository: repo, user: sample, targetWeight: 65)
        .padding()
        .preferredColorScheme(.light)
}

#Preview("GoalPlan (増量・ダーク)") {
    let sample = UserProfile(
        name: "プレビュー",
        age: 28,
        gender: .female,
        bodyType: .lean,
        heightCm: 165,
        weightKg: 50,
        activityLevel: .light,
        goal: GoalProfile(type: .bulkUp, goalWeightKg: 54)
    )
    let repo = DefaultSyncingProfileRepository.makePreview()
    return GoalPlanStepView(repository: repo, user: sample, targetWeight: 54)
        .padding()
        .preferredColorScheme(.dark)
}
