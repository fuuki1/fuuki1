import Foundation
import Combine
import HealthKit

struct ActivityProgress {
    let move: Double
    let exercise: Double
    let stand: Double

    // ✅ データが無い場合のデフォルト
    static var zero: ActivityProgress { .init(move: 0, exercise: 0, stand: 0) }
}

@MainActor
class ActivityDataManager: ObservableObject {
    
    // ✅ シングルトンインスタンス
    static let shared = ActivityDataManager()
    
    private let healthStore = HKHealthStore()
    private let calendar = Calendar(identifier: .gregorian)
    
    // 読み取りたいデータ型（WeeklyBurnCardが本当に必要なもの）
    private let readTypes: Set<HKObjectType> = [
        HKObjectType.activitySummaryType(),
        HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!,
        HKObjectType.quantityType(forIdentifier: .appleExerciseTime)!,
        HKObjectType.quantityType(forIdentifier: .stepCount)!,
        HKObjectType.workoutType(),
        HKObjectType.quantityType(forIdentifier: .heartRate)!,
        HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!,
        HKObjectType.quantityType(forIdentifier: .restingHeartRate)!,
        HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!,
        HKObjectType.categoryType(forIdentifier: .appleStandHour)!,
        HKObjectType.quantityType(forIdentifier: .dietaryEnergyConsumed)!,
        HKObjectType.quantityType(forIdentifier: .dietaryProtein)!,
        HKObjectType.quantityType(forIdentifier: .dietaryFatTotal)!,
        HKObjectType.quantityType(forIdentifier: .dietaryCarbohydrates)!,
        HKObjectType.quantityType(forIdentifier: .dietaryWater)!
    ]
    
    @Published var exerciseGoalMinutes: Int? = 30 // デフォルト値
    @Published var activityData: [Date: ActivityProgress] = [:]
    @Published var isAuthorized: Bool = false
    
    // ✅ イニシャライザ（シングルトンとしても使えるし、新規インスタンスも作成可能）
    init() {}
    
    // MARK: - 認証リクエスト
    
    /// HealthKitの認証を要求する（ExerciseDatabaseViewから呼ばれる）
    func requestAuthorization() {
        guard HKHealthStore.isHealthDataAvailable() else {
            print("❌ HealthKit is not available on this device.")
            self.isAuthorized = false
            return
        }
        
        // 読み取り権限をリクエスト
        healthStore.requestAuthorization(toShare: nil, read: readTypes) { [weak self] success, error in
            Task { @MainActor [weak self] in
                guard let self else { return }
                
                if let error {
                    print("❌ HealthKit authorization error: \(error.localizedDescription)")
                    self.isAuthorized = false
                    return
                }
                
                if success {
                    print("✅ HealthKit authorization granted.")
                    self.checkAuthorization()
                } else {
                    print("⚠️ HealthKit authorization was not granted.")
                    self.isAuthorized = false
                }
            }
        }
    }
    
    // MARK: - 許可ステータスの確認
    
    func checkAuthorization() {
        guard HKHealthStore.isHealthDataAvailable() else {
            print("❌ HealthKit is not available on this device.")
            self.isAuthorized = false
            return
        }

        var allAuthorized = true
        var firstMissingType: String = ""

        for type in self.readTypes {
            let status = healthStore.authorizationStatus(for: type)
            if status != .sharingAuthorized {
                allAuthorized = false
                firstMissingType = type.identifier
                break
            }
        }

        self.isAuthorized = allAuthorized

        if allAuthorized {
            print("✅ HealthKit authorization: All types authorized.")
            Task { await self.fetchWeeklyData(startDate: Date()) }
        } else {
            print("⚠️ HealthKit authorization: Not all types are authorized. First missing: \(firstMissingType)")
        }
    }
    
    // MARK: - データ取得（公開API）
    
    /// アクティビティデータを取得する（ExerciseDatabaseViewから呼ばれる）
    func fetchActivityData() {
        Task {
            await fetchWeeklyData(startDate: Date())
        }
    }
    
    // MARK: - 週次データ取得（内部実装）
    
    func fetchWeeklyData(startDate: Date) async {
        // 許可がない場合はデータを取得しない
        guard isAuthorized else {
            print("⚠️ Not authorized, skipping data fetch.")
            return
        }
        
        // グレゴリオ暦で、startDateの週の日曜日（週の開始日）を取得
        guard let startOfWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: startDate)) else {
            return
        }
        
        // 取得範囲：その週の日曜日から土曜日まで
        let predicate = HKQuery.predicate(
            forActivitySummariesBetweenStart: calendar.dateComponents([.year, .month, .day], from: startOfWeek),
            end: calendar.dateComponents([.year, .month, .day], from: calendar.date(byAdding: .day, value: 7, to: startOfWeek) ?? startOfWeek)
        )
        
        // HKActivitySummaryQuery を作成
        let query = HKActivitySummaryQuery(predicate: predicate) { [weak self] _, summaries, error in
            guard let self, let summaries, !summaries.isEmpty else {
                if let error {
                    print("❌ Activity summary query error: \(error.localizedDescription)")
                }
                // データがなくても空の辞書でUIを更新（古いデータをクリア）
                Task { [weak self] in
                    if let self { await self.updateActivityData(with: [:]) }
                }
                return
            }
            
            var weeklyData: [Date: ActivityProgress] = [:]
            
            for summary in summaries {
                // サマリーから日付を取得
                guard let date = self.calendar.date(from: summary.dateComponents(for: self.calendar)) else { continue }
                
                // 各目標値（Goal）を取得
                let moveGoal = summary.activeEnergyBurnedGoal.doubleValue(for: .kilocalorie())
                let exerciseGoal = summary.appleExerciseTimeGoal.doubleValue(for: .minute())
                let standGoal = summary.appleStandHoursGoal.doubleValue(for: .count())
                
                // 各実績値（Burned/Done）を取得
                let moveValue = summary.activeEnergyBurned.doubleValue(for: .kilocalorie())
                let exerciseValue = summary.appleExerciseTime.doubleValue(for: .minute())
                let standValue = summary.appleStandHours.doubleValue(for: .count())
                
                // 進捗率を計算 (0除算を避ける)
                let moveProgress = (moveGoal > 0) ? min(1.0, moveValue / moveGoal) : 0
                let exerciseProgress = (exerciseGoal > 0) ? min(1.0, exerciseValue / exerciseGoal) : 0
                let standProgress = (standGoal > 0) ? min(1.0, standValue / standGoal) : 0
                
                // 辞書に格納
                weeklyData[date] = ActivityProgress(
                    move: moveProgress,
                    exercise: exerciseProgress,
                    stand: standProgress
                )
            }
            
            // データを@Published varにセット（メインスレッドで実行）
            Task { await self.updateActivityData(with: weeklyData) }
        }
        
        // クエリを実行
        healthStore.execute(query)
    }
    
    // MARK: - データ更新（メインスレッド）
    
    // メインスレッドで@Published varを更新するためのヘルパー
    @MainActor
    private func updateActivityData(with data: [Date: ActivityProgress]) {
        self.activityData = data
        print("✅ Updated activity data for \(data.count) days.")
    }
}
