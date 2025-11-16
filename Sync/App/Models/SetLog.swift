import Foundation

// MARK: - Set Log Model

/// ワークアウト中に記録する各セットの情報を保持する構造体。
/// exerciseIndex は day.exercises 内のエクササイズのインデックス、
/// setIndex は 1 から始まるセット番号を表す。
/// weightKg と reps はそれぞれユーザーが扱った重量(kg)と実施回数。
struct SetLog: Identifiable, Hashable {
    let id = UUID()
    let exerciseIndex: Int
    let setIndex: Int
    let weightKg: Double
    let reps: Int
}
