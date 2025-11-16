import SwiftUI

// MARK: - Animated Gradient Background

/// An animated gradient background with multiple layers
struct AnimatedGradientBackground: View {
    @State private var animationPhase: Double = 0

    var body: some View {
        TimelineView(.animation) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate

            ZStack {
                MeshGradientLayer(
                    colors: [
                        Color(red: 200/255, green: 180/255, blue: 255/255),
                        Color(red: 124/255, green: 77/255, blue: 255/255),
                        Color(red: 60/255, green: 70/255, blue: 220/255),
                    ],
                    time: time,
                    speed: 0.3,
                    offset: 0
                )

                MeshGradientLayer(
                    colors: [
                        Color(red: 170/255, green: 150/255, blue: 240/255),
                        Color(red: 107/255, green: 94/255, blue: 255/255),
                        Color(red: 50/255, green: 80/255, blue: 200/255),
                    ],
                    time: time,
                    speed: 0.4,
                    offset: 120
                )
                .opacity(0.7)

                MeshGradientLayer(
                    colors: [
                        Color(red: 220/255, green: 200/255, blue: 255/255),
                        Color(red: 180/255, green: 140/255, blue: 250/255),
                        Color(red: 140/255, green: 84/255, blue: 255/255),
                    ],
                    time: time,
                    speed: 0.5,
                    offset: 240
                )
                .opacity(0.5)
                .blendMode(.screen)
            }
        }
        .ignoresSafeArea()
    }
}

/// A single layer of mesh gradient that animates based on time
private struct MeshGradientLayer: View {
    let colors: [Color]
    let time: Double
    let speed: Double
    let offset: Double

    var body: some View {
        let phase = time * speed + offset

        let startX = 0.5 + 0.3 * cos(phase)
        let startY = 0.5 + 0.3 * sin(phase)
        let endX = 0.5 + 0.3 * cos(phase + .pi)
        let endY = 0.5 + 0.3 * sin(phase + .pi)

        LinearGradient(
            gradient: Gradient(colors: colors),
            startPoint: UnitPoint(x: startX, y: startY),
            endPoint: UnitPoint(x: endX, y: endY)
        )
    }
}

/// Enhanced animated background with pulse and light band effects
struct EnhancedAnimatedBackground: View {
    let pulseScale: CGFloat
    let lightBandOffset: CGFloat

    var body: some View {
        ZStack {
            AnimatedGradientBackground()
                .scaleEffect(pulseScale)
        }
        .ignoresSafeArea()
    }
}

// MARK: - Arrow Animations

/// Animated dots arrow view
struct AnimatedDotsArrowView: View {
    @State private var opacity: Double = 0

    private let dotPositions: [(x: CGFloat, y: CGFloat)] = [
        (0.3, 0.2), (0.4, 0.3), (0.5, 0.4), (0.6, 0.5),
        (0.5, 0.6), (0.4, 0.7), (0.3, 0.8)
    ]

    private let dotColor = Color.white
    private let dotSize: CGFloat = 5

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(0..<dotPositions.count, id: \.self) { index in
                    let pos = dotPositions[index]

                    Circle()
                        .fill(dotColor)
                        .frame(width: dotSize, height: dotSize)
                        .position(
                            x: geometry.size.width * pos.x,
                            y: geometry.size.height * pos.y
                        )
                }
            }
        }
        .opacity(opacity)
        .onAppear {
            withAnimation(.easeIn(duration: 0.3)) {
                opacity = 1
            }
        }
    }
}

/// Chevron arrow shape
private struct ChevronArrowShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let inset = min(rect.width, rect.height) * 0.06
        let minX = rect.minX + inset
        let maxX = rect.maxX - inset
        let minY = rect.minY + inset
        let maxY = rect.maxY - inset
        let midY = rect.midY

        path.move(to: CGPoint(x: minX, y: minY))
        path.addLine(to: CGPoint(x: maxX, y: midY))
        path.addLine(to: CGPoint(x: minX, y: maxY))
        return path
    }
}

/// Arrow shape view with configurable direction
struct ArrowShapeView: View {
    enum Direction { case left, right }
    var direction: Direction = .right
    var lineWidth: CGFloat = 12.0
    var color: Color = .white

    var body: some View {
        ChevronArrowShape()
            .stroke(
                color,
                style: StrokeStyle(
                    lineWidth: lineWidth,
                    lineCap: .square,
                    lineJoin: .miter,
                    miterLimit: 2
                )
            )
            .scaleEffect(x: direction == .right ? 1 : -1, y: 1)
    }
}

/// Arrow layout constants
enum ArrowLayout {
    static var dotSize: CGFloat = 64
    static var dotSpacing: CGFloat = -50
    static var groupToPhotoGap: CGFloat = -49
    static var photoSize: CGFloat = 80
}
