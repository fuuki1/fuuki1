import SwiftUI
import SwiftData
import ConfettiSwiftUI

struct PlanCompletionView: View {
    let day: DaySchedule
    let elapsedSeconds: Int
    let isFullCompletion: Bool
    let completedExerciseIndices: [Int]
    /// セッション中に記録された各セットのログ。
    let setLogs: [SetLog]
    @Binding var navigationPath: NavigationPath
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    // Feedback
    @State private var selectedFeedback: String? = nil
    
    // Animation states
    @State private var showContent = false
    @State private var animatedExercises = 0
    @State private var animatedCalories = 0
    @State private var animatedMinutes = 0
    @State private var animatedSeconds = 0
    @State private var celebrationScale: CGFloat = 0.8
    @State private var confettiTrigger: Int = 0
    @AppStorage("userWeightKg") private var appWeightA: Double = 0
    @AppStorage("weightKg") private var appWeightB: Double = 0

    /// イニシャライザ。setLogs にはデフォルト値として空配列を与える。
    init(
        day: DaySchedule,
        elapsedSeconds: Int,
        isFullCompletion: Bool,
        completedExerciseIndices: [Int],
        setLogs: [SetLog] = [],
        navigationPath: Binding<NavigationPath>
    ) {
        self.day = day
        self.elapsedSeconds = elapsedSeconds
        self.isFullCompletion = isFullCompletion
        self.completedExerciseIndices = completedExerciseIndices
        self.setLogs = setLogs
        self._navigationPath = navigationPath
    }
    
    private let brandColor = Color(red: 124/255, green: 77/255, blue: 1.0)

    private struct FeedbackOption: Identifiable, Hashable {
        let id: String
        let label: String
        let emoji: String
        let gradient: [Color]
        var title: String { label.replacingOccurrences(of: "\n", with: " ") }
    }

    private let feedbackOptions: [FeedbackOption] = [
        .init(id: "very_hard", label: "とても\n難しい", emoji: "😰", gradient: [Color.red, Color.orange]),
        .init(id: "hard", label: "難しい", emoji: "😖", gradient: [Color.orange, Color.yellow]),
        .init(id: "medium", label: "ちょうど\nいい", emoji: "😀", gradient: [Color.green, Color.mint]),
        .init(id: "easy", label: "簡単", emoji: "☺️", gradient: [Color.cyan, Color.blue]),
        .init(id: "very_easy", label: "とても\n簡単", emoji: "😆", gradient: [Color.blue, Color.purple])
    ]

