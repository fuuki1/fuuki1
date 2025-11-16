import SwiftUI
import Foundation
import OSLog
import CryptoKit

// MARK: - Public API

public struct BMIContext: Hashable, Sendable {
    public enum Gender: String, Sendable { case male, female, other }
    public var heightCm: Double?
    public var weightKg: Double?
    public var goalWeightKg: Double?
    public var age: Int?
    public var gender: Gender?

    public init(heightCm: Double?, weightKg: Double?, goalWeightKg: Double?, age: Int? = nil, gender: Gender? = nil) {
        self.heightCm = heightCm
        self.weightKg = weightKg
        self.goalWeightKg = goalWeightKg
        self.age = age
        self.gender = gender
    }
}

// MARK: - Liquid Glass Material
private struct LiquidGlassMaterial: View {
    var body: some View {
        ZStack {
            // Base glass layer (no tint)
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.ultraThinMaterial)

            // Subtle highlight gradient for depth (white only, no color)
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            .white.opacity(0.06),
                            .white.opacity(0.02),
                            .clear
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        }
    }
}

// MARK: - Previews

#if DEBUG
struct BMISummaryCard_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            PreviewDeck()
                .previewDisplayName("Light")
                .preferredColorScheme(.light)
            PreviewDeck()
                .previewDisplayName("Dark")
                .preferredColorScheme(.dark)
        }
    }

    private struct PreviewDeck: View {
        var body: some View {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // 低体重(<18.5)
                    BMISummaryCard(
                        kind: .current,
                        context: BMIContext(heightCm: 170, weightKg: 50, goalWeightKg: 60)
                    )
                    // 普通体重(18.5–25)
                    BMISummaryCard(
                        kind: .current,
                        context: BMIContext(heightCm: 170, weightKg: 60, goalWeightKg: 65)
                    )
                    // 肥満(1度)(25–30)
                    BMISummaryCard(
                        kind: .current,
                        context: BMIContext(heightCm: 170, weightKg: 78, goalWeightKg: 68)
                    )
                    // 肥満(2度)以上(>=30)
                    BMISummaryCard(
                        kind: .current,
                        context: BMIContext(heightCm: 170, weightKg: 90, goalWeightKg: 72)
                    )
                    // 目標BMIカードの例
                    BMISummaryCard(
                        kind: .goal,
                        context: BMIContext(heightCm: 170, weightKg: 78, goalWeightKg: 65)
                    )
                }
                .padding()
            }
            .background(Color(uiColor: .systemGroupedBackground))
        }
    }
}
#endif

public protocol BMIExplanationProvider {
    func explanation(for kind: BMISummaryCard.Kind, context: BMIContext, bmi: Double?) async throws -> String
}

public struct BMISummaryCard: View {
    public enum Kind: Sendable { case current, goal }

    private let kind: Kind
    private let context: BMIContext
    private let provider: BMIExplanationProvider
    private let brandColor: Color
    private let maxTextLines: Int

    @State private var text: String = ""
    @State private var isLoading = false
    @State private var showInfo = false
    @AppStorage("ol_height_cm") private var storedHeightCm: Double = 0
    @AppStorage("ol_weight_kg") private var storedWeightKg: Double = 0
    @AppStorage("ol_goal_weight_kg") private var storedGoalWeightKg: Double = 0

    public init(
        kind: Kind,
        context: BMIContext,
        provider: BMIExplanationProvider = RuleBasedBMIExplanationProvider.shared,
        brandColor: Color = Color.purple,
        maxTextLines: Int = 4
    ) {
        self.kind = kind
        self.context = context
        self.provider = provider
        self.brandColor = brandColor
        self.maxTextLines = maxTextLines
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if kind == .goal {
                // === Goal card layout ===
                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 8) {
                        Image("assistant.bot")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 32, height: 32)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            .opacity(0.95)
                            .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)

                        Text(goalTitleText)
                            .font(.system(size: 24, weight: .heavy, design: .rounded))
                            .multilineTextAlignment(.center)                 // 複数行でも中央

                        Spacer()

                        Button(action: { withAnimation(.snappy) { showInfo.toggle() } }) {
                            Image(systemName: "info.circle.fill")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("BMIの説明")
                        .accessibilityHint("タップで説明を表示")
                    }

                    if let pctText = goalPercentText {
                        HStack(spacing: 8) {
                            Image(systemName: goalIcon)
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundStyle(accent)
                            
                            Text(pctText)
                                .font(.system(size: 26, weight: .bold, design: .rounded))
                                .foregroundStyle(accent)
                        }
                        .padding(.vertical, 4)
                    }

