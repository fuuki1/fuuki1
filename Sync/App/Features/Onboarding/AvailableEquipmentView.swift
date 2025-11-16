import SwiftUI

// MARK: - Brand Tokens
private enum Brand {
    static let accent    = Color(red: 124/255, green: 77/255,  blue: 255/255)
    static let accentLo  = Color(red: 107/255, green: 94/255,  blue: 255/255)
    static let accentHi  = Color(red: 140/255, green: 84/255,  blue: 255/255)
    static let chipFill  = Color(UIColor.systemBackground)
    static let chipStroke = Color(UIColor.separator)
}

private enum Typo {
    static let chip:  Font = .system(size: 18, weight: .semibold, design: .rounded)
    static let title: Font = .system(size: 34, weight: .bold, design: .rounded)
}

/// ✅ Swift 6.2: @Sendableアノテーション必須
public typealias AvailableEquipmentSplitSaveHandler = @MainActor @Sendable (_ categories: Set<String>, _ details: Set<String>) -> Void

// MARK: - Wrapping Flow Layout
struct FlowLayout: Layout {
    var spacing: CGFloat = 12
    var rowSpacing: CGFloat = 14

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        guard let maxWidth = proposal.width, maxWidth > 0 else {
            var totalWidth: CGFloat = 0
            var maxHeight: CGFloat = 0
            for sub in subviews {
                let size = sub.sizeThatFits(.unspecified)
                totalWidth += size.width + spacing
                maxHeight = max(maxHeight, size.height)
            }
            return CGSize(width: totalWidth, height: maxHeight)
        }

        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0

        for sub in subviews {
            let size = sub.sizeThatFits(.unspecified)
            if x + size.width > maxWidth {
                x = 0
                y += rowHeight + rowSpacing
                rowHeight = 0
            }
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
        }
        return CGSize(width: maxWidth, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for sub in subviews {
            let size = sub.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX {
                x = bounds.minX
                y += rowHeight + rowSpacing
                rowHeight = 0
            }
            sub.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(width: size.width, height: size.height))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

// MARK: - Chip
struct SelectableChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(Typo.chip)
                .lineLimit(1)
                .padding(.horizontal, 18)
                .padding(.vertical, 14)
                .background(background)
                .overlay(
                    Capsule()
                        .stroke(isSelected ? Color.white.opacity(0.22) : Brand.chipStroke, lineWidth: 1)
                )
                .foregroundStyle(isSelected ? .white : .primary)
        }
        .buttonStyle(.plain)
        .contentShape(Capsule())
    }

    @ViewBuilder
    private var background: some View {
        if isSelected {
            Capsule(style: .circular)
                .fill(
                    LinearGradient(colors: [Brand.accentLo, Brand.accent, Brand.accentHi],
                                   startPoint: .topLeading, endPoint: .bottomTrailing)
                )
                .shadow(color: Brand.accent.opacity(0.28), radius: 14, x: 0, y: 8)
        } else {
            Capsule(style: .circular)
                .fill(Brand.chipFill)
                .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 6)
        }
    }
}

// MARK: - Suggestion Chips
private struct SuggestionChips: View {
    let items: [String]
    @Binding var selectedDetails: Set<String>

    var body: some View {
        FlowLayout(spacing: 10, rowSpacing: 10) {
            ForEach(items, id: \.self) { item in
                let isSelected = selectedDetails.contains(item)
                SelectableChip(title: item, isSelected: isSelected) {
                    if isSelected { selectedDetails.remove(item) } else { selectedDetails.insert(item) }
                }
            }
        }
    }
}

// MARK: - Category Chips
private struct CategoryChips: View {
    let options: [String]
    @Binding var selected: Set<String>

    var body: some View {
        FlowLayout(spacing: 12, rowSpacing: 14) {
            ForEach(options, id: \.self) { title in
                let isSelected = selected.contains(title)
                SelectableChip(title: title, isSelected: isSelected) {
                    if isSelected { selected.remove(title) } else { selected.insert(title) }
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                }
            }
        }
    }
}

