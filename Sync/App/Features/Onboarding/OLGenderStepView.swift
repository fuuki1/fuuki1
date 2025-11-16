import SwiftUI

// MARK: - Gender Options (UI層)
enum GenderOption: String, CaseIterable, Identifiable {
    case male, female, unspecified
    
    var id: String { rawValue }
    
    var title: String {
        switch self {
        case .male: "男性"
        case .female: "女性"
        case .unspecified: "その他"
        }
    }
    
    var symbol: String {
        switch self {
        case .male:       return "figure.stand"
        case .female:     return "figure.stand.dress"
        case .unspecified:return "ellipsis.circle"
        }
    }
    
    var color: Color {
        switch self {
        case .male:        return Color(red: 0.24, green: 0.51, blue: 1.00)
        case .female:      return Color(red: 1.00, green: 0.50, blue: 0.59)
        case .unspecified: return Color.accentColor
        }
    }
    
    var gradient: LinearGradient {
        switch self {
        case .male, .female:
            return LinearGradient(colors: [color, color],
                                  startPoint: .topLeading, endPoint: .bottomTrailing)
        case .unspecified:
            return LinearGradient(
                gradient: Gradient(stops: [
                    .init(color: Color(red: 107/255, green: 94/255, blue: 255/255), location: 0.0),
                    .init(color: Color(red: 124/255, green: 77/255, blue: 255/255), location: 0.62),
                    .init(color: Color(red: 140/255, green: 84/255, blue: 255/255), location: 0.94)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
    
    // UI → Data層への変換
    var toModel: Gender {
        switch self {
        case .male:        return .male
        case .female:      return .female
        case .unspecified: return .unspecified
        }
    }
    
    // Data層 → UIへの変換
    static func from(_ model: Gender) -> GenderOption {
        switch model {
        case .male:        return .male
        case .female:      return .female
        case .unspecified: return .unspecified
        }
    }
}

// MARK: - Main View
struct OLGenderStepView: View, OnboardingValidatable {
    var gate: FlowGate
    var profileRepo: SyncingProfileRepository = DefaultSyncingProfileRepository.makePreview()
    var onContinue: (GenderOption?) -> Void = { _ in }

    @State private var displayName: String = ""
    @State private var selected: GenderOption?
    @State private var pressTriggers: [GenderOption: Int] = [:]

    // OnboardingValidatable準拠
    var isStepValid: Bool { selected != nil }

    private var userNominative: String {
        let n = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        return n.isEmpty ? "あなた" : "\(n)さん"
    }

    var body: some View {
        VStack(spacing: 16) {
            Text("\(userNominative)の性別は?")
                .font(.title.bold())
                .frame(maxWidth: .infinity, alignment: .center)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            VStack(spacing: 12) {
                ForEach(GenderOption.allCases) { option in
                    OptionRow(
                        option: option,
                        isSelected: selected == option,
                        trigger: pressTriggers[option] ?? 0
                    ) {
                        select(option)
                    }
                }
            }
            .padding(.horizontal)

            Spacer(minLength: 0)
        }
        .animation(.snappy, value: selected)
        .task {
            await loadName()
            // リポジトリから既存データを読み込む
            if let profile = try? await profileRepo.getProfile(),
               let gender = profile.gender {
                selected = GenderOption.from(gender)
            }
        }
        .safeAreaInset(edge: .bottom) {
            StartPrimaryButton(title: "次へ") {
                continueFlow()
            }
            .disabled(!isStepValid || gate.isNavigating)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
    }

    private func loadName() async {
        do {
            let profile = try await profileRepo.getProfile()
            let name = (profile.name ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            if !name.isEmpty { displayName = name }
        } catch {
            // フォールバック: 表示名は "あなた" のまま
        }
    }

    private func select(_ option: GenderOption) {
        pressTriggers[option, default: 0] += 1
        selected = option
        // 即座にデータ層に保存
        Task {
            try? await profileRepo.updateGender(option.toModel)
        }
    }

    private func continueFlow() {
        guard !gate.isNavigating, let selected else { return }
        // データ層に保存
        Task {
            try? await profileRepo.updateGender(selected.toModel)
        }
        onContinue(selected)
    }
}

// MARK: - Row Components

private struct OptionRow: View {
    let option: GenderOption
    let isSelected: Bool
    let trigger: Int
    let action: () -> Void

    @State private var isPressedAnim: Bool = false

    var body: some View {
        CardContainerView {
            Button(action: action, label: {
                HStack(spacing: 12) {
                    IconBadge(symbol: option.symbol, gradient: option.gradient)
                    Text(option.title)
                        .font(.title3.weight(.semibold))
                        .frame(maxWidth: .infinity, alignment: .leading)
                    CheckDot(isOn: isSelected, style: option.gradient)
                }
                .padding(18)
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(height: 84)
                .contentShape(Rectangle())
            })
            .buttonStyle(.plain)
        }
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(option.gradient, lineWidth: 2)
                .opacity(isSelected ? 1 : 0)
                .allowsHitTesting(false)
        )
    }
}

private struct IconBadge: View {
    let symbol: String
    let gradient: LinearGradient
    var body: some View {
        ZStack {
            Circle().fill(gradient).opacity(0.12)
            Image(systemName: symbol)
                .symbolRenderingMode(.hierarchical)
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(gradient)
        }
        .frame(width: 48, height: 48)
    }
}

private struct CheckDot: View {
    let isOn: Bool
    let style: LinearGradient
    var body: some View {
        ZStack {
            Circle().strokeBorder(Color.secondary.opacity(0.16), lineWidth: 1.5)
            Circle().fill(style).scaleEffect(isOn ? 1 : 0)
                .animation(.snappy, value: isOn)
            Image(systemName: "checkmark")
                .font(.caption.bold())
                .foregroundStyle(.white)
                .opacity(isOn ? 1 : 0)
                .animation(.snappy, value: isOn)
        }
        .frame(width: 28, height: 28)
    }
}

private struct CardContainerView<Content: View>: View {
    private let content: () -> Content
    init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }
    var body: some View {
        content()
            .frame(maxWidth: .infinity, alignment: .leading)
            .syncGlass(cornerRadius: 16)
    }
}

#if DEBUG
#Preview("Gender – Rows") {
    OLGenderStepView(gate: FlowGate())
        .padding()
}
#endif
