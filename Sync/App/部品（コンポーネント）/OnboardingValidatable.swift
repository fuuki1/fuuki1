import SwiftUI

/// オンボーディングステップのバリデーション要件を定義
protocol OnboardingValidatable {
    /// 現在のステップが有効（次へ進める）かどうか
    var isStepValid: Bool { get }
}

/// デフォルト実装：常に有効（イントロ画面など）
extension OnboardingValidatable {
    var isStepValid: Bool { true }
}
