import SwiftUI

// MARK: - Part Progress Bar

/// A progress bar component for showing progress through different parts
struct PartProgressBar: View {
    var progress: Double
    var isActive: Bool
    var isCompleted: Bool

    private var clamped: CGFloat { CGFloat(min(max(progress, 0), 1)) }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(isCompleted ? Color.customPurple.opacity(0.3) : Color.customPurple.opacity(0.18))

                Capsule()
                    .fill(Color.customPurple)
                    .frame(width: geo.size.width * clamped)
            }
        }
        .frame(height: 6)
        .drawingGroup()
        .animation(.easeInOut(duration: 0.22), value: progress)
    }
}
