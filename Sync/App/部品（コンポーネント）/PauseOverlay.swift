import SwiftUI

// MARK: - Pause Overlay

/// An overlay that appears when the workout is paused
struct PauseOverlay: View {
    let percent: Int
    let remainingCount: Int
    let onResume: () -> Void
    let onRestart: () -> Void
    let onQuit: () -> Void

    var body: some View {
        ZStack {
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                Text("がんばりましょう!\nあなたならできる!")
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)

                VStack(alignment: .leading, spacing: 6) {
                    Text("あなたは\(percent)%を終了しました")
                        .font(.title3)
                        .foregroundStyle(.secondary)

                    Text("残りあと\(remainingCount)個のエクササイズ")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(Color(red: 124.0/255.0, green: 77.0/255.0, blue: 255.0/255.0))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, 20)

                StartPrimaryButton(title: "再開", action: onResume)
                    .frame(maxWidth: .infinity)

                Button("エクササイズを最初から始める", action: onRestart)
                    .buttonStyle(.plain)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Color(red: 124.0/255.0, green: 77.0/255.0, blue: 255.0/255.0))
                    .frame(height: 60)
                    .frame(maxWidth: .infinity)
                    .padding(.top, -2)
                    .contentShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
                    .background(
                        RoundedRectangle(cornerRadius: 32, style: .continuous)
                            .fill(Color(.systemGray6))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 32, style: .continuous)
                            .strokeBorder(Color(.quaternaryLabel), lineWidth: 0.7)
                    )

                Button("やめる", action: onQuit)
                    .buttonStyle(.plain)
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .padding(.top, 2)
            }
            .padding(.horizontal, 28)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        }
    }
}
