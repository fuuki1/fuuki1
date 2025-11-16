import Foundation
import SwiftData

// MARK: - User Preferences Manager

/// ユーザー設定の永続化と取得を管理するユーティリティ
/// UserDefaultsとSwiftDataの両方からユーザー情報を取得します
enum UserPreferences {
    // MARK: - User Weight

    /// 現在のユーザー体重（kg）を取得
    ///
    /// 優先順位:
    /// 1. SwiftData（ModelContext）から最新の体重ログを取得
    /// 2. UserDefaultsのweightKgを取得
    /// 3. デフォルト値: 60.0kg
    ///
    /// - Parameter modelContext: SwiftDataのModelContext（オプション）
    /// - Returns: ユーザー体重（kg）
    static func currentWeightKg(from modelContext: ModelContext? = nil) -> Double {
        // SwiftDataから最新の体重ログを取得
        if let context = modelContext {
            var descriptor = FetchDescriptor<WeightLogEntity>()
            descriptor.sortBy = [SortDescriptor(\.recordDate, order: .reverse)]

            if let logs = try? context.fetch(descriptor),
               let latest = logs.first {
                return latest.weightKg
            }
        }

        // UserDefaultsから取得
        let saved = UserDefaults.standard.double(forKey: "weightKg")
        return saved > 0 ? saved : 60.0
    }

    /// ユーザー体重を保存
    /// - Parameter weight: 体重（kg）
    static func saveWeight(_ weight: Double) {
        UserDefaults.standard.set(weight, forKey: "weightKg")
    }

    // MARK: - Favorite Exercises

    /// お気に入りエクササイズのリストを取得
    /// - Returns: お気に入りエクササイズ名の配列
    static func loadFavoriteExercises() -> [String] {
        UserDefaults.standard.stringArray(forKey: "favoriteExercises") ?? []
    }

    /// お気に入りエクササイズのリストを保存
    /// - Parameter exercises: お気に入りエクササイズ名の配列
    static func saveFavoriteExercises(_ exercises: [String]) {
        UserDefaults.standard.set(exercises, forKey: "favoriteExercises")
    }

    /// エクササイズをお気に入りに追加
    /// - Parameter exercise: エクササイズ名
    static func addFavoriteExercise(_ exercise: String) {
        var favorites = loadFavoriteExercises()
        if !favorites.contains(exercise) {
            favorites.append(exercise)
            saveFavoriteExercises(favorites)
        }
    }

    /// エクササイズをお気に入りから削除
    /// - Parameter exercise: エクササイズ名
    static func removeFavoriteExercise(_ exercise: String) {
        var favorites = loadFavoriteExercises()
        favorites.removeAll { $0 == exercise }
        saveFavoriteExercises(favorites)
    }

    /// エクササイズがお気に入りに含まれているか確認
    /// - Parameter exercise: エクササイズ名
    /// - Returns: お気に入りに含まれている場合true
    static func isFavoriteExercise(_ exercise: String) -> Bool {
        loadFavoriteExercises().contains(exercise)
    }
}
