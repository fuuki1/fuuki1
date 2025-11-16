import SwiftUI

// MARK: - Typography
private enum Typography {
    static var header: CGFloat = 30
    static var optionTitle: CGFloat = 18
    static var optionSubtitle: CGFloat = 14
}

// MARK: - Activity Level Options (UI層)
enum ActivityLevel: String, CaseIterable {
    case sedentary = "座りがち"
    case light = "軽い運動"
    case moderate = "中程度の運動"
    case active = "アクティブ"
    case professional = "プロのアスリート"
    
    var subtitle: String {
        switch self {
        case .sedentary:    return "ほとんど運動しない"
        case .light:        return "週1-3回"
        case .moderate:     return "中程度の強度で週3-5回"
        case .active:       return "週6-7回"
        case .professional: return "平均の人の2倍の運動"
        }
    }
    
    // UI → Data層への変換
    var toModel: ActivityLevelModel {
        switch self {
        case .sedentary:    return .sedentary
        case .light:        return .light
        case .moderate:     return .moderate
        case .active:       return .active
        case .professional: return .professional
        }
    }
    
    // Data層 → UIへの変換
    static func from(_ model: ActivityLevelModel) -> ActivityLevel {
        switch model {
        case .sedentary:    return .sedentary
        case .light:        return .light
        case .moderate:     return .moderate
        case .active:       return .active
        case .professional: return .professional
        }
    }
}

// MARK: - Main View
struct OLActivityLevelStepView: View, OnboardingValidatable {
    var gate: FlowGate
    var profileRepo: SyncingProfileRepository = DefaultSyncingProfileRepository.makePreview()
    var onContinue: (ActivityLevel?) -> Void = { _ in }
    
    @State private var selected: ActivityLevel? = nil
    @State private var displayName: String? = nil
    
    // OnboardingValidatable準拠
    var isStepValid: Bool { selected != nil }

    private var userNominative: String {
        if let n = displayName, !n.isEmpty { return "\(n)さん" }
        return "あなた"
    }
    
    private var headerFirstLine: String { "\(userNominative)の日常活動レベルは" }
    
    public var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 10) {
                Text(headerFirstLine)
                    .font(.system(size: Typography.header, weight: .bold))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .allowsTightening(true)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity, alignment: .center)
                Text("どのくらいですか?")
                    .font(.system(size: Typography.header, weight: .bold))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            .padding(.top, 8)
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
            
            ActivityLevelSection(selection: $selected, profileRepo: profileRepo)
                .padding(.top, 8)
                .padding(.bottom, 24)
            
            Spacer(minLength: 0)
            
            StartPrimaryButton(title: "次へ") {
                guard let selected else { return }
                // データ層に保存
                Task {
                    try? await profileRepo.updateActivityLevel(selected.toModel)
                }
                onContinue(selected)
            }
            .disabled(!isStepValid || gate.isNavigating)
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .animation(.snappy, value: selected)
        .task {
            // リポジトリから既存データを読み込む
            if let profile = try? await profileRepo.getProfile() {
                if let level = profile.activityLevel {
                    selected = ActivityLevel.from(level)
                }
                displayName = profile.name
            }
        }
    }
}

// MARK: - Activity Level Section
private struct ActivityLevelSection: View {
    @Binding var selection: ActivityLevel?
    let profileRepo: SyncingProfileRepository
    @State private var effectTriggers: [ActivityLevel: Int] = [:]

    var body: some View {
        VStack(spacing: 16) {
            ForEach(ActivityLevel.allCases, id: \.self) { level in
                OptionRow(
                    option: level,
                    isSelected: selection == level,
                    trigger: effectTriggers[level] ?? 0
                ) {
                    pick(level)
                }
            }
        }
        .padding(.horizontal)
        .animation(.snappy, value: selection)
        .sensoryFeedback(.selection, trigger: selection)
    }

    private func pick(_ level: ActivityLevel) {
        effectTriggers[level, default: 0] += 1
        selection = level
        // 即座にデータ層に保存
        Task {
            try? await profileRepo.updateActivityLevel(level.toModel)
        }
    }
}

// MARK: - Components
private struct OptionRow: View {
    let option: ActivityLevel
    let isSelected: Bool
    let trigger: Int
    let action: () -> Void
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                VStack(alignment: .center, spacing: 4) {
                    Text(option.rawValue)
                        .font(.system(size: Typography.optionTitle, weight: .semibold))
                        .foregroundStyle(.primary)

                    Text(option.subtitle)
                        .font(.system(size: Typography.optionSubtitle))
                        .foregroundStyle(.secondary)
                }
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, alignment: .center)
            }
            .padding(18)
            .frame(maxWidth: .infinity, minHeight: 80, alignment: .center)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        // ✅ ベース背景(常に表示)
        .background(
            Capsule(style: .circular)
                .fill(Color(.systemBackground))
                .overlay(
                    Capsule(style: .circular)
                        .strokeBorder(.white.opacity(colorScheme == .dark ? 0.28 : 0.18), lineWidth: 1)
                )
        )
        // ✅ 選択時のグラデーション背景(上に重ねる)
        .background(
            Capsule(style: .circular)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 95/255,  green: 134/255, blue: 1.0),
                            Color(red: 124/255, green:  77/255, blue: 1.0)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .opacity(isSelected ? (colorScheme == .dark ? 0.18 : 0.10) : 0)
        )
        // ✅ 選択時のグラデーション枠
        .overlay(
            Capsule(style: .circular)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            Color(red: 95/255,  green: 134/255, blue: 1.0),
                            Color(red: 124/255, green:  77/255, blue: 1.0)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    lineWidth: 2
                )
                .opacity(isSelected ? 1 : 0)
        )
        // ✅ 影を追加(立体感)
        .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 4)
        .animation(.snappy, value: isSelected)
        .sensoryFeedback(.selection, trigger: trigger)
    }
}

#Preview {
    NavigationStack {
        OLActivityLevelStepView(gate: FlowGate())
            .background(.background)
    }
}