                    Text(goalLeadText)
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(.primary)
                        .lineSpacing(4)

                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(goalBullets, id: \.self) { b in
                            HStack(alignment: .top, spacing: 10) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 16))
                                    .foregroundStyle(accent)
                                    .offset(y: 2)
                                
                                Text(b)
                                    .font(.system(size: 16, weight: .regular))
                                    .foregroundStyle(.primary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                    .padding(.top, 4)
                }
            } else {
                // === Current card layout ===
                HStack(spacing: 8) {
                    Text(title)
                        .font(.system(size: 22, weight: .heavy, design: .rounded))
                        .foregroundStyle(.primary)

                    Button(action: { withAnimation(.snappy) { showInfo.toggle() } }) {
                        Image(systemName: "info.circle.fill")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("BMIの説明")
                    .accessibilityHint("タップで説明を表示")
                    Spacer()
                }

                HStack(alignment: .top, spacing: 16) {
                    if let bmi = computedBMI {
                        Text(String(format: "%.1f", bmi))
                            .font(.system(size: 45, weight: .heavy, design: .rounded))
                            .foregroundStyle(accent)
                            .contentTransition(.numericText())
                            .padding(.top, 2)
                    }

                    Text(text.isEmpty ? placeholder : text)
                        .font(.system(size: 16, weight: .regular))
                        .foregroundStyle(.primary)
                        .lineSpacing(4)
                        .multilineTextAlignment(.leading)
                        .lineLimit(maxTextLines)
                        .truncationMode(.tail)
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            ZStack {
                LiquidGlassMaterial()
            }
        }
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            .white.opacity(0.3),
                            .white.opacity(0.1),
                            .clear
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        }
        .overlay(alignment: .top) {
            if showInfo {
                HStack {
                    Spacer(minLength: 0)
                    InfoCallout(text: bmiInfoText)
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 12)
                .offset(y: -100)
                .transition(.move(edge: .top).combined(with: .opacity))
                .zIndex(2)
            }
        }
        .shadow(color: .black.opacity(0.12), radius: 20, x: 0, y: 10)
        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
        .task(id: taskID) { await refresh() }
        .animation(.snappy, value: isLoading)
        .onTapGesture {
            if showInfo { withAnimation(.snappy) { showInfo = false } }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title)。\(text)")
    }
}

// MARK: - Private helpers

private extension BMISummaryCard {
    var title: String { kind == .current ? "現在のBMI" : "目標のBMI" }
    var iconName: String { kind == .current ? "figure.run" : "target" }

    var accent: Color { accentColor(for: computedBMI) }

    func accentColor(for bmi: Double?) -> Color {
        guard let v = bmi else { return Color.gray }
        switch v {
        case ..<18.5: return Color.blue
        case 18.5..<25: return Color.green
        case 25..<30: return Color.orange
        default: return Color.red
        }
    }

    var effectiveCurrentWeight: Double? {
        if let w = context.weightKg, w > 0 { return w }
        return storedWeightKg > 0 ? storedWeightKg : nil
    }

    var goalIcon: String {
        guard let cur = effectiveCurrentWeight, let goal = effectiveTargetWeight else { return "arrow.right.circle.fill" }
        return (goal - cur) >= 0 ? "arrow.up.circle.fill" : "arrow.down.circle.fill"
    }

    var goalPercentText: String? {
        guard kind == .goal, let cur = effectiveCurrentWeight, let goal = effectiveTargetWeight, cur > 0 else { return nil }
        let pct = (goal - cur) / cur * 100
        let dir = (goal - cur) >= 0 ? "増加" : "減少"
        let val = String(format: "%.1f", abs(pct)).replacingOccurrences(of: ".0", with: "")
        return "体重の\(val)%の\(dir)"
    }

    var goalLeadText: String {
        guard kind == .goal, let cur = effectiveCurrentWeight, let goal = effectiveTargetWeight else { return "" }
        let increasing = (goal - cur) >= 0
        return increasing ? "健康に良いより顕著な効果を見ることができます:" : "健康に良い改善が期待できます:"
    }

    var goalBullets: [String] {
        guard kind == .goal, let cur = effectiveCurrentWeight, let goal = effectiveTargetWeight else { return [] }
        let increasing = (goal - cur) >= 0
        return increasing ? ["筋肉の比率を高め、より健康的に見せる", "エネルギーを高める"]
                          : ["体脂肪の割合を下げ、引き締まった印象に", "関節への負担を軽減"]
    }