// MARK: - Category Section View
private struct CategorySectionView: View {
    let category: String
    let sections: [SuggestionSection]
    @Binding var selectedDetails: Set<String>

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("\(category) の関連")
                .font(.headline)
                .padding(.horizontal)
            ForEach(sections) { section in
                VStack(alignment: .leading, spacing: 8) {
                    Text(section.title)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)
                    SuggestionChips(items: section.items, selectedDetails: $selectedDetails)
                        .padding(.horizontal)
                }
            }
        }
    }
}

// MARK: - Suggestion Provider
public protocol SuggestionProvider: Sendable {
    func suggest(for categories: Set<String>) async -> [String: [SuggestionSection]]
}

public struct SuggestionSection: Identifiable, Hashable, Sendable {
    public var id: String { title }
    public let title: String
    public let items: [String]
    
    public init(title: String, items: [String]) {
        self.title = title
        self.items = items
    }
}

/// モック実装(あとで本物の生成AIに差し替え)
public struct MockSuggestionProvider: SuggestionProvider {
    public init() {}
    
    public func suggest(for categories: Set<String>) async -> [String: [SuggestionSection]] {
        try? await Task.sleep(nanoseconds: 200 * 1_000_000)
        var result: [String: [SuggestionSection]] = [:]

        func pack(_ tools: [String], _ moves: [String]) -> [SuggestionSection] {
            var sections: [SuggestionSection] = []
            if !tools.isEmpty { sections.append(.init(title: "関連の器具", items: tools)) }
            if !moves.isEmpty { sections.append(.init(title: "関連の種目", items: moves)) }
            return sections
        }

        for cat in categories {
            switch cat {
            case "ジム":
                result[cat] = pack(["ベンチ", "パワーラック", "ダンベル", "バーベル", "ケーブルマシン"],
                                  ["ベンチプレス", "デッドリフト", "スクワット", "ラットプルダウン", "ケーブルフライ"])
            case "筋力トレーニング":
                result[cat] = pack(["ダンベル", "バーベル", "ケトルベル", "ベンチ", "バンド"],
                                  ["スクワット", "デッドリフト", "ベンチプレス", "ショルダープレス", "ローイング"])
            case "自重トレーニング":
                result[cat] = pack(["プルアップバー", "ディップスバー", "ヨガマット"],
                                  ["プッシュアップ", "プルアップ", "ディップス", "スクワット", "プランク"])
            case "有酸素運動":
                result[cat] = pack(["トレッドミル", "エアロバイク", "ローイングエルゴ", "縄跳び"],
                                  ["ジョグ", "バイク", "ロー", "ジャンプロープ", "インターバル走"])
            case "HIIT":
                result[cat] = pack(["タイマー", "バトルロープ", "ボックス", "ケトルベル"],
                                  ["バーピー", "スプリント", "スラスター", "ケトルベルスイング", "マウンテンクライマー"])
            case "ヨガ・ピラティス":
                result[cat] = pack(["ヨガマット", "ブロック", "ストラップ", "ピラティスリング"],
                                  ["ダウンドッグ", "キャットカウ", "ブリッジ", "ロールアップ", "サイドレッグ"])
            case "ストレッチ・柔軟":
                result[cat] = pack(["ストレッチバンド", "フォームローラー"],
                                  ["ハムストリングストレッチ", "ヒップフレクサー", "肩周りストレッチ"])
            case "ウォーキング":
                result[cat] = pack(["ウォーキングシューズ", "心拍センサー"],
                                  ["早歩き", "LISS"])
            default:
                result[cat] = pack([], [])
            }
        }
        return result
    }
}

