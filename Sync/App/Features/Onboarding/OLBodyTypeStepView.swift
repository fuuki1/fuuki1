import SwiftUI

// MARK: - Typography
private enum Typography {
    static var header: CGFloat = 30
    static var optionTitle: CGFloat = 18
    static var optionSubtitle: CGFloat = 14
}

// MARK: - Body Type Options (UI層)
enum BodyType: String, CaseIterable, Hashable {
    case lean = "痩せ型"
    case standard = "標準的"
    case muscular = "筋肉質"
    case chubby = "ぽっちゃりしている"

    var subtitle: String {
        switch self {
        case .lean:     return "脂肪や筋肉がつきにくい"
        case .standard: return "平均的な肉付きの体型"
        case .muscular: return "がっちりとした体型"
        case .chubby:   return "脂肪がつきやすい"
        }
    }
    
    // UI → Data層への変換
    var toModel: BodyTypeModel {
        switch self {
        case .lean:     return .lean
        case .standard: return .standard
        case .muscular: return .muscular
        case .chubby:   return .chubby
        }
    }
    
    // Data層 → UIへの変換
    static func from(_ model: BodyTypeModel) -> BodyType {
        switch model {
        case .lean:     return .lean
        case .standard: return .standard
        case .muscular: return .muscular
        case .chubby:   return .chubby
        }
    }
}

// MARK: - Main View
struct OLBodyTypeStepView: View, OnboardingValidatable {
    var gate: FlowGate
    var profileRepo: SyncingProfileRepository = DefaultSyncingProfileRepository.makePreview()
    var onContinue: (BodyType?) -> Void = { _ in }

    @State private var selected: BodyType? = nil
    @State private var displayName: String? = nil

    // OnboardingValidatable準拠
    var isStepValid: Bool { selected != nil }

    private var userNominative: String {
        if let n = displayName, !n.isEmpty { return "\(n)さん" }
        return "あなた"
    }

    public var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 4) {
                Text("\(userNominative)の体型は")
                Text("どれに近いですか?")
            }
            .font(.system(size: Typography.header, weight: .semibold))
            .foregroundStyle(.primary)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 24)
            .padding(.top, 8)
            .padding(.bottom, 60)

            BodyTypeSection(selection: $selected, profileRepo: profileRepo)
                .padding(.top, 0)
                .padding(.bottom, 24)

            Spacer(minLength: 0)

            StartPrimaryButton(title: "次へ") {
                guard !gate.isNavigating, let selected else { return }
                // データ層に保存
                Task {
                    try? await profileRepo.updateBodyType(selected.toModel)
                }
                onContinue(selected)
            }
            .disabled(!isStepValid || gate.isNavigating)
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .animation(.snappy, value: selected)
        .statusBarHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .background(Color.clear)
        .task {
            // リポジトリから既存データを読み込む
            if let profile = try? await profileRepo.getProfile() {
                if let bodyType = profile.bodyType {
                    selected = BodyType.from(bodyType)
                }
                displayName = profile.name
            }
        }
    }
}

// MARK: - Section
private struct BodyTypeSection: View {
    @Binding var selection: BodyType?
    let profileRepo: SyncingProfileRepository
    @State private var effectTriggers: [BodyType: Int] = [:]

    var body: some View {
        VStack(spacing: 16) {
            ForEach(BodyType.allCases, id: \.self) { type in
                OptionRow(
                    option: type,
                    isSelected: selection == type,
                    trigger: effectTriggers[type] ?? 0
                ) {
                    pick(type)
                }
            }
        }
        .padding(.horizontal)
        .animation(.snappy, value: selection)
        .sensoryFeedback(.selection, trigger: selection)
    }

    private func pick(_ type: BodyType) {
        effectTriggers[type, default: 0] += 1
        selection = type
        // 即座にデータ層に保存
        Task {
            try? await profileRepo.updateBodyType(type.toModel)
        }
    }
}

// MARK: - Components
private struct OptionRow: View {
    let option: BodyType
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
    OLBodyTypeStepView(gate: FlowGate())
        .padding(.vertical, 20)
}