    var goalTitleText: String {
        guard let b = computedBMI else { return "目標のBMI" }
        switch b {
        case ..<18.5:        return "注意!"
        case 18.5..<18.7:    return "非常に高い目標!"
        case 18.7..<19.8:    return "汗をかく選択!"
        case 19.8..<23.1:    return "妥当な目標です!"
        case 23.1..<24.2:    return "汗をかく選択!"
        case 24.2..<25.0:    return "非常に高い目標!"
        default:             return "注意!"
        }
    }

    var bmiInfoText: String {
        "ボディマス指数(BMI)は、身長と体重に基づいて体脂肪を推測する指標です。BMIは、体重に関する健康問題のリスクについての手がかりを与えてくれます。"
    }

    var targetWeight: Double? {
        kind == .current ? context.weightKg : context.goalWeightKg
    }

    var effectiveHeightCm: Double? {
        if let h = context.heightCm, h > 0 { return h }
        return storedHeightCm > 0 ? storedHeightCm : nil
    }

    var effectiveTargetWeight: Double? {
        switch kind {
        case .current:
            if let w = context.weightKg, w > 0 { return w }
            return storedWeightKg > 0 ? storedWeightKg : nil
        case .goal:
            if let w = context.goalWeightKg, w > 0 { return w }
            return storedGoalWeightKg > 0 ? storedGoalWeightKg : nil
        }
    }

    var computedBMI: Double? {
        guard let h = effectiveHeightCm, let w = effectiveTargetWeight else { return nil }
        let m = h / 100.0
        guard m > 0 else { return nil }
        return w / (m * m)
    }

    var placeholder: String {
        if effectiveHeightCm == nil { return "身長が未設定のため、BMIは後で計算します。" }
        if effectiveTargetWeight == nil { return "体重が未設定のため、BMIは後で計算します。" }
        return "BMIを計算し、あなたの体型に最適なトレーニングを調整します!"
    }

    var taskID: String {
        let base = "\(kind)-\(effectiveHeightCm?.description ?? "_")-\(effectiveTargetWeight?.description ?? "_")"
        let digest = SHA256.hash(data: Data(base.utf8))
        return digest.compactMap { String(format: "%02x", $0) }.joined()
    }

    func classificationJP(for bmi: Double) -> String {
        switch bmi {
        case ..<18.5: return "痩せ型"
        case 18.5..<25: return "普通体重"
        case 25..<30: return "肥満(1度)"
        case 30..<35: return "肥満(2度)"
        case 35..<40: return "肥満(3度)"
        default: return "肥満(4度)"
        }
    }

    @MainActor
    func refresh() async {
        guard effectiveHeightCm != nil, effectiveTargetWeight != nil else {
            isLoading = false
            text = placeholder
            return
        }

        if let cached = ExplanationCache.shared[taskID] {
            text = cached
            return
        }

        isLoading = true
        do {
            let t = try await provider.explanation(for: kind, context: context, bmi: computedBMI)
            ExplanationCache.shared[taskID] = t
            text = t
        } catch {
            os_log(.error, "BMI explanation error: %{public}@", String(describing: error))
            text = fallbackText()
        }
        isLoading = false
    }

    func fallbackText() -> String {
        guard let bmi = computedBMI else { return placeholder }
        if kind == .current {
            return "現在のBMIは\(String(format: "%.1f", bmi))\nフォーム重視の全身トレと、週2–3回の有酸素で基礎代謝を底上げしましょう。"
        } else {
            return "目標BMIは\(String(format: "%.1f", bmi))を想定。\n筋力維持のためタンパク質を確保しつつ、週あたり0.5kg以内の緩やかな変化を目指します。"
        }
    }
}

// MARK: - Info Callout with Liquid Glass

private struct InfoCallout: View {
    let text: String
    var body: some View {
        VStack(spacing: 0) {
            Text(text)
                .font(.system(size: 15))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.leading)
                .lineSpacing(3)
                .padding(16)
                .background {
                    ZStack {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(.regularMaterial)
                        
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(.black.opacity(0.2))
                    }
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    .white.opacity(0.4),
                                    .white.opacity(0.1)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                }
            
            CalloutTail()
                .fill(.regularMaterial)
                .frame(width: 18, height: 9)
                .overlay {
                    CalloutTail()
                        .fill(.black.opacity(0.2))
                }
                .offset(y: -1)
        }
        .shadow(color: .black.opacity(0.2), radius: 15, x: 0, y: 5)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(text)
    }
}

private struct CalloutTail: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        p.closeSubpath()
        return p
    }
}

