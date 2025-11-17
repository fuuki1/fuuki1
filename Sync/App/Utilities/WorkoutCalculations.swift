import Foundation

// MARK: - Workout Calculations

/// ワークアウト関連の計算を行うユーティリティ
enum WorkoutCalculations {
    // MARK: - Duration Estimation

    /// エクササイズリストから推定ワークアウト時間を計算
    ///
    /// 計算ロジック:
    /// - 時間ベース（duration指定あり）: durationをそのまま使用
    /// - レップベース: セット数 × レップ数 × 2.5秒 + セット間休憩（1分）
    /// - 休憩時間: セット間に1分、エクササイズ間に1.5分
    ///
    /// - Parameter exercises: エクササイズのリスト（PlanExercise配列）
    /// - Returns: 推定時間（分）
    static func estimatedDuration<T>(for exercises: [T]) -> Int where T: ExerciseProtocol {
        var totalMinutes = 0

        for (index, ex) in exercises.enumerated() {
            let sets = ExerciseParser.extractSets(from: ex.sets)

            // 時間ベースのエクササイズ
            if !ex.duration.isEmpty, ex.duration != "−" {
                let durationSeconds = ExerciseParser.parseDurationToSeconds(ex.duration)
                let durationMinutes = (durationSeconds + 59) / 60 // 秒を分に変換（切り上げ）
                totalMinutes += durationMinutes * sets

                // セット間休憩（最後のセット以外）
                if sets > 1 {
                    totalMinutes += (sets - 1) // 1分 × (セット数 - 1)
                }
            }
            // レップベースのエクササイズ
            else if !ex.reps.isEmpty, ex.reps != "−" {
                if let reps = ExerciseParser.firstInt(from: ex.reps) {
                    // レップあたり約2.5秒 × レップ数 × セット数
                    let secondsPerSet = Int(Double(reps) * 2.5)
                    totalMinutes += (secondsPerSet * sets + 59) / 60 // 秒を分に変換（切り上げ）

                    // セット間休憩（最後のセット以外）
                    if sets > 1 {
                        totalMinutes += (sets - 1) // 1分 × (セット数 - 1)
                    }
                } else {
                    // レップ数がパースできない場合は、デフォルトで3分/セット
                    totalMinutes += 3 * sets
                }
            }
            // duration, repsがどちらも指定されていない場合
            else {
                totalMinutes += 3 * sets // デフォルト: 3分/セット
            }

            // エクササイズ間の休憩（最後のエクササイズ以外）
            if index < exercises.count - 1 {
                totalMinutes += 2 // エクササイズ間休憩: 2分
            }
        }

        return max(totalMinutes, 1) // 最低1分
    }

    // MARK: - Calorie Estimation

    /// ワークアウト時間から推定カロリー消費量を計算
    ///
    /// 計算式: 時間（分） × 5kcal/分（中程度の強度を想定）
    ///
    /// - Parameter durationMinutes: ワークアウト時間（分）
    /// - Returns: 推定カロリー消費量（kcal）
    static func estimatedCalories(for durationMinutes: Int) -> Int {
        durationMinutes * 5 // 1分あたり約5kcal（中程度の強度）
    }

    /// METs値とユーザー体重から正確なカロリー消費量を計算
    ///
    /// 計算式: METs × 体重（kg） × 時間（時） × 1.05
    ///
    /// - Parameters:
    ///   - mets: METs値
    ///   - weightKg: ユーザー体重（kg）
    ///   - durationMinutes: 運動時間（分）
    /// - Returns: カロリー消費量（kcal）
    static func caloriesFromMETs(mets: Double, weightKg: Double, durationMinutes: Int) -> Int {
        let hours = Double(durationMinutes) / 60.0
        let calories = mets * weightKg * hours * 1.05
        return Int(calories.rounded())
    }

    // MARK: - Rep-Based Duration Estimation

    /// レップベースのセットの推定時間を計算
    ///
    /// 計算式:
    /// - レップあたり2.5秒
    /// - セット間休憩: 60秒
    /// - 準備時間: 10秒
    ///
    /// - Parameters:
    ///   - sets: セット数
    ///   - reps: 1セットあたりのレップ数
    /// - Returns: 推定時間（秒）
    static func estimatedSeconds(sets: Int, reps: Int) -> Int {
        let secondsPerRep = 2.5
        let restBetweenSets = 60
        let setupTime = 10

        let workSeconds = Int(Double(sets * reps) * secondsPerRep)
        let restSeconds = (sets - 1) * restBetweenSets
        return workSeconds + restSeconds + setupTime
    }

    /// 時間フォーマット（秒 → MM:SS）
    ///
    /// - Parameter seconds: 秒数
    /// - Returns: フォーマットされた時間文字列（例: "05:30"）
    static func formatTime(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let remainingSeconds = seconds % 60
        return String(format: "%02d:%02d", minutes, remainingSeconds)
    }
}

// MARK: - Exercise Protocol

/// エクササイズ情報を表すプロトコル
/// WorkoutCalculationsで使用するための共通インターフェース
protocol ExerciseProtocol {
    var sets: String { get }
    var reps: String { get }
    var duration: String { get }
}
