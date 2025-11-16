import Foundation
import Combine

@MainActor
class CalendarLogicManager: ObservableObject {
    
    @Published var weekOffset: Int = 0 // 0 = 今週, -1 = 先週, 1 = 来週
    @Published var weekDates: [Date] = []
    
    private let calendar = Calendar(identifier: .gregorian)
    let dataManager: ActivityDataManager // ✅ non-optionalに変更
    
    init(dataManager: ActivityDataManager) { // ✅ 必須パラメータに変更
        self.dataManager = dataManager
        self.weekDates = generateWeekDates(for: weekOffset)
    }
    
    // MARK: - Week Navigation
    
    func moveToNextWeek() {
        weekOffset += 1
        weekDates = generateWeekDates(for: weekOffset)
        
        Task {
            await dataManager.fetchWeeklyData(startDate: weekDates.first ?? Date())
        }
    }
    
    // ✅ WeeklyBurnCardで使われているメソッド名を追加
    func goToNextWeek() {
        moveToNextWeek()
    }
    
    func moveToPreviousWeek() {
        weekOffset -= 1
        weekDates = generateWeekDates(for: weekOffset)
        
        Task {
            await dataManager.fetchWeeklyData(startDate: weekDates.first ?? Date())
        }
    }
    
    // ✅ WeeklyBurnCardで使われているメソッド名を追加
    func goToPreviousWeek() {
        moveToPreviousWeek()
    }
    
    func resetToCurrentWeek() {
        weekOffset = 0
        weekDates = generateWeekDates(for: weekOffset)
    }
    
    // ✅ WeeklyBurnCardで使われているactivateメソッドを追加
    func activate() {
        // 初期データを読み込む
        Task {
            await dataManager.fetchWeeklyData(startDate: weekDates.first ?? Date())
        }
    }
    
    // MARK: - Date Generation
    
    private func generateWeekDates(for offset: Int) -> [Date] {
        var dates: [Date] = []
        
        // 今日の日付を取得
        let today = calendar.startOfDay(for: Date())
        
        // 今週の開始日（日曜日）を取得
        guard let startOfThisWeek = calendar.date(
            from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today)
        ) else {
            return dates
        }
        
        // オフセットを適用した週の開始日を計算
        guard let startOfTargetWeek = calendar.date(
            byAdding: .weekOfYear,
            value: offset,
            to: startOfThisWeek
        ) else {
            return dates
        }
        
        // その週の日曜日から土曜日までの7日間を生成
        for i in 0..<7 {
            if let date = calendar.date(byAdding: .day, value: i, to: startOfTargetWeek) {
                dates.append(date)
            }
        }
        
        return dates
    }
}
