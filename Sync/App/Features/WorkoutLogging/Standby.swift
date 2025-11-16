import SwiftUI

// StandbyView: プラン詳細・準備画面
struct StandbyView: View {
    let day: DaySchedule
    @Binding var navigationPath: NavigationPath // 追加

    var body: some View {
        List {

            HStack(spacing: 12) {
                Text("プラン詳細")
                    .font(.subheadline.weight(.semibold))
                Text(summaryText())
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 4)
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)

            Section {
                ForEach(day.exercises.indices, id: \.self) { i in
                    let ex = day.exercises[i]
                    VStack(alignment: .leading, spacing: 8) {
                        Text(ex.name)
                            .font(.headline)

                        HStack(spacing: 12) {
                            stepChip(i + 1)
                                                    
                                                    // セット/回数/時間を取得
                        let setRepStr = setRepText(for: ex)
                        if !setRepStr.isEmpty {
                    Text(setRepStr)
                            }
                                                    
                                                    // ★追加: 重量(weight)を取得
            
                            let weightStr = ex.weight.trimmingCharacters(in: .whitespacesAndNewlines)
                            if !weightStr.isEmpty {// 区切り文字 (セット/回数がある場合のみ)
                if !setRepStr.isEmpty {
                                                            Text("•")
                                                                .padding(.horizontal, -4) // 中黒の前後のスペースを詰める
                                                        }
                                                        // 重量テキストを表示
                                                        Text(weightStr)
                                                    }
                                                }
                                                .font(.callout)
                                                .foregroundStyle(.secondary)

                        if !ex.notes.isEmpty {
                            Text(ex.notes)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 6)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.visible)
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .listSectionSpacing(0)
        .safeAreaInset(edge: .bottom) {
            HStack {
                StartPrimaryButton(title: "ワークアウト開始") {
                    startWorkout()
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 16)
            .background(Color.clear)
        }
        .navigationTitle("\(currentMonthDayString()) \(day.day)")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Actions
    
    private func startWorkout() {
        navigationPath.append(
            WorkoutNavigationDestination.timerView(
                day: day,
                elapsedSeconds: 0
            )
        )
    }

    // MARK: - Helpers

    private func stepChip(_ n: Int) -> some View {
        Text("STEP \(n)")
            .font(.caption2.weight(.semibold))
            .padding(.vertical, 3)
            .padding(.horizontal, 8)
            .background(
                Capsule(style: .continuous)
                    .fill(
                        
                        LinearGradient(
                            gradient: Gradient(stops: [
                                .init(color: Color(red: 107/255, green: 94/255,  blue: 255/255), location: 0.0),
                                .init(color: Color(red: 124/255, green: 77/255,  blue: 255/255), location: 0.62),
                                .init(color: Color(red: 140/255, green: 84/255,  blue: 255/255), location: 1.0)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .glassEffect(in: .rect(cornerRadius: 12))
            .foregroundStyle(.white)
    }

    private func setRepText(for ex: PlanExercise) -> String {
        let sets = ex.sets.trimmingCharacters(in: .whitespacesAndNewlines)
        let reps = ex.reps.trimmingCharacters(in: .whitespacesAndNewlines)
        let duration = ex.duration.trimmingCharacters(in: .whitespacesAndNewlines)

        if !sets.isEmpty && !reps.isEmpty {
            return "\(sets) × \(reps)"
        }
        if !sets.isEmpty && !duration.isEmpty {
            return "\(sets) × \(duration)"
        }
        if !sets.isEmpty { return sets }
        if !reps.isEmpty { return reps }
        if !duration.isEmpty { return duration }
        return ""
    }

    private func currentMonthDayString() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = "M月d日"
        return formatter.string(from: Date())
    }

    private func summaryText() -> String {
        let setCount = day.exercises.reduce(0) { partial, ex in
            partial + extractSets(from: ex.sets)
        }
        let totalMinutes = estimatedDurationMinutes()
        return "セット \(setCount) ・ 目安 \(totalMinutes)分"
    }

    private func estimatedDurationMinutes() -> Int {
        var totalMinutes = 0

        for ex in day.exercises {
            // duration(秒 or 分表記)を加算
            if !ex.duration.isEmpty {
                let digits = ex.duration.replacingOccurrences(of: "[^0-9]", with: "", options: .regularExpression)
                if let num = Int(digits) {
                    let sets = max(1, extractSets(from: ex.sets))
                    // 30以上なら秒とみなし、未満なら分とみなす(柔軟な推定)
                    if num >= 30 {
                        totalMinutes += (num * sets) / 60
                    } else {
                        totalMinutes += num * sets
                    }
                }
            }

            // reps(回数ベース)の概算(1rep ≒ 3秒)
            if !ex.reps.isEmpty {
                let digits = ex.reps.replacingOccurrences(of: "[^0-9]", with: "", options: .regularExpression)
                if let reps = Int(digits) {
                    let sets = max(1, extractSets(from: ex.sets))
                    totalMinutes += (reps * sets * 3) / 60
                }
            }
        }

        return max(totalMinutes, 5)
    }

    private func extractSets(from setsString: String) -> Int {
        let digits = setsString.replacingOccurrences(of: "[^0-9]", with: "", options: .regularExpression)
        return Int(digits) ?? 1
    }
}

// MARK: - Preview
#Preview("Standby") {
    @Previewable @State var path = NavigationPath()
    
    NavigationStack(path: $path) {
        StandbyView(
            day: DaySchedule(day: "月曜日", exercises: [
                PlanExercise(name: "スクワット", sets: "3セット", reps: "12回", weight: "自重", duration: "", notes: "フォームを崩さない範囲で"),
                PlanExercise(name: "プッシュアップ", sets: "3セット", reps: "10回", weight: "自重", duration: "", notes: "膝をついてもOK"),
                PlanExercise(name: "プランク", sets: "3セット", reps: "", weight: "自重", duration: "45秒", notes: "腰を落とさない")
            ]),
            navigationPath: $path
        )
    }
}
