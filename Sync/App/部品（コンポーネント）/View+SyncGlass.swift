import SwiftUI

extension View {
    /// Syncアプリ統一のガラスエフェクト
    /// 使用例: .syncGlass(cornerRadius: 16)
    func syncGlass(cornerRadius: CGFloat = 16) -> some View {
        self
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .strokeBorder(.white.opacity(0.08), lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(0.10), radius: 12, x: 0, y: 6)
                    .shadow(color: Color.black.opacity(0.04), radius: 4, x: 0, y: 1)
            )
    }
    
    /// ShapeStyleを受け取るバージョン（in: パラメータ互換）
    func syncGlass<S: InsettableShape>(in shape: S) -> some View {
        self
            .background(
                shape
                    .fill(.ultraThinMaterial)
                    .overlay(
                        shape.strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(0.10), radius: 12, x: 0, y: 6)
                    .shadow(color: Color.black.opacity(0.04), radius: 4, x: 0, y: 1)
            )
    }
}
