import SwiftUI
import SwiftData


// MARK: - Main AI Plan View

struct AIPlanButtonView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    
    @Query(FetchDescriptor<GeneratedPlanRecord>(sortBy: [SortDescriptor(\GeneratedPlanRecord.createdAt, order: .reverse)])) private var planRecords: [GeneratedPlanRecord]
    @Query private var progressRecords: [WorkoutProgress]
    
    @State private var selectedPlan: AIGeneratedPlan?
    @Binding var navigationPath: NavigationPath
    
    var body: some View {
        Group {
            if let plan = selectedPlan {
                planContentView(plan: plan)
            } else if let latestRecord = planRecords.first {
                Color.clear.onAppear {
                    loadPlan(from: latestRecord)
                }
            } else {
                // Show demo plan when no AI plan exists
                planContentView(plan: demoPlan)
            }
        }
        .navigationTitle("AIプラン")
        .navigationBarTitleDisplayMode(.large)
    }
    
    // MARK: - Plan Content View
    
    private func planContentView(plan: AIGeneratedPlan) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Weekly Schedule
                weeklyScheduleSection(plan: plan)
            }
            .padding()
        }
        .background(colorScheme == .dark ? Color.black : Color(.systemGroupedBackground))
    }
    
    
    // MARK: - Weekly Schedule Section
    
    private func weeklyScheduleSection(plan: AIGeneratedPlan) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            ForEach(Array(plan.workoutPlan.weeklySchedule.enumerated()), id: \.element.id) { index, daySchedule in
                WorkoutDayCard(
                    daySchedule: daySchedule,
                    dayNumber: index + 1,
                    isCompleted: isWorkoutCompleted(daySchedule),
                    isPreviousDayCompleted: isPreviousDayCompleted(dayIndex: index, plan: plan),
                    onStart: {
                        startWorkout(for: daySchedule)
                    }
                )
            }
        }
    }
    // MARK: - Helper Methods
    
    private func loadPlan(from record: GeneratedPlanRecord) {
        guard let data = record.json.data(using: String.Encoding.utf8) else { return }
        let decoder = JSONDecoder()
        selectedPlan = try? decoder.decode(AIGeneratedPlan.self, from: data)
    }
    
    private func isWorkoutCompleted(_ daySchedule: DaySchedule) -> Bool {
        guard let planId = planRecords.first?.id else { return false }
        return progressRecords.contains { progress in
            progress.planRecordId == planId &&
            progress.dayIdentifier == daySchedule.day &&
            progress.isCompleted
        }
    }
    
    private func isPreviousDayCompleted(dayIndex: Int, plan: AIGeneratedPlan) -> Bool {
        // First day is always unlocked
        if dayIndex == 0 {
            return true
        }
        
        // Check if previous day is completed
        let previousDay = plan.workoutPlan.weeklySchedule[dayIndex - 1]
        return isWorkoutCompleted(previousDay)
    }
    
    private func startWorkout(for daySchedule: DaySchedule) {
        // StandbyViewに遷移
        navigationPath.append(
            WorkoutNavigationDestination.standbyView(day: daySchedule)
        )
    }
    
    private func markWorkoutAsComplete(_ daySchedule: DaySchedule) {
        guard let planId = planRecords.first?.id else { return }
        
        // Check if already exists
        if let existing = progressRecords.first(where: {
            $0.planRecordId == planId && $0.dayIdentifier == daySchedule.day
        }) {
            existing.isCompleted = true
            existing.completedAt = Date()
        } else {
            let progress = WorkoutProgress(
                planRecordId: planId,
                dayIdentifier: daySchedule.day,
                completedAt: Date(),
                isCompleted: true
            )
            modelContext.insert(progress)
        }
        
        try? modelContext.save()
    }
    
}

// MARK: - Workout Day Card

struct WorkoutDayCard: View {
    @Environment(\.colorScheme) var colorScheme
    let daySchedule: DaySchedule
    let dayNumber: Int
    let isCompleted: Bool
    let isPreviousDayCompleted: Bool
    let onStart: () -> Void
    
    private let brandGradient = LinearGradient(
        colors: [
            Color(red: 95/255, green: 134/255, blue: 1.0),
            Color(red: 124/255, green: 77/255, blue: 1.0)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 16) {
                // Left: Day info
                VStack(alignment: .leading, spacing: 6) {
                    if isCompleted {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(Color.green)
                            Text("完了")
                                .font(.caption.bold())
                                .foregroundStyle(Color.green)
                        }
                    }
                    
                    Text(daySchedule.day)
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                    
                    Text("\(dayNumber)日目")
                        .font(.system(size: 32, weight: .bold))
                    
                    HStack(spacing: 8) {
                        Text("\(estimatedDuration())分")
                        Text("|")
                        Text("\(estimatedCalories())kcal")
                    }
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                }
                
                Spacer(minLength: 16)
                
                // Right: Exercise preview
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(daySchedule.exercises.prefix(3)) { exercise in
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Image(systemName: "circle.fill")
                                .font(.system(size: 5))
                                .foregroundColor(.secondary.opacity(0.5))
                            
                            Text(exercise.name)
                                .font(.system(size: 13, weight: .medium))
                                .lineLimit(1)
                        }
                    }
                    