// MARK: - Screen
public struct AvailableEquipmentView: View {
    private let options: [String] = [
        "筋力トレーニング", "自重トレーニング", "有酸素運動", "HIIT",
        "ヨガ・ピラティス", "ストレッチ・柔軟", "ウォーキング", "特になし", "ジム"
    ]

    @State private var selected: Set<String> = []
    @State private var selectedDetails: Set<String> = []
    @State private var suggestionsByCategory: [String: [SuggestionSection]] = [:]
    @State private var isLoading = false

    private let onSave: (Set<String>) -> Void
    private let provider: SuggestionProvider
    private let onSaveSplit: AvailableEquipmentSplitSaveHandler?

    public init(
        provider: SuggestionProvider = MockSuggestionProvider(),
        onSave: @escaping (Set<String>) -> Void = { _ in },
        onSaveSplit: AvailableEquipmentSplitSaveHandler? = nil
    ) {
        self.provider = provider
        self.onSave = onSave
        self.onSaveSplit = onSaveSplit
    }

    private var sortedSelected: [String] { selected.sorted() }

    private var visibleCategorySections: [(category: String, sections: [SuggestionSection])] {
        sortedSelected.compactMap { cat in
            if let secs = suggestionsByCategory[cat], !secs.isEmpty {
                return (category: cat, sections: secs)
            }
            return nil
        }
    }

    public var body: some View {
        VStack(spacing: 12) {
            Text("プランに取り入れたい\n活動は?")
                .font(Typo.title)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.horizontal)
                .padding(.top, 12)

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    CategoryChips(options: options, selected: $selected)
                        .padding(.horizontal)
                        .padding(.top, 6)

                    if isLoading {
                        ProgressView("AIが関連を提案中…")
                            .padding(.horizontal)
                    }

                    ForEach(visibleCategorySections, id: \.category) { item in
                        CategorySectionView(category: item.category, sections: item.sections, selectedDetails: $selectedDetails)
                    }
                }
                .padding(.bottom, 24)
            }
            
            StartPrimaryButton(title: "次へ") {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                
                var cats: Set<String> = selected
                let dets: Set<String> = selectedDetails
                
                let hasNoEquipment = cats.isEmpty || (cats.count == 1 && cats.contains("特になし"))
                let hasNoDetails = dets.isEmpty
                
                if hasNoEquipment && hasNoDetails {
                    cats.insert("自重トレーニング")
                }
                
                // ✅ 分割保存が提供されている場合（実際のフロー）
                if let onSaveSplit {
                    // 即座にコールバックを呼ぶ（同期的に）
                    onSaveSplit(cats, dets)
                } else {
                    // ✅ フォールバック: プレビュー用
                    let result: Set<String> = cats.union(dets)
                    onSave(result)
                    
                    // バックグラウンドで保存（fire-and-forget）
                    Task.detached { @MainActor in
                        let repo = DefaultSyncingProfileRepository.makePreview()
                        try? await repo.updatePreferredActivities(Array(cats))
                        try? await repo.updateOwnedEquipments(Array(dets))
                        await repo.syncWithRemote()
                    }
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 10)
        }
        .background(Color(UIColor.systemGray6).opacity(0.35))
        .onChange(of: selected) { _, newValue in
            // ✅ Swift 6.2: Task内を@MainActorで明示
            Task { @MainActor in
                await refreshSuggestions(for: newValue)
            }
        }
        .task { @MainActor in
            await refreshSuggestions(for: selected)
        }
    }

    // MARK: - Suggestion fetching
    @MainActor
    private func refreshSuggestions(for categories: Set<String>) async {
        isLoading = true
        let out = await provider.suggest(for: categories)
        var filtered: [String: [SuggestionSection]] = [:]
        for cat in categories { filtered[cat] = out[cat] }
        suggestionsByCategory = filtered
        isLoading = false
    }
}

#Preview("好きな活動(AIサジェスト付き)") {
    AvailableEquipmentView(provider: MockSuggestionProvider()) { selected in
        print("SAVE:", selected)
    }
}
