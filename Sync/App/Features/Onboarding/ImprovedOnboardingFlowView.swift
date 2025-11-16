import SwiftUI
import UIKit

// MARK: - 改善版オンボーディングフロー(router切替・FlowGate統合・アニメーション強化)

public struct ImprovedOnboardingFlowView: View {
    public enum Step: CaseIterable, Hashable {
        // パート1:基本情報
        case part1Intro
        case name
        case gender
        case age

        // パート2:現在の身体データ
        case part2Intro
        case height
        case weight
        case bodyType
        case activityLevel

        // パート3:目標設定
        case part3Intro
        case goalType
        case goalWeight
        case goalPlan
        case availableEquipment
        case workoutSchedule
        case goalPlanResult
        case aiPlanGeneration
        case done
    }

    private let profileRepo: DefaultSyncingProfileRepository = .makePreview()
    
    @State private var name: String = ""
    @State private var age: Int? = nil
    @State private var heightCm: Double? = nil
    @State private var weightKg: Double? = nil
    @State private var goalWeightKg: Double? = nil
    @State private var step: Step = .part1Intro
    @State private var hasPrefilled = false
    @State private var gate = FlowGate()
    
    // WorkoutScheduleViewから選択された曜日を保存
    @State private var selectedWorkoutWeekdays: [Int] = []
    
    // 連打防止用のロックフラグ
    @State private var isNextLocked: Bool = false

    private var progress: Double {
        switch step {
        case .part1Intro: return 0.0 / 3.0
        case .name:       return 1.0 / 3.0
        case .gender:     return 2.0 / 3.0
        case .age:        return 3.0 / 3.0
        case .part2Intro:     return 0.0 / 4.0
        case .height:         return 1.0 / 4.0
        case .weight:         return 2.0 / 4.0
        case .bodyType:       return 3.0 / 4.0
        case .activityLevel:  return 4.0 / 4.0
        // Part 3: updated order
        case .part3Intro:      return 0.0 / 8.0
        case .goalType:        return 1.0 / 8.0
        case .goalWeight:      return 2.0 / 8.0
        case .goalPlan:        return 3.0 / 8.0
        case .availableEquipment: return 4.0 / 8.0
        case .workoutSchedule: return 5.0 / 8.0
        case .goalPlanResult:  return 6.0 / 8.0
        case .aiPlanGeneration: return 7.0 / 8.0
        case .done:            return 8.0 / 8.0
        }
    }


    private var currentPart: Int {
        switch step {
        case .part1Intro, .name, .gender, .age:
            return 1

        case .part2Intro, .height, .weight, .bodyType, .activityLevel:
            return 2

        case .part3Intro,
             .goalType,
             .goalWeight,
             .goalPlan,
             .availableEquipment,
             .workoutSchedule,
             .goalPlanResult,
             .aiPlanGeneration,
             .done:
            return 3
        }
    }

    private var userForPlan: UserProfile {
        UserProfile(
            name: name.isEmpty ? nil : name,
            age: age,
            gender: nil,
            bodyType: nil,
            heightCm: heightCm,
            weightKg: weightKg,
            activityLevel: nil,
            goal: GoalProfile(type: nil, goalWeightKg: goalWeightKg)
        )
    }
    
    private var isFirstStep: Bool { Step.allCases.first == step }

    private func nextStep(from current: Step) -> Step? {
        guard let idx = Step.allCases.firstIndex(of: current),
              idx < Step.allCases.count - 1 else { return nil }
        return Step.allCases[idx + 1]
    }

