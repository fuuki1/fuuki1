import SwiftUI
import SwiftData

struct WorkoutRecordView: View {
    @Binding var navigationPath: NavigationPath
    @State private var searchText: String = ""
    @State private var selectedCategory: String = "すべて"
    @State private var isShowingCalendar: Bool = false
    @State private var currentDate: Date = Date()
    @State private var isPresentingCustom: Bool = false
    @State private var isSearchExpanded: Bool = false
    @State private var workoutItems: [WorkoutItem] = []
    @State private var favoriteNames: Set<String> = []

    // 🔽 SwiftDataから履歴(過去のセッション)とカスタムワークアウトを取得
    @Query(sort: \WorkoutSessionEntity.sessionDate, order: .reverse) private var workoutSessions: [WorkoutSessionEntity]
    @Query(sort: \CustomWorkoutEntity.createdAt, order: .reverse) private var customWorkoutEntities: [CustomWorkoutEntity]

    // 新しいカテゴリーリスト
    let categories = ["すべて", "履歴", "カスタム", "お気に入り", "胸", "肩", "背中", "腕", "脚", "腹筋", "お尻", "有酸素", "スポーツ"]
    
    // フィルタリングされたワークアウトリスト
    var workouts: [WorkoutItem] {
        // 入力キーワードで共通の検索フィルタリングを定義
        let keyword = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let matchesSearch: (WorkoutItem) -> Bool = { workout in
            if keyword.isEmpty { return true }
            // 名前またはタグにキーワードを含むかで判定
            return workout.name.localizedCaseInsensitiveContains(keyword) ||
                workout.tags.contains(where: { $0.localizedCaseInsensitiveContains(keyword) })
        }

        // カテゴリ別のリストを生成
        switch selectedCategory {
        case "履歴":
            let historyItems = historyWorkouts()
            return historyItems.filter(matchesSearch)
        case "カスタム":
            // ユーザーが作成したCustomWorkoutEntityをWorkoutItemに変換
            let customItems = customWorkoutEntities.map { customToItem($0) }
            return customItems.filter(matchesSearch)
        case "すべて":
            // すべて: メインデータセット + カスタムをまとめて表示
            let customItems = customWorkoutEntities.map { customToItem($0) }
            let baseItems = workoutItems + customItems

            // 種目名ごとに重複をまとめ、1つだけ使用
            let uniqueItemsByName: [WorkoutItem] = Dictionary(grouping: baseItems, by: { $0.name })
                .compactMap { $0.value.first }

            return uniqueItemsByName.filter(matchesSearch)
        case "お気に入り":
            // すべての種目(プリセット+カスタム+履歴)からお気に入りだけを表示
            let historyItems = historyWorkouts()
            let customItems = customWorkoutEntities.map { customToItem($0) }
            let baseItems = workoutItems + customItems + historyItems

            // 種目名ごとに重複をまとめ、1つだけ使用
            let uniqueItemsByName: [WorkoutItem] = Dictionary(grouping: baseItems, by: { $0.name })
                .compactMap { $0.value.first }

            return uniqueItemsByName.filter { item in
                matchesSearch(item) && favoriteNames.contains(item.name)
            }
        default:
            // その他の部位カテゴリの場合
            return workoutItems.filter { item in
                matchesSearch(item) && item.bodyPart == selectedCategory
            }
        }
    }

    /// 過去セッションから履歴用の WorkoutItem 配列を生成
    private func historyWorkouts() -> [WorkoutItem] {
        // 過去のセッションから、登場したエクササイズ名をユニークに抽出
        let allNames: [String] = workoutSessions
            .flatMap { $0.exercises }
            .map { $0.exerciseName }

        let uniqueNames = Array(Set(allNames)).sorted()

        let weight = currentUserWeightKg()

        // ユニークなエクササイズごとにMETとカロリーを計算してWorkoutItemに変換
        let historyItems: [WorkoutItem] = uniqueNames.map { name in
            // 種目名からMETを取得（レップベースの筋トレとして扱う）
            let met = METValueProvider.shared.metValue(for: name, isDurationBased: false)

            // 10回を行ったと仮定したときのカロリーを計算（1レップ ≒ 3秒）
            let totalSecondsForTenReps = 3.0 * 10.0
            let calories = (met * weight / 3600.0) * totalSecondsForTenReps

            let bodyPart = BodyPartKeywords.determineBodyPart(for: [name], mets: met)

            return WorkoutItem(
                name: name,
                calories: calories,
                displayUnit: "10回",
                mets: met,
                tags: [name],
                bodyPart: bodyPart
            )
        }
        return historyItems
    }
    
    /// UserDefaults からお気に入りの種目名セットを読み込む
    private func loadFavoritesFromDefaults() {
        let names = UserDefaults.standard.stringArray(forKey: "favoriteExerciseNames") ?? []
        favoriteNames = Set(names)
    }
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [Color(hex: "F3E8FF"), Color(hex: "F8F5FF"), Color.white],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // ヘッダー部分
                headerView
                    .navigationBarBackButtonHidden(true)
                
