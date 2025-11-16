import SwiftUI

/// オンボーディングフローのナビゲーション制御を一元管理
/// 連打防止・二重遷移防止のためのゲートキーパー
@MainActor
@Observable
class FlowGate {
    /// 遷移中フラグ（連打防止）
    private(set) var isNavigating: Bool = false
    
    /// 遷移を試行。すでに遷移中なら無視
    func navigate(_ action: () -> Void) {
        guard !isNavigating else {
            print("⚠️ [FlowGate] Already navigating, ignoring")
            return
        }
        
        print("🔓 [FlowGate] Navigation started")
        isNavigating = true
        
        // 同期的に実行
        action()
        
        // 次のフレームで解除
        DispatchQueue.main.async {
            self.isNavigating = false
            print("🔒 [FlowGate] Navigation finished")
        }
    }
    
    /// 手動でゲートをリセット（エラー時など）
    func reset() {
        isNavigating = false
    }
}
