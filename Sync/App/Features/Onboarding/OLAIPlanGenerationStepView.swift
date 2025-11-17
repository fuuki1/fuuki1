import SwiftUI
import Foundation
import GoogleGenerativeAI
import SwiftData

// MARK: - Data Models

struct AIGeneratedPlan: Codable, Sendable {
    let summary: String
    let workoutPlan: WorkoutPlanDetail
    let nutritionPlan: NutritionPlanDetail
    let motivationalMessage: String
}

struct WorkoutPlanDetail: Codable, Sendable {
    let overview: String
    let weeklySchedule: [DaySchedule]
    let tips: [String]
}

struct DaySchedule: Codable, Identifiable, Sendable, Hashable {
    var id: String { day }
    let day: String
    let exercises: [PlanExercise]}

struct PlanExercise: Codable, Identifiable, Sendable, Hashable {
    var id: String { "\(name)-\(sets)-\(reps)-\(duration)" }
    let name: String
    let sets: String
    let reps: String
    let weight: String // 👈 ★変更点1: 追加
    let duration: String
    let notes: String
}

struct NutritionPlanDetail: Codable, Sendable {
    let overview: String
    let dailyCalories: Int
    let macronutrients: Macronutrients
    let mealSuggestions: [MealSuggestion]
    let tips: [String]
}

struct Macronutrients: Codable, Sendable {
    let protein: String
    let carbs: String
    let fats: String
}

struct MealSuggestion: Codable, Identifiable, Sendable {
    var id: String { meal }
    let meal: String
    let suggestion: String
}

// MARK: - APIKey Helper

enum APIKey {
    static func load() throws -> String {
        guard
            let url = Bundle.main.url(forResource: "GenerativeAI-Info", withExtension: "plist"),
            let data = try? Data(contentsOf: url),
            let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
            let key = plist["API_KEY"] as? String,
            !key.isEmpty
        else {
            throw GeminiError.missingAPIKey
        }
        return key
    }
}

// MARK: - Gemini Plan Generator

@MainActor final class GeminiPlanGenerator {
    private let model: GenerativeModel
    private let selectedWorkoutWeekdays: [Int]
    
    init(selectedWorkoutWeekdays: [Int] = [2, 4, 6]) throws {
        let apiKey = try APIKey.load()
        
        self.model = GenerativeModel(
            name: "gemini-2.0-flash-exp",
            apiKey: apiKey
        )
        // 空の場合はデフォルトで月・水・金（2, 4, 6）
        self.selectedWorkoutWeekdays =
            selectedWorkoutWeekdays.isEmpty ? [2, 4, 6] : selectedWorkoutWeekdays
    }
    
    /// ユーザープロファイルから総合プランを生成
    func generateComprehensivePlan(for profile: UserProfile) async throws -> AIGeneratedPlan {
        let prompt = buildPrompt(from: profile)
        let response = try await model.generateContent(prompt)
        
        guard let text = response.text else {
            throw GeminiError.invalidResponse
        }
        
        return try parseResponse(text)
    }
    