    var body: some View {
        ZStack {
            VStack(spacing: 8) {
                // Title with animation
                VStack(spacing: 12) {
                    Text(isFullCompletion ? "本日のワークアウトが\n完了しました!" : "本日のワークアウトを\n記録しました")
                        .font(.largeTitle.weight(.bold))
                        .fontDesign(.rounded)
                        .multilineTextAlignment(.center)
                        .opacity(showContent ? 1 : 0)
                        .offset(y: showContent ? 0 : -20)
                }
                .padding(.horizontal, 24)
                .padding(.top, 40)
                
                Text(dayCountText)
                    .font(.title2.weight(.bold))
                    .fontDesign(.rounded)
                    .foregroundStyle(.secondary)
                    .padding(.top, 8)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .opacity(showContent ? 1 : 0)
                    .offset(y: showContent ? 0 : -10)
                
                // Stats card with staggered animation
                HStack(spacing: 0) {
                    // Exercises
                    VStack(spacing: 12) {
                        Text("エクササイズ")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("\(animatedExercises)")
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .contentTransition(.numericText())
                    }
                    .frame(maxWidth: .infinity)
                    .opacity(showContent ? 1 : 0)
                    .offset(y: showContent ? 0 : 30)

                    Divider()
                        .frame(height: 50)
                        .opacity(showContent ? 0.3 : 0)

                    // Calories
                    VStack(spacing: 12) {
                        Text("カロリー")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text("\(animatedCalories)")
                                .font(.system(size: 32, weight: .bold, design: .rounded))
                                .monospacedDigit()
                                .foregroundStyle(.primary)
                                .contentTransition(.numericText())
                            Text("kcal")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .opacity(showContent ? 1 : 0)
                    .offset(y: showContent ? 0 : 30)

                    Divider()
                        .frame(height: 50)
                        .opacity(showContent ? 0.3 : 0)

                    // Duration
                    VStack(spacing: 12) {
                        Text("時間")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        HStack(alignment: .firstTextBaseline, spacing: 1) {
                            Text("\(animatedMinutes)")
                                .font(.system(size: 32, weight: .bold, design: .rounded))
                                .monospacedDigit()
                                .contentTransition(.numericText())
                            Text("分")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .offset(y: -1)
                            Text(String(format: "%02d", animatedSeconds))
                                .font(.system(size: 32, weight: .bold, design: .rounded))
                                .monospacedDigit()
                                .contentTransition(.numericText())
                            Text("秒")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .offset(y: -1)
                        }
                        .offset(x: 8)
                        .fixedSize(horizontal: true, vertical: false)
                    }
                    .frame(maxWidth: .infinity)
                    .opacity(showContent ? 1 : 0)
                    .offset(y: showContent ? 0 : 30)
                }
                .offset(y: -12)
                .padding(.top, 24)
                .padding(.horizontal, 24)
                .padding(.vertical, 24)
                .frame(maxWidth: 370)
                .glassEffect(in: .rect(cornerRadius: 20.0))
                .shadow(color: .black.opacity(0.05), radius: 20, y: 10)
                .scaleEffect(showContent ? 1 : 0.9)
                
                // Feedback Section
                VStack(alignment: .leading, spacing: 16) {
                    Text("今日の運動はどうでしたか?")
                        .font(.headline)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .opacity(showContent ? 1 : 0)
                        .offset(y: showContent ? 0 : 20)

                    Grid(alignment: .top, horizontalSpacing: 12, verticalSpacing: 8) {
                        // Row 1: Emojis
                        GridRow {
                            ForEach(Array(feedbackOptions.enumerated()), id: \.element.id) { index, option in
                                feedbackEmojiButton(for: option, index: index)
                            }
                        }

                        // Row 2: Labels
                        GridRow {
                            ForEach(Array(feedbackOptions.enumerated()), id: \.element.id) { index, option in
                                feedbackLabelButton(for: option, index: index)
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                }
                .padding(.top, 24)
            }
            .frame(maxWidth: .infinity, alignment: .top)
            .padding(.top, -280)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.background)
        .ignoresSafeArea()
        .navigationBarBackButtonHidden(true)
        .overlay(alignment: .bottom) {
            Color.clear
                .frame(height: 1)
                .offset(y: -10)
                .confettiCannon(
                    trigger: $confettiTrigger,
                    num: 150,
                    openingAngle: Angle(degrees: 60),
                    closingAngle: Angle(degrees: 120),
                    radius: 800,
                    repetitions: 1,
                    repetitionInterval: 0.7
                )
        }
        .safeAreaInset(edge: .bottom) {
            StartPrimaryButton(title: "お疲れ様でした!") {
                saveWorkoutSession()
                let gen = UINotificationFeedbackGenerator()
                gen.notificationOccurred(.success)
                
                navigationPath.removeLast(navigationPath.count)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 8)
            .opacity(showContent ? 1 : 0)
        }
        .onAppear {
            startAnimations()
            if isFullCompletion { confettiTrigger += 1 }
        }
    }
    
    // MARK: - Animation Functions
    private func startAnimations() {
        withAnimation(.spring(response: 0.6, dampingFraction: 0.6).delay(0.1)) {
            celebrationScale = 1.0
        }
        withAnimation(.spring(response: 0.6, dampingFraction: 0.4).delay(0.3).repeatForever(autoreverses: true)) {
            celebrationScale = 1.1
        }
        
        withAnimation(.easeOut(duration: 0.5).delay(0.2)) {
            showContent = true
        }
        
        animateCountUp(
            from: 0,
            to: exercisesCount,
            duration: 0.8,
            delay: 0.5
        ) { value in
            animatedExercises = value
        }
        
        animateCountUp(
            from: 0,
            to: estimatedCalories,
            duration: 1.0,
            delay: 0.6
        ) { value in
            animatedCalories = value
        }
        
        animateCountUp(
            from: 0,
            to: durationM,
            duration: 0.8,
            delay: 0.65
        ) { value in
            animatedMinutes = value
        }
        
        animateCountUp(
            from: 0,
            to: durationS,
            duration: 0.8,
            delay: 0.7
        ) { value in
            animatedSeconds = value
        }
    }
    
    private func animateCountUp(from start: Int, to end: Int, duration: Double, delay: Double, update: @escaping (Int) -> Void) {
        let steps = min(end, 30)
        let stepDuration = duration / Double(steps)
        let increment = Double(end) / Double(steps)
        
        for step in 0...steps {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay + (stepDuration * Double(step))) {
                let value = min(Int(Double(step) * increment), end)
                withAnimation(.easeOut(duration: stepDuration)) {
                    update(value)
                }
            }
        }
    }
    
    // MARK: - Feedback Buttons
    private func feedbackEmojiButton(for option: FeedbackOption, index: Int) -> some View {
        let isSelected = selectedFeedback == option.id
        
        return Button {
            let gen = UIImpactFeedbackGenerator(style: .medium)
            gen.impactOccurred()
            
            withAnimation(.interpolatingSpring(stiffness: 300, damping: 15)) {
                selectedFeedback = option.id
            }
        } label: {
            Text(option.emoji)
                .font(.system(size: isSelected ? 42 : 32))
                .frame(height: 50)
                .frame(maxWidth: .infinity)
                .scaleEffect(isSelected ? 1.15 : 1.0)
                .rotationEffect(.degrees(isSelected ? 360 : 0))
                .shadow(color: isSelected ? brandColor.opacity(0.3) : .clear, radius: 8, y: 4)
                .offset(y: isSelected ? -8 : 0)
        }
        .buttonStyle(.plain)
        .opacity(showContent ? 1 : 0)
        .scaleEffect(showContent ? 1 : 0.5)
        .blur(radius: showContent ? 0 : 3)
        .animation(
            .interpolatingSpring(stiffness: 200, damping: 15)
            .delay(1.0 + Double(index) * 0.1),
            value: showContent
        )
        .animation(.interpolatingSpring(stiffness: 300, damping: 15), value: isSelected)
    }
    
    private func feedbackLabelButton(for option: FeedbackOption, index: Int) -> some View {
        let isSelected = selectedFeedback == option.id
        
        return Button {
            let gen = UIImpactFeedbackGenerator(style: .medium)
            gen.impactOccurred()
            
            withAnimation(.interpolatingSpring(stiffness: 300, damping: 15)) {
                selectedFeedback = option.id
            }
        } label: {
            Text(option.label)
                .font(.caption2.weight(isSelected ? .bold : .semibold))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, minHeight: 32)
                .foregroundStyle(isSelected ? brandColor : Color.secondary)
                .scaleEffect(isSelected ? 1.08 : 1.0)
        }
        .buttonStyle(.plain)
        .opacity(showContent ? 1 : 0)
        .scaleEffect(showContent ? 1 : 0.5)
        .blur(radius: showContent ? 0 : 3)
        .animation(
            .interpolatingSpring(stiffness: 200, damping: 15)
            .delay(1.05 + Double(index) * 0.1),
            value: showContent
        )
        .animation(.interpolatingSpring(stiffness: 300, damping: 15), value: isSelected)
    }

    // MARK: - Helpers
    private var dayCountText: String {
        let name = day.day
        let map: [(String, Int)] = [("月", 1), ("火", 2), ("水", 3), ("木", 4), ("金", 5), ("土", 6), ("日", 7)]
        if let hit = map.first(where: { name.contains($0.0) }) {
            return "\(hit.1)日目"
        }
        let digits = name.filter { $0.isNumber }
        if let n = Int(digits), n > 0 {
            return "\(n)日目"
        }
        return name
    }

    private var exercisesCount: Int {
        completedExerciseIndices.count
    }

    // ✅ 完了したエクササイズのみでカロリーを計算（リファクタリング版を使用）
    private var estimatedCalories: Int {
        let weight = userWeightKg
        
        let completedExercises = completedExerciseIndices.compactMap { index in
            day.exercises.indices.contains(index) ? day.exercises[index] : nil
        }

        var totalSec = 0
        var totalKcal = 0.0
        for ex in completedExercises {
            let sec = durationSeconds(for: ex)
            totalSec += sec
            
            // ✅ リファクタリング版の METValueProvider を使用
            let met = METValueProvider.shared.metValue(
                for: ex.name,
                isDurationBased: !ex.duration.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            )
            totalKcal += 1.05 * met * weight * (Double(sec) / 3600.0)
        }

        if totalSec == 0 {
            let kcal = 1.05 * 3.0 * weight * (Double(elapsedSeconds) / 3600.0)
            return max(0, Int(kcal.rounded()))
        }
        return max(0, Int(totalKcal.rounded()))
    }

    private var userWeightKg: Double {
        let w = appWeightA > 0 ? appWeightA : (appWeightB > 0 ? appWeightB : 0)
        return w > 0 ? w : 60
    }

    private func durationSeconds(for ex: PlanExercise) -> Int {
        let t = ex.duration.trimmingCharacters(in: .whitespacesAndNewlines)
        if !t.isEmpty {
            return parseJapaneseDurationSeconds(from: t)
        }
        let sets = firstInt(in: ex.sets) ?? 1
        let reps = firstInt(in: ex.reps) ?? 10
        return max(0, sets * reps * 3)
    }

    private func firstInt(in text: String) -> Int? {
        let digits = text.compactMap { $0.isNumber ? String($0) : nil }.joined()
        return digits.isEmpty ? nil : Int(digits)
    }

    private func parseJapaneseDurationSeconds(from text: String) -> Int {
        let s = text.replacingOccurrences(of: " ", with: "")
        var minutes = 0
        var seconds = 0
        if let m = matchInt(pattern: "(\\d+)\\s*分", in: s) { minutes = m }
        if let sVal = matchInt(pattern: "(\\d+)\\s*秒", in: s) { seconds = sVal }
        if minutes == 0 && seconds == 0 {
            if let only = Int(s.filter({ $0.isNumber })) { seconds = only }
        }
        return minutes * 60 + seconds
    }

    private func matchInt(pattern: String, in text: String) -> Int? {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let ns = text as NSString
        let range = NSRange(location: 0, length: ns.length)
        guard let m = regex.firstMatch(in: text, range: range), m.numberOfRanges >= 2 else { return nil }
        let r = m.range(at: 1)
        if let swiftRange = Range(r, in: text) { return Int(text[swiftRange]) }
        return nil
    }

    private var durationM: Int { max(elapsedSeconds / 60, 0) }
    private var durationS: Int { max(elapsedSeconds % 60, 0) }
    
    // MARK: - Save Workout
    private func saveWorkoutSession() {
        let userID = "current_user"
        
        let session = WorkoutSessionEntity(
            userID: userID,
            name: day.day,
            sessionDate: Date()
        )
        session.durationSeconds = elapsedSeconds
        session.caloriesKcal = estimatedCalories
        
        
        // 各完了したエクササイズに対して、setLogs から重量と回数を反映した LoggedSetEntity を作成する
        for exIndex in completedExerciseIndices {
            guard day.exercises.indices.contains(exIndex) else { continue }
            let exercise = day.exercises[exIndex]
            let loggedExercise = LoggedExerciseEntity(exerciseName: exercise.name)
            // このエクササイズに紐づくログを抽出
            let logsForExercise = setLogs.filter { $0.exerciseIndex == exIndex }
            if !logsForExercise.isEmpty {
                // ログのあるセットをそのまま保存
                for log in logsForExercise {
                    let set = LoggedSetEntity(
                        setIndex: log.setIndex,
                        weightKg: log.weightKg,
                        reps: log.reps,
                        isCompleted: true
                    )
                    loggedExercise.sets.append(set)
                }
            } else {
                // ログが無い場合は PlanExercise のセット数を元にデフォルト値で保存
                // sets 文字列から数字を抽出（例: "3セット" → 3）
                let digitsOnly = exercise.sets.replacingOccurrences(of: "[^0-9]", with: "", options: .regularExpression)
                if let setCount = Int(digitsOnly) {
                    for i in 1...setCount {
                        let set = LoggedSetEntity(
                            setIndex: i,
                            weightKg: 0,
                            reps: 0,
                            isCompleted: true
                        )
                        loggedExercise.sets.append(set)
                    }
                }
            }
            session.exercises.append(loggedExercise)
        }
        
        modelContext.insert(session)
        
        // WorkoutProgressを更新
        let descriptor = FetchDescriptor<GeneratedPlanRecord>(
            sortBy: [SortDescriptor(\GeneratedPlanRecord.createdAt, order: .reverse)]
        )
        
        if let planRecords = try? modelContext.fetch(descriptor),
           let latestPlan = planRecords.first {
            
            let planId = latestPlan.id
            let dayIdentifier = day.day
            
            let progressDescriptor = FetchDescriptor<WorkoutProgress>(
                predicate: #Predicate<WorkoutProgress> { progress in
                    progress.planRecordId == planId &&
                    progress.dayIdentifier == dayIdentifier
                }
            )
            
            if let existingProgress = try? modelContext.fetch(progressDescriptor).first {
                existingProgress.isCompleted = isFullCompletion
                existingProgress.completedAt = Date()
                existingProgress.elapsedSeconds = elapsedSeconds
                existingProgress.estimatedCalories = estimatedCalories
                existingProgress.difficultyFeedback = selectedFeedback
            } else {
                let newProgress = WorkoutProgress(
                    planRecordId: latestPlan.id,
                    dayIdentifier: day.day,
                    completedAt: Date(),
                    isCompleted: isFullCompletion
                )
                newProgress.elapsedSeconds = elapsedSeconds
                newProgress.estimatedCalories = estimatedCalories
                newProgress.difficultyFeedback = selectedFeedback
                modelContext.insert(newProgress)
            }
        }
        
        do {
            try modelContext.save()
            print("✅ ワークアウトセッションと進捗を保存しました")
        } catch {
            print("❌ Failed to save workout session: \(error)")
        }
    }
}

#Preview("PlanCompletionView • Light") {
    @Previewable @State var path = NavigationPath()
    PlanCompletionView(
        day: DaySchedule(day: "月曜日", exercises: [
            PlanExercise(name: "スクワット", sets: "3セット", reps: "12回", weight: "自重", duration: "", notes: ""),
            PlanExercise(name: "スクワット", sets: "3セット", reps: "12回", weight: "自重", duration: "", notes: "")
        ]),
        elapsedSeconds: 20 * 60 + 45,
        isFullCompletion: true,
        completedExerciseIndices: [0, 1],
        setLogs: [],
        navigationPath: $path
    )
    .preferredColorScheme(.light)
    .task { UserDefaults.standard.set(68.0, forKey: "userWeightKg") }
    .modelContainer(for: [WorkoutSessionEntity.self, WorkoutProgress.self])
}

#Preview("PlanCompletionView • Dark") {
    @Previewable @State var path = NavigationPath()
    PlanCompletionView(
        day: DaySchedule(day: "月曜日", exercises: [
            PlanExercise(name: "スクワット", sets: "3セット", reps: "12回", weight: "自重", duration: "", notes: ""),
            PlanExercise(name: "プランク", sets: "3セット", reps: "", weight: "自重", duration: "45秒", notes: "")
        ]),
        elapsedSeconds: 20 * 60 + 45,
        isFullCompletion: false,
        completedExerciseIndices: [0],
        setLogs: [],
        navigationPath: $path
    )
    .preferredColorScheme(.dark)
    .task { UserDefaults.standard.set(55.0, forKey: "userWeightKg") }
    .modelContainer(for: [WorkoutSessionEntity.self, WorkoutProgress.self], inMemory: true)
}
