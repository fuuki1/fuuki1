import SwiftUI
import SwiftData

struct ActivityCardView: View {
    // ✅ 今日のワークアウトセッションをQueryで取得
    @Query(
        filter: #Predicate<WorkoutSessionEntity> { session in
            // 今日の日付でフィルタリング(注: この形式ではフィルタが動作しないため、bodyで再フィルタ)
            true
        },
        sort: \WorkoutSessionEntity.sessionDate,
        order: .reverse
    ) private var allSessions: [WorkoutSessionEntity]
    
    @EnvironmentObject private var activityData: ActivityDataManager
    
    @Binding var navigationPath: NavigationPath
    var onStartWorkout: () -> Void
    var onAddActivity: () -> Void
    
    // ✅ 今日のワークアウトデータを計算
    private var todayMinutes: Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        return allSessions
            .filter { calendar.isDate($0.sessionDate, inSameDayAs: today) }
            .reduce(0) { $0 + ($1.durationSeconds / 60) }
    }
    
    private var todayCalories: Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        return allSessions
            .filter { calendar.isDate($0.sessionDate, inSameDayAs: today) }
            .reduce(0) { $0 + $1.caloriesKcal }
    }
    
    // ✅ HealthKitのゴールまたはデフォルト値
    private var goalMinutes: Int {
        // ActivityDataManagerから取得する、または固定値
        return activityData.exerciseGoalMinutes ?? 30
    }
    
    var progress: Double {
        guard goalMinutes > 0 else { return 0 }
        return min(Double(todayMinutes) / Double(goalMinutes), 1.0)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("\(todayMinutes)")
                            .font(.system(size: 44, weight: .bold))
                            .contentTransition(.numericText())
                        Text("分")
                            .font(.system(size: 24, weight: .medium))
                            .foregroundColor(.secondary)
                        Text("/ \(goalMinutes)分")
                            .font(.system(size: 20, weight: .regular))
                            .foregroundColor(.secondary)
                    }
                    
                    Text("カロリー: \(todayCalories)kcal")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.secondary)
                        .contentTransition(.numericText())
                }
                
                Spacer()
                
                ActivityRingView(progress: progress)
            }
            
            VStack(spacing: 12) {
                Button(action: onStartWorkout) {
                    Text("AIプランを開始")
                        .font(.system(size: 18, weight:.semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth:.infinity)
                        .frame(height: 56)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(Color(red: 124.0/255.0, green: 77.0/255.0, blue: 255.0/255.0))
                        )
                        .glassEffect(in:.rect(cornerRadius: 14.0))
                }
                
                Button(action: onAddActivity) {
                    HStack(spacing: 8) {
                        Image(systemName: "plus")
                            .font(.system(size: 16, weight: .semibold))
                        Text("筋トレ記録")
                            .font(.system(size: 18, weight: .semibold))
                    }
                    .foregroundColor(.primary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .glassEffect(in:.rect(cornerRadius: 14.0))
                }
            }
        }
        .padding(20)
        .glassEffect(in:.rect(cornerRadius: 20))
        .animation(.spring(response: 0.4), value: todayMinutes)
        .animation(.spring(response: 0.4), value: todayCalories)
    }
}

struct ActivityRingView: View {
    let progress: Double
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(Color(.systemGray5), lineWidth: 5)
                .frame(width: 80, height: 80)
            
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    LinearGradient(
                        colors: [.green, .green.opacity(0.8)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    style: StrokeStyle(lineWidth: 8, lineCap: .round)
                )
                .frame(width: 80, height: 80)
                .rotationEffect(.degrees(-90))
                .animation(.spring(response: 0.6, dampingFraction: 0.8), value: progress)
        }
    }
}

#Preview {
    @Previewable @State var path = NavigationPath()
    
    NavigationStack(path: $path) {
        ActivityCardView(
            navigationPath: $path,
            onStartWorkout: {},
            onAddActivity: {}
        )
        .environmentObject(ActivityDataManager.shared)
        .padding()
    }
    .modelContainer(for: [WorkoutSessionEntity.self], inMemory: true)
}