    private func buildPrompt(from profile: UserProfile) -> String {
        var prompt = """
        あなたはプロのフィットネスコーチ兼栄養士です。以下のユーザー情報に基づいて、パーソナライズされた総合プランを作成してください。
        
        ## ユーザー情報
        """
        
        if let name = profile.name {
            prompt += "\n- 名前: \(name)"
        }
        if let age = profile.age {
            prompt += "\n- 年齢: \(age)歳"
        }
        if let gender = profile.gender {
            let genderText = gender == .male ? "男性" : gender == .female ? "女性" : "その他"
            prompt += "\n- 性別: \(genderText)"
        }
        if let height = profile.heightCm {
            prompt += "\n- 身長: \(String(format: "%.1f", height))cm"
        }
        if let weight = profile.weightKg {
            prompt += "\n- 現在の体重: \(String(format: "%.1f", weight))kg"
        }
        if let goalWeight = profile.goal?.goalWeightKg {
            prompt += "\n- 目標体重: \(String(format: "%.1f", goalWeight))kg"
        }
        
        // 選択されたプラン詳細を追加
        if let planSelection = profile.goal?.planSelection {
            prompt += "\n\n## 選択されたプラン"
            prompt += "\n- 難易度: \(planSelection.planTitle)"
            prompt += "\n- 週あたりの体重変化: \(String(format: "%.2f", abs(planSelection.weeklyRateKg)))kg (\(planSelection.weeklyRateKg >= 0 ? "増量" : "減量"))"
            prompt += "\n- 目標摂取カロリー: \(Int(planSelection.dailyCalorieIntake))kcal/日"
            prompt += "\n- 目標達成予定: 約\(Int(ceil(planSelection.weeksNeeded)))週間"
        }
        
        if let bodyType = profile.bodyType {
            let bodyText: String
            switch bodyType {
            case .lean: bodyText = "痩せ型"
            case .standard: bodyText = "標準的"
            case .muscular: bodyText = "筋肉質"
            case .chubby: bodyText = "ぽっちゃり"
            }
            prompt += "\n- 体型: \(bodyText)"
        }
        if let activityLevel = profile.activityLevel {
            let activityText: String
            switch activityLevel {
            case .sedentary: activityText = "座りがち(ほとんど運動しない)"
            case .light: activityText = "軽い運動(週1-3回)"
            case .moderate: activityText = "中程度の運動(週3-5回)"
            case .active: activityText = "アクティブ(週6-7回)"
            case .professional: activityText = "プロのアスリート"
            }
            prompt += "\n- 活動レベル: \(activityText)"
        }
        if let goalType = profile.goal?.type {
            let goalText: String
            switch goalType {
            case .loseFat: goalText = "ダイエット(体脂肪を減らす)"
            case .bulkUp: goalText = "筋肉増強"
            case .maintain: goalText = "健康維持"
            }
            prompt += "\n- 目標: \(goalText)"
        }
        if let activities = profile.preferredActivities, !activities.isEmpty {
            prompt += "\n- 好きな活動: \(activities.joined(separator: "、"))"
        }
        if let equipments = profile.ownedEquipments, !equipments.isEmpty {
            prompt += "\n- 所有器具: \(equipments.joined(separator: "、"))"
        } else {
            prompt += "\n- 所有器具: なし(自重トレーニングのみ可能)"
        }
        
        // 選択された曜日を追加（selectedWorkoutWeekdaysを使用）
        let weekdayNames = ["日", "月", "火", "水", "木", "金", "土"]
        let workoutDays = selectedWorkoutWeekdays.compactMap { weekday in
            (weekday >= 1 && weekday <= 7) ? weekdayNames[weekday - 1] : nil
        }
        if !workoutDays.isEmpty {
            prompt += "\n- ワークアウト可能日: \(workoutDays.joined(separator: "、"))曜日"
            prompt += "\n  **重要: この曜日のみでトレーニングスケジュールを構成してください**"
        }
        
        prompt += """
        
        
        ## 出力形式(必ず以下のJSON形式で出力してください)
        
        {
          "summary": "プランの概要(2-3文)",
          "workoutPlan": {
            "overview": "運動プランの説明",
            "weeklySchedule": [
              {
                "day": "月曜日",
                "exercises": [
                  {
                    "name": "エクササイズ名",
                    "sets": "セット数",
                    "reps": "回数",
                    "weight": "重量 (例: '10kg', '自重')", // 👈 ★変更点2: 追加
                    "duration": "時間(分)",
                    "notes": "補足説明"
                  }
                ]
              }
            ],
            "tips": ["アドバイス1", "アドバイス2"]
          },
          "nutritionPlan": {
            "overview": "栄養プランの説明",
            "dailyCalories": ユーザーが選択したプランの目標摂を計算して書いてください,
            "macronutrients": {
              "protein": "タンパク質の目標(g)",
              "carbs": "炭水化物の目標(g)",
              "fats": "脂質の目標(g)"
            },
            "mealSuggestions": [
              {
                "meal": "朝食",
                "suggestion": "具体的な食事例＆カロリー"
              },
              {
                "meal": "昼食",
                "suggestion": "具体的な食事例＆カロリー"
              },
              {
                "meal": "夕食",
                "suggestion": "具体的な食事例＆カロリー"
              }
            ],
            "tips": ["栄養アドバイス1", "栄養アドバイス2"]
          },
          "motivationalMessage": "ユーザーへの励ましのメッセージ"
        }
        
        
        // 👈 ★変更点3: 「注意事項」セクション全体を以下に差し替え
        
        ## 注意事項
        - **プランの基本方針:** ユーザーの目標（`goalType`）、活動レベル（`activityLevel`）、体型（`bodyType`）、年齢（`age`）、性別（`gender`）を総合的に考慮し、安全かつ効果的なプランを作成してください。
        - **カロリー目標の厳守:** `nutritionPlan.dailyCalories` は、ユーザーが選択したプラン（`planSelection`）の `dailyCalorieIntake` の値を**必ずそのまま使用してください**。AIが再計算する必要はありません。
        - **PFCバランス:** `macronutrients` は、指定された `dailyCalories` に基づき、ユーザーの目標（例：ダイエットなら脂質控えめ、筋肉増強ならタンパク質多め）に合わせて計算してください。
        - **スケジュールの厳守:** `weeklySchedule` は、ユーザーが指定した `ワークアウト可能日` の曜日（例：月、水、金）**のみ**で構成してください。それ以外の曜日はスケジュールに含めないでください。
        - **器具の活用:**
            - `所有器具` が「なし」または空の場合は、**必ず自重トレーニングのみ**（プッシュアップ、スクワット、プランク、ランジ、バーピーなど）でメニューを構成してください。
            - `所有器具` がある場合（例：ダンベル、ケトルベル、バンド）、それらを積極的に活用するエクササイズを優先的に組み込んでください。
        
        // --- ここからが詳細化された指示 ---
        
        - **【最重要】エクササイズ詳細（重量・回数）の決定ロジック:**
        - `exercises` 配列内の各項目（`name`, `sets`, `reps`, `weight`, `duration`, `notes`）は、以下のルールに従って詳細かつ具体的に設定してください。
        
        - **ステップ0: ユーザーペルソナの推定**
        - AIはまず、以下の情報を組み合わせてユーザーの「ペルソナ」を深く推定します。
            - **体格 (身長/体重):** 筋力のベースラインは？ (例: 180cm/90kgなら「大柄」、160cm/50kgなら「小柄」)
            - **経験 (好きな活動/活動レベル):** 器具を使った筋トレに慣れているか？ (例: `preferredActivities` が「ウエイトリフティング」なら「経験者」、`preferredActivities` が「ヨガ」なら「筋トレ未経験」)
            - **要求強度 (目標ペース/プラン難易度/目標):** どの程度の強度を求めているか？ (例: `goalType` が「筋肉増強」で `weeklyRateKg` が `+0.5kg` なら「高強度」、`goalType` が「健康維持」で `weeklyRateKg` が `0kg` なら「中強度」)

        - **ステップ1: 重量 (weight) の設定**
        - 上記で推定した「ペルソナ」に基づき、`weight` を決定します。
        - `weight` フィールドは**必須**です。
        - 器具を使用するエクササイズの場合、具体的な重量を `kg` 単位で指定してください (例: `"weight": "10kg"`)。
        - 自重エクササイズ（プッシュアップ、スクワット、プランク等）の場合、必ず `"weight": "自重"` と指定してください。
        - **ペルソナと重量の連動:**
            - (例: ペルソナが「大柄」「筋トレ経験者」「高強度」なら) -> 高重量を設定 (例: `"ダンベルベンチプレス", "weight": "20kg"`)
            - (例: ペルソナが「小柄」「筋トレ未経験」「低強度」でダンベル所有なら) -> 超低重量から設定 (例: `"ダンベルカール", "weight": "2kg"`)
            - (例: ペルソナが「標準体型」「筋トレ未経験」「中強度」で器具なしなら) -> 自重で設定 (例: `"自重スクワット", "weight": "自重"`)

        - **ステップ2: 回数 (reps) と 時間 (duration) の設定**
        - 筋力トレーニング（例：スクワット、ベンチプレス）は `reps`（回数）ベースで設定し、`duration` は `""`（空文字列）にしてください。
        - 有酸素運動や静的トレーニング（例：プランク、ストレッチ、ランニング）は `duration`（時間）ベースで設定し、`reps` は `""`（空文字列）にしてください。
        - `duration` を設定する場合、`"30秒"` や `"10分"` のように単位を必ず含めてください。
        
        - **ステップ3: 重量と回数の連動 (重要)**
        - **筋肉増強（高重量）の場合:** `weight` を重めに設定し、`reps` は低〜中回数（例: `"reps": "6-10回"`）に設定します。（ペルソナの「要求強度」が「高」の場合）
        - **筋持久力・ダイエット（低重量）の場合:** `weight` を軽めに設定し、`reps` は高回数（例: `"reps": "12-15回"`）に設定します。（ペルソナの「要求強度」が「低〜中」の場合）
        
        - **ステップ4: 具体的な指示例 (ペルソナ反映)**
            - *例1（ペルソナ: 180cm/80kg, 筋肉増強, ペース+0.5kg, アクティブ, ダンベル所有）*
              `{ "name": "ダンベルショルダープレス", "sets": "4セット", "reps": "8-10回", "weight": "16kg", "duration": "", "notes": "高重量・高強度で肩を追い込む" }`
            - *例2（ペルソナ: 160cm/60kg, ダイエット, ペース-0.25kg, 座りがち, 器具なし, 筋トレ未経験）*
              `{ "name": "自重スクワット", "sets": "3セット", "reps": "15回", "weight": "自重", "duration": "", "notes": "フォームを最優先。膝がつま先より前に出ないように" }`
            - *例3（ペルソナ: 165cm/55kg, 健康維持, ペース0kg, 好きな活動ヨガ, ダンベル所有）*
              `{ "name": "ダンベルランジ", "sets": "3セット", "reps": "各12回", "weight": "4kg", "duration": "", "notes": "軽めの重量でバランスを取りながら行う" }`
        
        // --- 詳細化ここまで ---

        - 安全性を最優先し、無理のない範囲で設定してください
        - 日本語で出力してください
        - JSON形式以外のテキストは含めないでください(```json などのマークダウンも不要)
        """
        
        return prompt
    }
    
