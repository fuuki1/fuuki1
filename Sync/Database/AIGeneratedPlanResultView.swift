import SwiftUI

struct AIGeneratedPlanResultView: View {
    let plan: AIGeneratedPlan
    let onStart: () -> Void
    
    @Environment(\.colorScheme) private var colorScheme
    
    private let brandGradient = LinearGradient(
        colors: [
            Color(red: 95/255, green: 134/255, blue: 1.0),
            Color(red: 124/255, green: 77/255, blue: 1.0)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // ヘッダー
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 40))
                            .foregroundStyle(brandGradient)
                        
                        Spacer()
                    }
                    
                    Text("あなた専用プランが\n完成しました!")
                        .font(.system(size: 34, weight: .bold))
                        .lineSpacing(4)
                    
                    Text(plan.summary)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .lineSpacing(6)
                }
                .padding(.horizontal, 24)
                .padding(.top, 20)
                
                // 運動プラン
                planSection(
                    title: "運動プラン",
                    icon: "figure.run",
                    color: Color(red: 95/255, green: 134/255, blue: 1.0)
                ) {
                    VStack(alignment: .leading, spacing: 16) {
                        Text(plan.workoutPlan.overview)
                            .font(.body)
                            .foregroundStyle(.secondary)
                        
                        ForEach(plan.workoutPlan.weeklySchedule.prefix(3)) { day in
                            dayScheduleCard(day: day)
                        }
                        
                        if plan.workoutPlan.weeklySchedule.count > 3 {
                            Text("他\(plan.workoutPlan.weeklySchedule.count - 3)日分のプランも用意されています")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .padding(.top, 8)
                        }
                        
                        if !plan.workoutPlan.tips.isEmpty {
                            tipsSection(tips: plan.workoutPlan.tips, title: "運動のコツ")
                        }
                    }
                }
                
                // 栄養プラン
                planSection(
                    title: "栄養プラン",
                    icon: "fork.knife",
                    color: Color(red: 255/255, green: 140/255, blue: 100/255)
                ) {
                    VStack(alignment: .leading, spacing: 16) {
                        Text(plan.nutritionPlan.overview)
                            .font(.body)
                            .foregroundStyle(.secondary)
                        
                        HStack(spacing: 12) {
                            macroCard(
                                title: "カロリー",
                                value: "\(plan.nutritionPlan.dailyCalories)",
                                unit: "kcal",
                                color: .orange
                            )
                            
                            macroCard(
                                title: "タンパク質",
                                value: plan.nutritionPlan.macronutrients.protein,
                                unit: "",
                                color: .red
                            )
                        }
                        
                        HStack(spacing: 12) {
                            macroCard(
                                title: "炭水化物",
                                value: plan.nutritionPlan.macronutrients.carbs,
                                unit: "",
                                color: .green
                            )
                            
                            macroCard(
                                title: "脂質",
                                value: plan.nutritionPlan.macronutrients.fats,
                                unit: "",
                                color: .yellow
                            )
                        }
                        
                        ForEach(plan.nutritionPlan.mealSuggestions.prefix(3)) { meal in
                            mealCard(meal: meal)
                        }
                        
                        if !plan.nutritionPlan.tips.isEmpty {
                            tipsSection(tips: plan.nutritionPlan.tips, title: "栄養のコツ")
                        }
                    }
                }
                
                // 励ましメッセージ
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "heart.fill")
                            .foregroundStyle(Color.pink)
                        Text("応援メッセージ")
                            .font(.headline)
                    }
                    
                    Text(plan.motivationalMessage)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .lineSpacing(6)
                }
                .padding(20)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.pink.opacity(0.08))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.pink.opacity(0.2), lineWidth: 1)
                )
                .padding(.horizontal, 24)
                
                Spacer(minLength: 120)
            }
            .padding(.vertical, 20)
        }
        .safeAreaInset(edge: .bottom) {
            Button {
                onStart()
            } label: {
                Text("プランを開始")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(brandGradient)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
        }
    }
    
    // MARK: - Helper Views
    
    private func planSection<Content: View>(
        title: String,
        icon: String,
        color: Color,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(color)
                Text(title)
                    .font(.title3.bold())
            }
            .padding(.horizontal, 24)
            
            content()
                .padding(.horizontal, 24)
        }
    }
    
    private func dayScheduleCard(day: DaySchedule) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(day.day)
                .font(.headline)
            
            ForEach(day.exercises.prefix(3)) { exercise in
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "circle.fill")
                        .font(.system(size: 6))
                        .foregroundStyle(.secondary)
                        .padding(.top, 6)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(exercise.name)
                            .font(.subheadline.weight(.semibold))
                        
                        HStack(spacing: 8) {
                            if !exercise.sets.isEmpty {
                                Label(exercise.sets, systemImage: "repeat")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            // ★ weight があれば表示 (ここに追加するとプレビューでも確認できます)
                            if !exercise.weight.isEmpty {
                                Label(exercise.weight, systemImage: "scalemass")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            if !exercise.reps.isEmpty {
                                Label(exercise.reps, systemImage: "number")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            if !exercise.duration.isEmpty {
                                Label(exercise.duration, systemImage: "timer")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        
                        if !exercise.notes.isEmpty {
                            Text(exercise.notes)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            
            if day.exercises.count > 3 {
                Text("他\(day.exercises.count - 3)種目")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
        )
    }
    
    private func macroCard(title: String, value: String, unit: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(value)
                    .font(.title2.bold())
                    .foregroundStyle(color)
                if !unit.isEmpty {
                    Text(unit)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(color.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(color.opacity(0.2), lineWidth: 1)
        )
    }
    
    private func mealCard(meal: MealSuggestion) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(meal.meal)
                .font(.headline)
            
            Text(meal.suggestion)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
        )
    }
    
    private func tipsSection(tips: [String], title: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "lightbulb.fill")
                    .foregroundStyle(.yellow)
                Text(title)
                    .font(.headline)
            }
            
            ForEach(Array(tips.enumerated()), id: \.offset) { _, tip in
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "checkmark")
                        .font(.caption)
                        .foregroundStyle(.green)
                        .padding(.top, 2)
                    
                    Text(tip)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.yellow.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.yellow.opacity(0.2), lineWidth: 1)
        )
    }
}

