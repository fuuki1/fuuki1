import SwiftUI

// MARK: - Brand Gradients

/// 統一されたグラデーション定義
/// アプリ全体で一貫したグラデーションスタイルを提供します
extension LinearGradient {
    // MARK: - Primary Gradients

    /// メインブランドグラデーション
    /// 使用箇所: ボタン、ヘッダー、カード背景
    static let brandPrimary = LinearGradient(
        colors: [
            Color(red: 95.0/255.0, green: 134.0/255.0, blue: 1.0),
            Color(red: 124.0/255.0, green: 77.0/255.0, blue: 1.0)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// 3ストップブランドグラデーション
    /// 使用箇所: ステップチップ、選択された要素
    static let brandTriple = LinearGradient(
        gradient: Gradient(stops: [
            .init(color: Color(red: 107.0/255.0, green: 94.0/255.0, blue: 255.0/255.0), location: 0.0),
            .init(color: Color(red: 124.0/255.0, green: 77.0/255.0, blue: 255.0/255.0), location: 0.62),
            .init(color: Color(red: 140.0/255.0, green: 84.0/255.0, blue: 255.0/255.0), location: 0.94)
        ]),
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    // MARK: - Background Gradients

    /// ソフトパープル背景グラデーション
    /// 使用箇所: ビュー背景、カード背景
    static let softPurpleBackground = LinearGradient(
        gradient: Gradient(colors: [
            Color(red: 244.0/255.0, green: 236.0/255.0, blue: 255.0/255.0),
            Color.white
        ]),
        startPoint: .top,
        endPoint: .bottom
    )

    /// ライトパープル背景グラデーション
    /// 使用箇所: セクション背景
    static let lightPurpleBackground = LinearGradient(
        gradient: Gradient(colors: [
            Color(red: 237.0/255.0, green: 231.0/255.0, blue: 255.0/255.0),
            Color.white.opacity(0.5)
        ]),
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

// MARK: - Gradient Convenience

/// グラデーション関連のユーティリティ
extension Color {
    /// ブランドグラデーションをLinearGradientとして提供
    static let brandGradient = LinearGradient.brandPrimary
}
