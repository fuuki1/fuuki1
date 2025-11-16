import SwiftUI
// MARK: - セクション本体（この部分だけ使えばOK）
struct GoalOptionListSection: View {
    @State private var selected: GoalOption? = nil
    @State private var effectTriggers: [GoalOption: Int] = [:]

    var body: some View {
        VStack(spacing: 12) {
            OptionRow(option: .maintain,
                      isSelected: selected == .some(.maintain),
                      trigger: effectTriggers[.maintain] ?? 0) { pick(.maintain) }
        }
        .padding(.horizontal)
        .animation(.snappy, value: selected)
        .sensoryFeedback(.selection, trigger: selected)
    }

    private func pick(_ option: GoalOption) {
        effectTriggers[option, default: 0] += 1
        selected = option
    }
}

// MARK: - コンポーネント
/// 共通カードUIの起点
private struct GlassCard<Content: View>: View {
    var cornerRadius: CGFloat = 16
    var minHeight: CGFloat = 64
    var padding: CGFloat = 18
    @ViewBuilder var content: () -> Content

    var body: some View {
        HStack(spacing: 0) { content() }
            .padding(padding)
            .frame(maxWidth: .infinity, minHeight: minHeight, alignment: .leading)
            .contentShape(Rectangle())
            .glassEffect(in: .rect(cornerRadius: cornerRadius))
    }
}

/// タップ時の微小スケール/減光のみを付与するボタンスタイル
private struct GlassCardButtonStyle: ButtonStyle {
    var pressedScale: CGFloat = 0.985
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? pressedScale : 1)
            .opacity(configuration.isPressed ? 0.98 : 1)
            .animation(.snappy, value: configuration.isPressed)
    }
}

/// カードUI付きのボタン。中身は任意（デフォルト空）。
private struct GlassCardButton<Content: View>: View {
    let action: () -> Void
    var cornerRadius: CGFloat = 16
    var minHeight: CGFloat = 64
    var padding: CGFloat = 18
    @ViewBuilder var content: () -> Content

    init(action: @escaping () -> Void,
         cornerRadius: CGFloat = 16,
         minHeight: CGFloat = 64,
         padding: CGFloat = 18,
         @ViewBuilder content: @escaping () -> Content = { EmptyView() }) {
        self.action = action
        self.cornerRadius = cornerRadius
        self.minHeight = minHeight
        self.padding = padding
        self.content = content
    }

    var body: some View {
        Button(action: action) {
            GlassCard(cornerRadius: cornerRadius, minHeight: minHeight, padding: padding) {
                content()
            }
        }
        .buttonStyle(GlassCardButtonStyle())
    }
}
private struct OptionRow: View {
    let option: GoalOption
    let isSelected: Bool
    let trigger: Int
    let action: () -> Void

    var body: some View {
        GlassCardButton(action: action, minHeight: 64) { }
            .animation(.snappy, value: isSelected)
            .sensoryFeedback(.selection, trigger: trigger)
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
        }
        .frame(width: 36, height: 36)
    }
}
// MARK: - プレビュー
#Preview("Goal Option List Only") {
    VStack {
        GoalOptionListSection()
        Spacer()
    }
    .padding(.vertical)
}
