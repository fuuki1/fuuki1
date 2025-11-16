import SwiftUI

// MARK: - Workout Row

/// A row displaying workout information with a navigation link to add sets
struct WorkoutRow: View {
    /// 表示するワークアウト
    let workout: WorkoutItem
    /// 選択中の日付（親ビューから渡される）
    let currentDate: Date

    private var calorieString: String {
        if workout.calories < 1.0 {
            return String(format: "%.1f", workout.calories)
        } else {
            return String(format: "%.0f", workout.calories.rounded())
        }
    }

    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(workout.name)
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)

                Text("目安 \(calorieString)Kcal / \(workout.displayUnit)")
                    .font(.caption)
                    .foregroundColor(.gray)
            }

            Spacer()

            NavigationLink {
                ExerciseSetEntryView(
                    exerciseName: workout.name,
                    selectedDate: currentDate
                )
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 16, weight: .semibold))
                    .frame(width: 14, height: 24)
                    .contentShape(Circle())
            }
            .buttonStyle(.glass)
            .tint(Color(hex: "1F2340"))
        }
        .padding(.horizontal)
        .padding(.vertical, 0)
    }
}
