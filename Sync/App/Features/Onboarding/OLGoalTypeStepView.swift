import SwiftUI

// MARK: - Goal Options
enum GoalOption: String, CaseIterable, Identifiable, Sendable {
    case loseFat, bulkUp, maintain

    var id: String { rawValue }

    var title: String {
        switch self {
        case .loseFat:  return "ダイエット"
        case .bulkUp:   return "筋肉増強"
        case .maintain: return "健康維持"
        }
    }

    var symbolName: String {
        switch self {
        case .loseFat:  return "flame.fill"
        case .bulkUp:   return "dumbbell.fill"
        case .maintain: return "heart.fill"
        }
        
    }

    var color: Color {
        switch self {
        case .loseFat:  return Color(red: 1.0,   green: 0.498, blue: 0.588)
        case .bulkUp:   return Color(red: 0.478, green: 0.439, blue: 1.0)
        case .maintain: return Color(red: 0.612, green: 0.855, blue: 0.541)
        }
    }

    var goalType: GoalType {
        switch self {
        case .loseFat:  return .loseFat
        case .bulkUp:   return .bulkUp
        case .maintain: return .maintain
        }
    }

    static func from(_ t: GoalType) -> GoalOption {
        switch t {
        case .loseFat:  return .loseFat
        case .bulkUp:   return .bulkUp
        case .maintain: return .maintain
        }
    }
}

// MARK: - View
struct OLGoalTypeStepView: View, OnboardingValidatable {
    var gate: FlowGate
    var onContinue: () -> Void = {}
    var profileRepo: SyncingProfileRepository = DefaultSyncingProfileRepository.makePreview()

    @State private var selected: GoalOption? = nil
    @State private var isSaving = false
    @State private var effectTriggers: [GoalOption: Int] = [:]

    // OnboardingValidatable準拠
    var isStepValid: Bool { selected != nil }

    var body: some View {
        VStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 6) {
                Text("まず目標を選びましょう")
                    .font(.system(size: 28, weight: .bold))
                Text("重要な項目を1つ選んでください")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal)

            VStack(spacing: 12) {
                ForEach(GoalOption.allCases) { option in
                    OptionRow(
                        option: option,
                        isSelected: selected == option,
                        trigger: effectTriggers[option] ?? 0
                    ) {
                        select(option)
                    }
                }
            }
            .padding(.horizontal)

            Spacer(minLength: 0)
        }
        .animation(.snappy, value: selected)
        .sensoryFeedback(.selection, trigger: selected)
        .safeAreaInset(edge: .bottom) {
            StartPrimaryButton(title: "次へ") {
                continueFlow()
            }
            .disabled(!isStepValid || gate.isNavigating)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
    }

    private func select(_ option: GoalOption) {
        effectTriggers[option, default: 0] += 1
        selected = option
        Task {
            await save(option: option)
        }
    }

    private func continueFlow() {
        guard let option = selected, !gate.isNavigating else { return }
        Task {
            await save(option: option)
            await MainActor.run {
                onContinue()
            }
        }
    }

    private func save(option: GoalOption) async {
        guard !isSaving else { return }
        isSaving = true
        defer { isSaving = false }
        do {
            let current = try await profileRepo.getProfile()
            var goal = current.goal ?? GoalProfile()
            goal.type = option.goalType
            try await profileRepo.updateGoal(goal)
        } catch {
            #if DEBUG
            print("[GoalTypeStep] save failed: \(error)")
            #endif
        }
    }
}

// MARK: - Components
private struct OptionRow: View {
    let option: GoalOption
    let isSelected: Bool
    let trigger: Int
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                IconBadge(option: option, color: option.color, isSelected: isSelected, trigger: trigger)
                Text(option.title)
                    .font(.title3.weight(.semibold))
                    .frame(maxWidth: .infinity, alignment: .leading)
                CheckDot(isOn: isSelected, color: option.color)
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, alignment: .leading)
        .syncGlass(cornerRadius: 16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(option.color, lineWidth: 2)
                .opacity(isSelected ? 1 : 0)
        )
    }
}

private struct IconBadge: View {
    let option: GoalOption
    let color: Color
    let isSelected: Bool
    let trigger: Int
    var body: some View {
        ZStack {
            Circle().fill(color.opacity(0.12))
            animatedImage
        }
        .frame(width: 36, height: 36)
    }

    @ViewBuilder
    private var animatedImage: some View {
        let base = Image(systemName: option.symbolName)
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(color)
        switch option {
        case .bulkUp:
            base.symbolEffect(.rotate.byLayer, options: .nonRepeating, value: trigger)
        case .loseFat, .maintain:
            base.symbolEffect(.bounce, value: trigger)
        }
    }
}

private struct CheckDot: View {
    let isOn: Bool
    let color: Color
    var body: some View {
        ZStack {
            Circle().strokeBorder(Color.secondary.opacity(0.16), lineWidth: 1.5)
            Circle().fill(color).scaleEffect(isOn ? 1 : 0)
                .animation(.snappy, value: isOn)
            Image(systemName: "checkmark")
                .font(.caption.bold())
                .foregroundStyle(.white)
                .opacity(isOn ? 1 : 0)
                .animation(.snappy, value: isOn)
        }
        .frame(width: 24, height: 24)
    }
}

#Preview("Goal Type Step") {
    OLGoalTypeStepView(
        gate: FlowGate(),
        profileRepo: DefaultSyncingProfileRepository.makePreview()
    )
    .padding(.vertical)
}