    private func parseResponse(_ response: String) throws -> AIGeneratedPlan {
        // JSONマークダウンを削除
        let cleanedResponse = response
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard let data = cleanedResponse.data(using: .utf8) else {
            throw GeminiError.parsingFailed
        }
        
        let decoder = JSONDecoder()
        return try decoder.decode(AIGeneratedPlan.self, from: data)
    }
}

// MARK: - Error Types

enum GeminiError: LocalizedError {
    case invalidResponse
    case parsingFailed
    case missingAPIKey
    
    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "APIからの応答が無効です"
        case .parsingFailed:
            return "応答の解析に失敗しました"
        case .missingAPIKey:
            return "APIキーが設定されていません"
        }
    }
}

// MARK: - ViewModel (moves heavy logic out of the View)
@MainActor

final class OLAIPlanGenerationViewModel {
    // UI-observed states
    var isGenerating: Bool = false
    var errorMessage: String? = nil
    var showError: Bool = false
    var hasRequestedPlanOnce: Bool = false
    var userGoalTitle: String? = nil
    var lastGeneratedPlan: AIGeneratedPlan? = nil

    enum SaveError: LocalizedError {
        case failedToSave(underlying: Error)
        var errorDescription: String? { "プランの保存に失敗しました。" }
    }

    /// メイン処理：プロフィール取得 → 生成 → 保存（エラーは `showError`/`errorMessage` へ反映）
    func generatePlan(
        profileRepo: SyncingProfileRepository,
        selectedWorkoutWeekdays: [Int],
        modelContext: ModelContext
    ) async {
        isGenerating = true
        errorMessage = nil
        do {
            let profile = try await profileRepo.getProfile()

            // ゴール名をUI表示用に整形
            if let goal = profile.goal, let type = goal.type {
                switch type {
                case .loseFat:    userGoalTitle = "目標: ダイエット"
                case .bulkUp:     userGoalTitle = "目標: 筋肉増強"
                case .maintain:   userGoalTitle = "目標: 健康維持"
                }
            } else {
                userGoalTitle = nil
            }

            // Geminiでプラン生成（指定曜日を尊重）
            let generator = try GeminiPlanGenerator(selectedWorkoutWeekdays: selectedWorkoutWeekdays)
            let plan = try await generator.generateComprehensivePlan(for: profile)

            // SwiftDataへ保存（失敗は throw → catch → showError）
            try savePlanToModels(plan, in: modelContext)

            // 完了
            lastGeneratedPlan = plan
            isGenerating = false
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            showError = true
            isGenerating = false
        }
    }