// MARK: - Preview

#Preview("ライトモード") {
    AIGeneratedPlanResultView(
        plan: demoPlan,
        onStart: {}
    )
}

#Preview("ダークモード") {
    AIGeneratedPlanResultView(
        plan: demoPlan,
        onStart: {}
    )
    .preferredColorScheme(.dark)
}

// 👇 ★★★ ここからが修正箇所です ★★★

fileprivate let demoPlan = AIGeneratedPlan(
    summary: "週3回の自宅トレと、1800kcal前後の食事でゆる〜く脂肪を減らすプランです。",
    workoutPlan: WorkoutPlanDetail(
        overview: "自宅でできる全有酸素を交互に配置しています。",
        weeklySchedule: [
            DaySchedule(day: "月曜日", exercises: [
                PlanExercise(name: "スクワット", sets: "3セット", reps: "12回", weight: "自重", duration: "", notes: "フォームを崩さない範囲で"),
                PlanExercise(name: "ヒップリフト", sets: "3セット", reps: "15回", weight: "自重", duration: "", notes: "お尻をしっかり締める")
            ]),
            DaySchedule(day: "水曜日", exercises: [
                PlanExercise(name: "ウォーキング", sets: "", reps: "", weight: "自重", duration: "30分", notes: "話せるくらいの強度で")
            ]),
            DaySchedule(day: "土曜日", exercises: [
                PlanExercise(name: "プランク", sets: "3セット", reps: "", weight: "自重", duration: "30秒", notes: "腰を落とさない"),
                PlanExercise(name: "バードドッグ", sets: "2セット", reps: "左右10回", weight: "自重", duration: "", notes: "体幹を意識")
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