                // 検索バー展開時
                if isSearchExpanded {
                    liquidGlassSearchBar
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
                
                HStack(spacing: 0) {
                    // Category sidebar
                    categorySidebar
                    
                    // Workout list
                    workoutList
                        .padding()
                        .glassEffect(in: .rect(cornerRadius: 16.0))
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                }
                
            }
            
        }
        .task {
            // ビュー表示時にワークアウトデータをロード
            await loadWorkouts()
        }
        .onAppear {
            loadFavoritesFromDefaults()
        }
        .sheet(isPresented: $isShowingCalendar) {
            CalendarSheetView(selectedDate: $currentDate)
                .presentationDetents([.fraction(0.75), .large])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(22)
        }
        .sheet(isPresented: $isPresentingCustom) {
            CustomWorkoutCreateView()
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(22)
        }
        .onChange(of: currentDate) { _, _ in
            isShowingCalendar = false
        }
    }
    
    private var headerView: some View {
        ZStack {
            // 左: 戻るボタン
            HStack {
                if !isSearchExpanded {
                    Button {
                        if !navigationPath.isEmpty {
                            navigationPath.removeLast()
                        }
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundStyle(Color(hex: "1F2340"))
                        
                    }
                    .buttonStyle(.glass)
                    .tint(Color(hex: "1F2340"))
                    .accessibilityLabel("戻る")
                    .transition(.opacity.combined(with: .scale))
                }
                Spacer()
            }
            
            // 中央: 日付選択ボタン
            if !isSearchExpanded {
                Button {
                    isShowingCalendar = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "calendar")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Color(hex: "1F2340"))
                        Text(dateTitle)
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(Color(hex: "1F2340"))
                        Image(systemName: "chevron.down")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Color(hex: "B6BBC6"))
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .transition(.opacity.combined(with: .scale))
            }

            // 右: 検索 + カスタム
            HStack(spacing: 16) {
                Spacer()

                // 検索ボタン
                if !isSearchExpanded {
                    Button {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                            isSearchExpanded = true
                        }
                    } label: {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 17, weight: .semibold))
                            .frame(width: 10, height: 20)
                            .contentShape(Circle())
                        
                    }
                    .buttonStyle(.glass)
                    .tint(Color(hex: "1F2340"))
                    .transition(.opacity.combined(with: .scale))
                }

                // カスタムボタン
                if !isSearchExpanded {
                    Button {
                        isPresentingCustom = true
                    } label: {
                        Text("カスタム")
                            .font(.system(size: 17))
                            .foregroundStyle(Color(hex: "7C4DFF"))
                    }
                    .buttonStyle(.plain)
                    .transition(.opacity.combined(with: .move(edge: .trailing)))
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }
    
    private var liquidGlassSearchBar: some View {
        HStack(spacing: 12) {
            // 検索アイコン
            Image(systemName: "magnifyingglass")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Color(hex: "1F2340"))
            
            // 検索フィールド
            TextField("運動名やタグで検索", text: $searchText)
                .font(.system(size: 16))
                .foregroundStyle(Color(hex: "1F2340"))
                .autocorrectionDisabled()
                .textFieldStyle(.plain)
            
            // クリアボタン
            if !searchText.isEmpty {
                Button {
                    withAnimation(.easeOut(duration: 0.2)) {
                        searchText = ""
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(.secondary.opacity(0.6))
                }
                .buttonStyle(.plain)
                .transition(.opacity.combined(with: .scale))
            }
            
            // キャンセルボタン
            Button {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                    searchText = ""
                    isSearchExpanded = false
                }
            } label: {
                Text("キャンセル")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Color(hex: "7C4DFF"))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background {
            ZStack {
                // Liquid Glass背景
                RoundedRectangle(cornerRadius: 14)
                    .fill(.ultraThinMaterial)
                
                // 内側のグロー効果
                RoundedRectangle(cornerRadius: 14)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.7),
                                Color.white.opacity(0.3)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .blur(radius: 0.5)
                
                // 境界線
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.8),
                                Color.white.opacity(0.2)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            }
            .shadow(color: Color.black.opacity(0.06), radius: 12, x: 0, y: 4)
            .shadow(color: Color.black.opacity(0.04), radius: 4, x: 0, y: 2)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 12)
    }
    
    private var dateTitle: String {
        let now = currentDate
        let cal = Calendar(identifier: .gregorian)
        let df = DateFormatter()
        df.locale = Locale(identifier: "ja_JP")
        df.calendar = cal
        df.dateFormat = "M/d(EEE)"
        let base = df.string(from: now)
        return cal.isDateInToday(now) ? "今日" : base
    }

    private var categorySidebar: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                ForEach(categories, id: \.self) { category in
                    Text(category)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(selectedCategory == category ? Color(hex: "7C4DFF") : Color(hex: "666666"))
                        .lineLimit(1)
                        .frame(width: 58, alignment: .leading)
                        .onTapGesture {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                selectedCategory = category
                            }
                        }
                }
                Spacer()
            }
            .padding(.leading, 16)
            .padding(.trailing, 12)
            .padding(.top, 24)
        }
        .frame(width: 90)
        .fixedSize(horizontal: true, vertical: false)
    }

    private var workoutList: some View {
        ScrollView {
            VStack(spacing: 0) {
                if !workouts.isEmpty {
                    ForEach(workouts) { workout in
                        VStack(spacing: 0) {
                            WorkoutRow(
                                workout: workout,
                                currentDate: currentDate
                            )
                            .padding(.vertical, 10)
                            Divider()
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .overlay {
            if workouts.isEmpty {
                Text("該当する運動が見つかりません")
                    .foregroundColor(.gray)
            }
        }
    }
    
    // MARK: - Data Loading
    
    // METValueProviderから非同期でワークアウトデータをロード
    private func loadWorkouts() async {
        // METValueProviderの全エントリを取得
        let metEntries = await METValueProvider.shared.getAllEntries()
        
        // PaceProvider は @MainActor クラスなのでメインスレッドで初期化
        let paceProvider = await MainActor.run {
            PaceProvider()
        }
        
        var items: [WorkoutItem] = []
        let weight = currentUserWeightKg()
        
        for entry in metEntries {
            guard let displayName = entry.keys.first else { continue }
            
            let bodyPart = BodyPartKeywords.determineBodyPart(for: entry.keys, mets: entry.mets)
            
            let calories: Double
            let displayUnit: String
            
            if bodyPart == "有酸素" || bodyPart == "スポーツ" {
                // 有酸素・スポーツ: 10分あたりのカロリー
                calories = entry.mets * weight * 0.167
                displayUnit = "10分"
            } else {
                // 筋トレ系: 10回あたりのカロリー
                let profile = await MainActor.run {
                    paceProvider.pace(for: displayName)
                }
                let secondsPerRep = profile.secondsPerRep
                let totalSecondsForTenReps = secondsPerRep * 10.0
                calories = (entry.mets * weight / 3600.0) * totalSecondsForTenReps
                displayUnit = "10回"
            }
            
            let workoutItem = WorkoutItem(
                name: displayName,
                calories: calories,
                displayUnit: displayUnit,
                mets: entry.mets,
                tags: entry.keys,
                bodyPart: bodyPart
            )
            
            items.append(workoutItem)
        }
        
        // メインスレッドでUI更新
        await MainActor.run {
            workoutItems = items.sorted { $0.name < $1.name }
        }
    }

    // ユーザーの体重(kg)を取得
    private func currentUserWeightKg() -> Double {
        let candidateKeys = [
            "userWeightKg",
            "OLWeightStepView.userWeightKg",
            "OLWeightStepView.weight"
        ]
        for key in candidateKeys {
            let v = UserDefaults.standard.double(forKey: key)
            if v > 0 { return v }
        }
        // デフォルト体重(未設定の場合)
        return 70
    }

    // MARK: - Data Conversion Helpers

    /// CustomWorkoutEntity から表示用の WorkoutItem へ変換
    /// 保存済みの durationMin と calories を元に、METs を「逆算」して一覧表示用の値を作る。
    ///
    /// `CustomWorkoutEntity` には `bodyPart` と `tags` のプロパティがあるため、
    /// それらをそのまま `WorkoutItem` に反映する。`durationMin` と `caloriesKcal` は
    /// ユーザー入力に基づいた値であり、その単位やカロリー表示を維持するために
    /// `displayUnit` は「◯分」とする。
    private func customToItem(_ custom: CustomWorkoutEntity) -> WorkoutItem {
        let weight = currentUserWeightKg()

        // 保存されている値をDoubleに変換
        let durationMinutes = custom.durationMin
        let calories = Double(custom.caloriesKcal)

        // 分 → 時間（0除算を避けるため、極端に小さい値は下限を持たせる）
        let hours = max(durationMinutes / 60.0, 0.0001)

        // MET ≒ 消費カロリー / (体重(kg) × 時間(h))
        let mets: Double
        if weight > 0 && calories > 0 {
            mets = calories / (weight * hours)
        } else {
            mets = 0
        }

        // 表示用の単位は「◯分」とする
        let displayUnit = String(format: "%.0f分", durationMinutes)

        return WorkoutItem(
            name: custom.name,
            calories: calories,
            displayUnit: displayUnit,
            mets: mets,
            tags: custom.tags,
            bodyPart: custom.bodyPart
        )
    }
}

struct WorkoutRecordView_Previews: PreviewProvider {
    static var previews: some View {
        PreviewRecordHost()
    }
}

private struct PreviewRecordHost: View {
    @State private var path = NavigationPath()
    var body: some View {
        NavigationStack(path: $path) {
            WorkoutRecordView(navigationPath: $path)
        }
    }
}