    /// SwiftData 保存（do-catchで伝播）
    private func savePlanToModels(_ plan: AIGeneratedPlan, in modelContext: ModelContext) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .withoutEscapingSlashes]

        guard let data = try? encoder.encode(plan),
              let json = String(data: data, encoding: .utf8) else {
            throw SaveError.failedToSave(underlying: NSError(domain: "encode", code: -1))
        }

        let record = GeneratedPlanRecord(
            id: UUID(),
            createdAt: Date(),
            summary: plan.summary,
            dailyCalories: plan.nutritionPlan.dailyCalories,
            motivationalMessage: plan.motivationalMessage,
            json: json
        )

        modelContext.insert(record)
        do {
            try modelContext.save()
        } catch {
            throw SaveError.failedToSave(underlying: error)
        }
    }
}

// MARK: - Main View

struct OLAIPlanGenerationStepView: View {
    let profileRepo: SyncingProfileRepository
    let selectedWorkoutWeekdays: [Int] // WorkoutScheduleViewから渡される曜日
    let onContinue: (AIGeneratedPlan) -> Void
    
    @State private var progress: CGFloat = 0.0
    @State private var viewModel = OLAIPlanGenerationViewModel()
    
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.modelContext) private var modelContext
    
    private let brandGradient = LinearGradient(
        colors: [
            Color(red: 95/255, green: 134/255, blue: 1.0),
            Color(red: 124/255, green: 77/255, blue: 1.0)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    var body: some View {
        ZStack {
            Rectangle()
                .fill(.background)
                .ignoresSafeArea()
            
            if viewModel.isGenerating {
                generatingView
            } else {
                errorView
            }
        }
        .alert("エラー", isPresented: $viewModel.showError) {
            Button("再試行") {
                Task { await viewModel.generatePlan(
                    profileRepo: profileRepo,
                    selectedWorkoutWeekdays: selectedWorkoutWeekdays,
                    modelContext: modelContext
                )}
            }
        }
        .onChange(of: viewModel.isGenerating) { oldValue, newValue in
            if newValue {
                progress = 0.0
                Task {
                    for step in 1...12 {
                        try? await Task.sleep(nanoseconds: 250_000_000)
                        await MainActor.run {
                            let target = min(0.07 * CGFloat(step), 0.95)
                            withAnimation(.easeInOut(duration: 0.22)) {
                                progress = target
                            }
                        }
                        if viewModel.isGenerating == false { break }
                    }
                }
            } else {
                withAnimation(.spring(duration: 0.35)) {
                    progress = 1.0
                }
                // 生成結果があれば少し待ってから onContinue
                if let plan = viewModel.lastGeneratedPlan {
                    Task {
                        try? await Task.sleep(nanoseconds: 500_000_000)
                        onContinue(plan)
                    }
                }
            }
        }
        .task {
            guard !viewModel.hasRequestedPlanOnce else { return }
            viewModel.hasRequestedPlanOnce = true
            await viewModel.generatePlan(
                profileRepo: profileRepo,
                selectedWorkoutWeekdays: selectedWorkoutWeekdays,
                modelContext: modelContext
            )
        }
    }
    
    // MARK: - Generating View
    
    private var generatingView: some View {
        ZStack {
            // Background with animated gradient
            Rectangle()
                .fill(.background)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 32) {
                    // Title with fade-in animation
                    VStack(alignment: .leading, spacing: 8) {
                        Text("データ分析中…")
                            .font(.system(size: 28, weight: .bold))
                            .opacity(progress > 0 ? 1 : 0)
                            .animation(.easeOut(duration: 0.6), value: progress)
                        
                        Text(viewModel.userGoalTitle ?? "健康目標を設定")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .opacity(progress > 0.1 ? 1 : 0)
                            .animation(.easeOut(duration: 0.6).delay(0.2), value: progress)
                    }
                    .padding(.horizontal, 28)
                    // Animated Steps
                    VStack(alignment: .leading, spacing: 20) {
                        AnimatedStepRow(
                            icon: "checkmark.circle.fill",
                            text: "個人状況を分析中",
                            isCompleted: true,
                            isActive: progress > 0.2,
                            gradient: brandGradient
                        )
                        
                        AnimatedStepRow(
                            icon: "circle.fill",
                            text: "日常生活を分析中",
                            isCompleted: progress > 0.6,
                            isActive: progress > 0.35,
                            gradient: brandGradient
                        )
                        
                        AnimatedStepRow(
                            icon: "circle.fill",
                            text: "あなたに適したタスクと目標を生成中",
                            isCompleted: progress > 0.9,
                            isActive: progress > 0.55,
                            gradient: brandGradient
                        )
                    }
                    .padding(.horizontal, 28)
                }
                .padding(.top, 12)
                
                Spacer()
                
                // Enhanced circular progress
                VStack(spacing: 16) {
                    ZStack {
                        // Background circle
                        Circle()
                            .stroke(Color.purple.opacity(0.1), lineWidth: 20)
                            .frame(width: 160, height: 160)
                        
                        // Animated progress circle
                        Circle()
                            .trim(from: 0, to: max(0.05, progress))
                            .stroke(
                                brandGradient,
                                style: StrokeStyle(
                                    lineWidth: 20,
                                    lineCap: .round,
                                    lineJoin: .round
                                )
                            )
                            .rotationEffect(.degrees(-90))
                            .frame(width: 160, height: 160)
                        
                        // Percentage text with scale animation
                        VStack(spacing: 4) {
                            Text("\(Int(progress * 100))")
                                .font(.system(size: 48, weight: .bold, design: .rounded))
                                .foregroundStyle(brandGradient)
                                .contentTransition(.numericText())
                            
                            Text("%")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundStyle(.secondary)
                        }
                        .scaleEffect(progress > 0.95 ? 1.1 : 1.0)
                        .animation(.spring(duration: 0.4), value: progress)
                    }
                    .padding(.bottom, 24)
                    
                    // Dynamic status text
                    Text(getStatusText())
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                        .animation(.easeInOut(duration: 0.5), value: progress)
                }
                
                Spacer()
            }
        }
    }
    
    // MARK: - Error View
    
    private var errorView: some View {
        VStack(spacing: 16) {
            Image(systemName: "sparkles")
                .font(.system(size: 40))
                .foregroundStyle(brandGradient)
            Text("AIプランを準備できませんでした")
                .font(.headline)
            Text("ネットワークまたはプロフィール取得で問題が起きています。『再試行』をタップしてください。")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
            Button {
                Task {
                    await viewModel.generatePlan(
                        profileRepo: profileRepo,
                        selectedWorkoutWeekdays: selectedWorkoutWeekdays,
                        modelContext: modelContext
                    )
                }
            } label: {
                Text("再試行")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Supporting Views
    
    struct AnimatedStepRow: View {
        let icon: String
        let text: String
        let isCompleted: Bool
        let isActive: Bool
        let gradient: LinearGradient
        
        var body: some View {
            HStack(spacing: 14) {
                ZStack {
                    if isCompleted {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(gradient)
                            .transition(.scale.combined(with: .opacity))
                    } else if isActive {
                        ZStack {
                            Circle()
                                .stroke(gradient, lineWidth: 2.5)
                                .frame(width: 22, height: 22)

                            Circle()
                                .fill(gradient)
                                .frame(width: 8, height: 8)
                                .scaleEffect(isActive ? 1.0 : 0.5)
                                .animation(
                                    .easeInOut(duration: 1.0)
                                    .repeatForever(autoreverses: true),
                                    value: isActive
                                )
                        }
                        .transition(.scale.combined(with: .opacity))
                    } else {
                        Circle()
                            .stroke(.secondary.opacity(0.3), lineWidth: 2)
                            .frame(width: 22, height: 22)
                    }
                }
                .frame(width: 22, height: 22)
                
                Text(text)
                    .font(.system(size: 17, weight: isActive ? .semibold : .regular))
                    .foregroundStyle(isActive ? .primary : .secondary)
                    .animation(.easeOut(duration: 0.3), value: isActive)
            }
            .opacity(isActive ? 1 : 0.6)
            .scaleEffect(isActive ? 1.0 : 0.98)
            .animation(.spring(duration: 0.5), value: isActive)
        }
    }
    
    // MARK: - Helper Methods
    
    private func getStatusText() -> String {
        switch progress {
        case 0..<0.3:
            return "プロフィールを確認しています..."
        case 0.3..<0.6:
            return "最適な運動プランを計算中..."
        case 0.6..<0.85:
            return "栄養バランスを調整中..."
        case 0.85..<0.95:
            return "最終調整を行っています..."
        default:
            return "もうすぐ完成です!"
        }
    }
    
}

// MARK: - Preview

#Preview("生成中のデモ") {
    // プレビューではメモリオンリーのコンテナを利用するため `makePreview()` を使用します。
    OLAIPlanGenerationStepView(
        profileRepo: DefaultSyncingProfileRepository.makePreview(),
        selectedWorkoutWeekdays: [2, 4, 6], // 月・水・金
        onContinue: { _ in }
    )
    .modelContainer(for: [GeneratedPlanRecord.self], inMemory: true)
}