                    if daySchedule.exercises.count > 3 {
                        Text("他\(daySchedule.exercises.count - 3)種目")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                            .padding(.leading, 11)
                    }
                }
                .frame(maxWidth: 180, alignment: .leading)
            }
            .padding(16)
            
            // Start/Complete button
            if !isCompleted {
                Button(action: onStart) {
                    HStack {
                        Image(systemName: isPreviousDayCompleted ? "play.fill" : "lock.fill")
                        Text(isPreviousDayCompleted ? "開始する" : "前の日を完了してください")
                            .font(.headline)
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        isPreviousDayCompleted
                        ? brandGradient
                        : LinearGradient(colors: [.gray], startPoint: .leading, endPoint: .trailing)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(!isPreviousDayCompleted)
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(colorScheme == .dark ? Color(.systemGray6).opacity(0.3) : Color.white)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(isCompleted ? Color.green.opacity(0.3) : Color.clear, lineWidth: 2)
        )
        .shadow(color: .black.opacity(0.08), radius: 12, x: 0, y: 4)
    }
    
    // MARK: - Helper Methods
    
    private func estimatedDuration() -> Int {
        var totalMinutes = 0
        
        for exercise in daySchedule.exercises {
            // Duration-based exercises
            if !exercise.duration.isEmpty {
                let durationStr = exercise.duration.replacingOccurrences(of: "[^0-9]", with: "", options: .regularExpression)
                if let duration = Int(durationStr) {
                    let sets = extractSets(from: exercise.sets)
                    if duration >= 30 { // seconds
                        totalMinutes += (duration * sets) / 60
                    } else { // already in minutes
                        totalMinutes += duration * sets
                    }
                }
            }
            
            // Reps-based exercises (estimate ~3 seconds per rep)
            if !exercise.reps.isEmpty {
                let repsStr = exercise.reps.replacingOccurrences(of: "[^0-9]", with: "", options: .regularExpression)
                if let reps = Int(repsStr) {
                    let sets = extractSets(from: exercise.sets)
                    totalMinutes += (reps * sets * 3) / 60 // 3 seconds per rep
                }
            }
        }
        
        return max(totalMinutes, 5) // Minimum 5 minutes
    }
    
    private func estimatedCalories() -> Int {
        // Rough estimation: ~5-8 kcal per minute of workout
        let duration = estimatedDuration()
        return duration * 6
    }
    
    private func extractSets(from setsString: String) -> Int {
        let setsStr = setsString.replacingOccurrences(of: "[^0-9]", with: "", options: .regularExpression)
        return Int(setsStr) ?? 1
    }
}

// MARK: - Preview
#Preview("AIPlanButtonView") {
    @Previewable @State var path = NavigationPath()
    
    NavigationStack(path: $path) {
        AIPlanButtonView(navigationPath: $path)
    }
    .preferredColorScheme(.dark)
    .modelContainer(for: [GeneratedPlanRecord.self, WorkoutProgress.self], inMemory: true)
}

// MARK: - Demo Plan Data

private let demoPlan = AIGeneratedPlan(
    summary: "週3回の自宅トレと、1800kcal前後の食事でゆる〜く脂肪を減らすプランです。",
    workoutPlan: WorkoutPlanDetail(
        overview: "自宅でできる筋トレと有酸素を交互に配置しています。",
        weeklySchedule: [
            DaySchedule(day: "月曜日", exercises: [
                // AIPlanButton.swift の一番下にある demoPla

                // 修正後:
                // ...
                PlanExercise(name: "スクワット", sets: "3セット", reps: "12回", weight: "自重", duration: "", notes: "フォームを崩さない範囲で"),
                PlanExercise(name: "プッシュアップ", sets: "3セット", reps: "10回", weight: "自重", duration: "", notes: "膝をついてもOK"),
                // ... (他の PlanExercise にも同様に追加)
            ])
        ],
        tips: ["疲れている日はストレッチに置き換えてOK", "週1回は完全休養日をつくる"]
    ),
    nutritionPlan: NutritionPlanDetail(
        overview: "PFCバランスを大きく崩さず、外食も週1でOKな設計です。",
        dailyCalories: 1800,
        macronutrients: Macronutrients(protein: "95g", carbs: "200g", fats: "55g"),
        mealSuggestions: [
            MealSuggestion(meal: "朝食", suggestion: "オートミール+ヨーグルト+フルーツ+ゆで卵"),
            MealSuggestion(meal: "昼食", suggestion: "鶏むね肉のプレート+雑穀米+サラダ"),
            MealSuggestion(meal: "夕食", suggestion: "鮭のホイル焼き+味噌汁+温野菜")
        ],
        tips: ["水分は1.5Lを目安に", "週末は糖質をやや多めにしてもよい"]
    ),
    motivationalMessage: "ここまで入力できた時点でかなり優秀です。今日はこのプランから1つだけ実行してみましょう。"
)
