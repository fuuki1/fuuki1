import Foundation

// MARK: - Exercise Parser

/// エクササイズ情報のパースと抽出を行うユーティリティ
enum ExerciseParser {
    // MARK: - Set Extraction

    /// セット数を文字列から抽出
    ///
    /// 例:
    /// - "3セット" → 3
    /// - "4 sets" → 4
    /// - "5" → 5
    ///
    /// - Parameter text: セット数を含む文字列
    /// - Returns: 抽出されたセット数、見つからない場合は1
    static func extractSets(from text: String) -> Int {
        let pattern = #"(\d+)"#
        if let match = text.range(of: pattern, options: .regularExpression),
           let count = Int(text[match]) {
            return count
        }
        return 1
    }

    // MARK: - Duration Parsing

    /// 日本語の時間表記をパース（秒に変換）
    ///
    /// サポート形式:
    /// - "3分" → 180秒
    /// - "30秒" → 30秒
    /// - "3分30秒" → 210秒
    /// - "1時間" → 3600秒
    /// - "1時間30分" → 5400秒
    ///
    /// - Parameter text: 時間を表す日本語文字列
    /// - Returns: 秒数、パース失敗時は0
    static func parseDurationToSeconds(_ text: String) -> Int {
        var totalSeconds = 0

        // 時間の抽出
        if let hoursMatch = text.range(of: #"(\d+)時間"#, options: .regularExpression) {
            let hoursText = text[hoursMatch]
            if let hours = Int(hoursText.replacingOccurrences(of: "時間", with: "")) {
                totalSeconds += hours * 3600
            }
        }

        // 分の抽出
        if let minutesMatch = text.range(of: #"(\d+)分"#, options: .regularExpression) {
            let minutesText = text[minutesMatch]
            if let minutes = Int(minutesText.replacingOccurrences(of: "分", with: "")) {
                totalSeconds += minutes * 60
            }
        }

        // 秒の抽出
        if let secondsMatch = text.range(of: #"(\d+)秒"#, options: .regularExpression) {
            let secondsText = text[secondsMatch]
            if let seconds = Int(secondsText.replacingOccurrences(of: "秒", with: "")) {
                totalSeconds += seconds
            }
        }

        return totalSeconds
    }

    // MARK: - Number Extraction

    /// 文字列から最初の整数を抽出
    ///
    /// 例:
    /// - "10回" → 10
    /// - "Weight: 50kg" → 50
    /// - "abc123def456" → 123
    ///
    /// - Parameter text: 整数を含む文字列
    /// - Returns: 最初に見つかった整数、見つからない場合はnil
    static func firstInt(from text: String) -> Int? {
        let pattern = #"\d+"#
        if let match = text.range(of: pattern, options: .regularExpression) {
            return Int(text[match])
        }
        return nil
    }

    /// 正規表現パターンにマッチする整数を抽出
    ///
    /// - Parameters:
    ///   - text: 対象文字列
    ///   - pattern: 正規表現パターン
    /// - Returns: マッチした整数、見つからない場合はnil
    static func matchInt(in text: String, pattern: String) -> Int? {
        if let match = text.range(of: pattern, options: .regularExpression) {
            let matched = text[match]
            let digits = matched.filter { $0.isNumber }
            return Int(digits)
        }
        return nil
    }

    // MARK: - Digits Extraction

    /// 文字列から数字のみを抽出
    ///
    /// 例:
    /// - "abc123def456" → "123456"
    /// - "Weight: 50kg" → "50"
    ///
    /// - Parameter text: 対象文字列
    /// - Returns: 数字のみの文字列
    static func extractDigits(from text: String) -> String {
        text.filter { $0.isNumber }
    }

    // MARK: - Equipment Inference

    /// エクササイズ名から使用器具を推測
    ///
    /// - Parameter exerciseName: エクササイズ名
    /// - Returns: 使用器具（例: "ダンベル", "バーベル", "自重"）
    static func inferEquipment(from exerciseName: String) -> String {
        let lower = exerciseName.lowercased()
        if lower.contains("ダンベル") || lower.contains("dumbbell") {
            return "ダンベル"
        } else if lower.contains("バーベル") || lower.contains("barbell") {
            return "バーベル"
        } else if lower.contains("ケトルベル") || lower.contains("kettlebell") {
            return "ケトルベル"
        } else if lower.contains("マシン") || lower.contains("machine") {
            return "マシン"
        } else if lower.contains("バンド") || lower.contains("band") {
            return "バンド"
        } else {
            return "自重"
        }
    }
}