@MainActor
private final class ExplanationCache {
    static let shared = ExplanationCache()
    private var store: [String: String] = [:]
    subscript(key: String) -> String? {
        get { store[key] }
        set { store[key] = newValue }
    }
}

// MARK: - Default rule-based provider

public final class RuleBasedBMIExplanationProvider: BMIExplanationProvider {
    public static let shared = RuleBasedBMIExplanationProvider()
    private init() {}

    public func explanation(for kind: BMISummaryCard.Kind, context: BMIContext, bmi: Double?) async throws -> String {
        guard let bmi else {
            if context.heightCm == nil { return "身長が未設定のため、BMIは後で計算します。" }
            return "体重が未設定のため、BMIは後で計算します。"
        }

        func cls(_ v: Double) -> String {
            switch v {
            case ..<18.5: return "低体重"
            case 18.5..<25: return "普通体重"
            case 25..<30: return "肥満(1度)"
            case 30..<35: return "肥満(2度)"
            case 35..<40: return "肥満(3度)"
            default: return "肥満(4度)"
            }
        }

        func shortComment(_ v: Double) -> String {
            switch v {
            case ..<18.5:
                return "しっかり食べて、理想の体型を目指そう!"
            case 18.5..<25:
                return "素晴らしい!その調子で今のスタイルをキープ!"
            case 25..<30:
                return "ここが頑張りどこ!軽い運動から始めてみない?"
            case 30..<35:
                return "焦らず自分のペースでOK!小さな一歩が未来を変える!"
            case 35..<40:
                return "一人じゃない!私が全力でサポートするよ!"
            default:
                return "大丈夫、ここから始めよう。私が全力でパートナーがついてる!"
            }
        }

        func shortGoalComment(_ v: Double) -> String {
            switch v {
            case ..<18.5:
                return "注意!健康警告:低体重リスク。無理な減量は避けよう。"
            case 18.5..<18.7:
                return "非常に高い目標!!(減少)15%超の体重減少。専門家のサポート推奨。"
            case 18.7..<19.8:
                return "汗をかく選択!!(減少)約10–15%の体重減少。十分な栄養と休養を。"
            case 19.8..<22.0:
                return "妥当な目標です!!(減少)0–10%の体重減少。生活習慣の微調整でOK。"
            case 22.0..<23.1:
                return "妥当な目標です!!(増加)0–5%の体重増加。筋力アップに最適。"
            case 23.1..<24.2:
                return "汗をかく選択!!(増加)約5–10%の体重増加。段階的に。"
            case 24.2..<25.0:
                return "非常に高い目標!!(増加)約10–15%の体重増加。計画的に進もう。"
            default:
                return "注意!健康警告:肥満リスク。目標体重を安全圏に設定し直そう。"
            }
        }

        switch kind {
        case .current:
            return "\(shortComment(bmi))"
        case .goal:
            return "目標BMIは\(String(format: "%.1f", bmi))\n\(shortGoalComment(bmi))"
        }
    }
}

// MARK: - Optional: OpenAI/LLM provider

public final class OpenAIExplanationProvider: BMIExplanationProvider {
    public typealias Caller = (_ path: String, _ body: Data) async throws -> Data

    private let call: Caller
    private let endpointPath: String

    public init(endpointPath: String = "/v1/explanations/bmi", call: @escaping Caller) {
        self.endpointPath = endpointPath
        self.call = call
    }

    public func explanation(for kind: BMISummaryCard.Kind, context: BMIContext, bmi: Double?) async throws -> String {
        struct Req: Encodable {
            let kind: String
            let heightCm: Double
            let weightKg: Double
            let goalWeightKg: Double?
            let bmi: Double
            let systemPrompt: String
        }
        guard let h = context.heightCm, let w = (kind == .current ? context.weightKg : context.goalWeightKg), let b = bmi else {
            return "入力が不足しているため、後で計算します。"
        }

        let system = """
        あなたはスポーツ栄養士兼パーソナルトレーナー。70〜100字、日本語、敬体、専門用語は簡潔。
        推奨は安全第一(週の体重変化は±0.5kg以内、無理な減量・過度な運動は避ける)。
        """

        let req = Req(kind: kind == .current ? "current" : "goal",
                      heightCm: h, weightKg: w,
                      goalWeightKg: context.goalWeightKg,
                      bmi: b,
                      systemPrompt: system)

        let encoder = JSONEncoder()
        let data = try encoder.encode(req)
        let resData = try await call(endpointPath, data)
        struct Res: Decodable { let text: String }
        let res = try JSONDecoder().decode(Res.self, from: resData)
        return res.text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
