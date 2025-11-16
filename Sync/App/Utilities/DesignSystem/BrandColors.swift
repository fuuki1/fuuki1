import SwiftUI

// MARK: - Brand Colors

/// 統一されたブランドカラー定義
/// アプリ全体で一貫したカラーパレットを提供します
extension Color {
    // MARK: - Primary Brand Colors

    /// メインブランドカラー: #7C4DFF (Purple)
    /// 使用箇所: ボタン、アクセント、選択状態、プログレスインジケーター
    static let brandPurple = Color(red: 124.0/255.0, green: 77.0/255.0, blue: 255.0/255.0)

    /// Syncグリーン: #63C465
    /// 使用箇所: 成功状態、完了表示、アクティビティリング
    static let syncGreen = Color(red: 99.0/255.0, green: 196.0/255.0, blue: 101.0/255.0)

    // MARK: - Background Colors

    /// ライトパープル背景: #EDE7FF
    /// 使用箇所: カードの背景、グラスエフェクト
    static let lightPurpleBackground = Color(red: 237.0/255.0, green: 231.0/255.0, blue: 255.0/255.0)

    /// ソフトパープル背景: #F4ECFF
    /// 使用箇所: グラデーション背景、サブビュー背景
    static let softPurpleBackground = Color(red: 244.0/255.0, green: 236.0/255.0, blue: 255.0/255.0)

    // MARK: - Dark Theme Colors

    /// ダークブルー背景: #1F2340
    /// 使用箇所: カレンダー、ダークモード背景
    static let darkBlueBackground = Color(red: 31.0/255.0, green: 35.0/255.0, blue: 64.0/255.0)

    /// ミッドナイトブルー: #1E2030
    /// 使用箇所: 今日のインジケーター背景
    static let midnightBlue = Color(red: 30.0/255.0, green: 32.0/255.0, blue: 48.0/255.0)

    // MARK: - Accent Colors

    /// オレンジアクセント: ワークアウトインジケーター
    static let workoutIndicatorOrange = Color(red: 1.0, green: 0.6, blue: 0.4)

    // MARK: - Brand Color Variations

    /// ブランドカラーのライトバリエーション (95, 134, 255)
    static let brandPurpleLight = Color(red: 95.0/255.0, green: 134.0/255.0, blue: 255.0/255.0)

    /// ブランドカラーの中間バリエーション (107, 94, 255)
    static let brandPurpleMid = Color(red: 107.0/255.0, green: 94.0/255.0, blue: 255.0/255.0)

    /// ブランドカラーのダークバリエーション (140, 84, 255)
    static let brandPurpleDark = Color(red: 140.0/255.0, green: 84.0/255.0, blue: 255.0/255.0)
}