    // ImprovedOnboardingFlowView の continueFlow() に連打防止ロジックを追加
    /// Advances to the next step in the onboarding flow. Runs on the main actor
    /// to ensure state mutations occur on the correct thread and guards against
    /// rapid repeated taps.
    @MainActor
    private func continueFlow() {
        // 連打防止：すでに遷移中、またはロック中なら無視
        guard !isNextLocked, !gate.isNavigating else {
            print("[OnboardingFlow] continueFlow ignored (locked or navigating)")
            return
        }
        isNextLocked = true
        
        print("[OnboardingFlow] continueFlow called, current step: \(step)")
        gate.navigate {
            if let next = nextStep(from: step) {
                print("[OnboardingFlow] Moving to next step: \(next)")
                withAnimation(.easeInOut(duration: 0.3)) {
                    step = next
                }
            } else {
                print("[OnboardingFlow] No next step found!")
            }
        }
        
        // 一定時間後にロック解除（アニメーション完了を待つため少し余裕を持たせる）
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            isNextLocked = false
        }
    }
    public init() {}

    public var body: some View {
        ZStack {
            currentStepView
        }
        .animation(.easeInOut(duration: 0.3), value: step)
        .safeAreaInset(edge: .top) { header }
        // Perform a one‑time prefill of existing profile data when the view
        // appears. Explicitly run this task on the main actor so that updates
        // to `@State` properties occur on the UI thread. Without the
        // `@MainActor` annotation Swift 6.2 may emit warnings about capturing
        // non‑Sendable state in a concurrent context.
        .task(id: hasPrefilled) { @MainActor in
            guard !hasPrefilled else { return }
            await prefillIfNeeded()
            hasPrefilled = true
        }
        .onAppear {
            print("🎯 [OnboardingFlow] Body appeared, step: \(step)")
        }
    }

    @ViewBuilder
    private var currentStepView: some View {
        switch step {
        // パート1
        case .part1Intro:
            PartIntroView(
                partNumber: 1,
                title: "あなたの基本情報",
                subtitle: "まずは、あなたの基本情報を入力しましょう。",
                onContinue: continueFlow
            )
            .transition(scaleTransition)

        case .name:
            OLNameStepView(
                name: $name,
                gate: gate,
                onContinue: continueFlow,
                profileRepo: profileRepo
            )
            .transition(slideTransition)

        case .gender:
            OLGenderStepView(
                gate: gate,
                profileRepo: profileRepo,
                onContinue: { _ in continueFlow() }
            )
            .transition(slideTransition)

        case .age:
            OLAgeStepView(
                age: $age,
                gate: gate,
                onContinue: continueFlow,
                profileRepo: profileRepo
            )
            .transition(slideTransition)

        // パート2
        case .part2Intro:
            PartIntroView(
                partNumber: 2,
                title: "自分の体を知ろう",
                subtitle: "あなたの身体情報を入力して、現在の状態を把握しましょう。",
                onContinue: continueFlow
            )
            .transition(scaleTransition)

        case .height:
            OLHeightStepView(
                heightCm: $heightCm,
                gate: gate,
                onContinue: continueFlow,
                profileRepo: profileRepo
            )
            .transition(slideTransition)

        case .weight:
            OLWeightStepView(
                weightKg: $weightKg,
                gate: gate,
                onContinue: continueFlow,
                profileRepo: profileRepo
            )
            .transition(slideTransition)

        case .bodyType:
            OLBodyTypeStepView(
                gate: gate,
                profileRepo: profileRepo,
                onContinue: { _ in continueFlow() }
            )
            .transition(slideTransition)

        case .activityLevel:
            OLActivityLevelStepView(
                gate: gate,
                profileRepo: profileRepo,
                onContinue: { _ in continueFlow() }
            )
            .transition(slideTransition)

        // パート3
        case .part3Intro:
            PartIntroView(
                partNumber: 3,
                title: "目標とプラン設定",
                subtitle: "あなたの目標を設定し、最適なプランを選択しましょう",
                onContinue: continueFlow
            )
            .transition(scaleTransition)

        case .goalType:
            OLGoalTypeStepView(
                gate: gate,
                onContinue: continueFlow,
                profileRepo: profileRepo
            )
            .transition(slideTransition)

        case .goalWeight:
            OLGoalWeightStepView(
                goalWeightKg: $goalWeightKg,
                       currentWeightKg: weightKg,
                       currentHeightCm: heightCm,
                       gate: gate,
                       profileRepo: profileRepo,
                       onContinue: continueFlow
            )
            .transition(slideTransition)
            
        case .goalPlan:
            GoalPlanStepView(
                repository: profileRepo,
                user: userForPlan,
                targetWeight: goalWeightKg ?? weightKg ?? 0,
                onContinue: continueFlow
            )
            .transition(slideTransition)

        case .availableEquipment:
            AvailableEquipmentView(
                onSave: { _ in },
                onSaveSplit: { cats, dets in
                    print("🟢 [OnboardingFlow] onSaveSplit called")
                    print("   📍 Current step BEFORE: \(step)")
                    print("   📍 Next step calculation...")
                    
                    // 次のステップを計算
                    guard let next = nextStep(from: step) else {
                        print("   ❌ No next step found!")
                        return
                    }
                    
                    print("   📍 Next step: \(next)")
                    print("   🔄 Updating step with animation...")
                    
                    // ✅ 画面遷移（同期的）
                    withAnimation(.easeInOut(duration: 0.3)) {
                        step = next
                    }
                    
                    print("   📍 Current step AFTER: \(step)")
                    
                    // ✅ 保存処理（非同期・分離）
                    // In Swift 6.2, passing a non‑Sendable repository into a
                    // background queue can result in concurrency warnings. To
                    // avoid capturing `profileRepo` across actor boundaries,
                    // perform the save operations within a `Task` scoped to the
                    // main actor. This ensures that the updates occur on the
                    // correct isolation context while still running
                    // asynchronously.
                    Task { @MainActor in
                        do {
                            try await profileRepo.updatePreferredActivities(Array(cats))
                            try await profileRepo.updateOwnedEquipments(Array(dets))
                            await profileRepo.syncWithRemote()
                            print("✅ [AvailableEquipment] Saved successfully")
                        } catch {
                            print("❌ [AvailableEquipment] Save failed: \(error)")
                        }
                    }
                }
            )
            .transition(slideTransition)
            .transition(slideTransition)
            .transition(slideTransition)

        case .workoutSchedule:
            WorkoutScheduleView(
                selectedWorkoutWeekdays: selectedWorkoutWeekdays
            ) { weekdays in
                // 選択された曜日を保存
                selectedWorkoutWeekdays = weekdays
                continueFlow()
            }
            .transition(slideTransition)

        case .goalPlanResult:
            UIGoalPlanResultView(
                profileRepo: profileRepo,
                onContinue: continueFlow,
                prefill: GoalPlanResultPrefill(
                    currentWeight: weightKg,
                    goalWeight: goalWeightKg,
                    weeklyRateKg: nil,
                    weeksNeeded: nil,
                    targetDate: nil
                )
            )
            .transition(slideTransition)

        case .aiPlanGeneration:
            OLAIPlanGenerationStepView(
                profileRepo: profileRepo,
                selectedWorkoutWeekdays: selectedWorkoutWeekdays.isEmpty ? [2, 4, 6] : selectedWorkoutWeekdays,
                onContinue: { _ in
                    continueFlow()
                }
            )
            .transition(slideTransition)

        case .done:
            completionView
                .transition(.opacity)
        }
    }

    private var slideTransition: AnyTransition {
        .asymmetric(
            insertion: .move(edge: .trailing).combined(with: .opacity),
            removal: .move(edge: .leading).combined(with: .opacity)
        )
    }

    private var scaleTransition: AnyTransition {
        .asymmetric(
            insertion: .scale(scale: 0.9).combined(with: .opacity),
            removal: .scale(scale: 1.1).combined(with: .opacity)
        )
    }

    /// Navigates back to the previous onboarding step. Runs on the main
    /// actor to ensure UI state updates occur on the correct thread.
    @MainActor
    private func back() {
        gate.navigate {
            let order = Step.allCases
            guard let currentIndex = order.firstIndex(of: step), currentIndex > 0 else { return }
            
            var targetIndex = currentIndex - 1
            var targetStep = order[targetIndex]
            
            // イントロ画面をスキップして、前のパートの最後のデータ入力画面に戻る
            while targetIndex > 0 && (targetStep == .part1Intro || targetStep == .part2Intro || targetStep == .part3Intro) {
                targetIndex -= 1
                targetStep = order[targetIndex]
            }
            
            withAnimation(.easeInOut(duration: 0.3)) {
                step = order[targetIndex]
            }
        }
    }

    /// Prefills the onboarding fields with existing profile values. This
    /// asynchronous method is isolated to the main actor so that it can
    /// safely update `@State` properties without crossing actor boundaries.
    @MainActor
    private func prefillIfNeeded() async {
        do {
            let p = try await profileRepo.getProfile()
            if name.isEmpty, let pName = p.name { name = pName }
            if age == nil { age = p.age }
            if heightCm == nil { heightCm = p.heightCm }
            if weightKg == nil { weightKg = p.weightKg }
            if goalWeightKg == nil { goalWeightKg = p.goal?.goalWeightKg }
            // Load selected weekdays from existing workout schedule if none selected yet.
            if selectedWorkoutWeekdays.isEmpty, let schedule = p.workoutSchedule {
                selectedWorkoutWeekdays = schedule.selectedWeekdays
            }
        } catch {
            #if DEBUG
            print("[OnboardingFlow] prefill failed: \(error)")
            #endif
        }
    }

    private var shouldShowHeader: Bool {
        switch step {
        case .part1Intro, .part2Intro, .part3Intro, .done:
            return false
        default:
            return true
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Button(action: back) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Palette.accent)
            }
            .tint(Palette.accent)
            .opacity(isFirstStep ? 0 : 1)
            .disabled(isFirstStep || gate.isNavigating)
            .accessibilityHidden(isFirstStep)

            HStack(spacing: 2) {
                ForEach(1...3, id: \.self) { partNumber in
                    PartProgressBar(
                        progress: partNumber == currentPart ? progress : (partNumber < currentPart ? 1.0 : 0.0),
                        isActive: partNumber == currentPart,
                        isCompleted: partNumber < currentPart
                    )
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(.systemBackground))
        .opacity(shouldShowHeader ? 1 : 0)
    }

    private var completionView: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(Palette.accent)
                .symbolEffect(.bounce, value: step == .done)

            Text("プロフィール設定が完了しました")
                .font(.title3.weight(.semibold))

            Text("すべての項目はいつでも設定から編集できます")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
}

// MARK: - Preview

#Preview("完全フロー") {
    ImprovedOnboardingFlowView()
        .environmentObject(DataModel())
}
