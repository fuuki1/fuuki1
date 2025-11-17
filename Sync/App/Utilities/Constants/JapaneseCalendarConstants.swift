import Foundation

// MARK: - Japanese Calendar Constants

/// 日本語カレンダー関連の定数
enum JapaneseCalendarConstants {
    // MARK: - Weekday Symbols

    /// 曜日シンボル（月曜始まり）
    /// 使用箇所: カレンダービュー、スケジュール選択
    static let weekdaySymbols = ["月", "火", "水", "木", "金", "土", "日"]

    /// 曜日シンボル（日曜始まり）
    /// 使用箇所: 日本の標準カレンダー表示
    static let weekdaySymbolsSundayFirst = ["日", "月", "火", "水", "木", "金", "土"]

    // MARK: - Month Names

    /// 月名（短縮形）
    static let shortMonthNames = ["1月", "2月", "3月", "4月", "5月", "6月",
                                   "7月", "8月", "9月", "10月", "11月", "12月"]

    /// 月名（フル）
    static let fullMonthNames = ["1月", "2月", "3月", "4月", "5月", "6月",
                                  "7月", "8月", "9月", "10月", "11月", "12月"]

    // MARK: - Era Names

    /// 年号
    enum Era {
        case reiwa
        case heisei
        case showa

        var name: String {
            switch self {
            case .reiwa: return "令和"
            case .heisei: return "平成"
            case .showa: return "昭和"
            }
        }
    }
}
