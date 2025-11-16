import SwiftUI

// MARK: - View Extensions

extension View {
    /// Applies a glass effect with shadows
    func glassEffect() -> some View {
        self
            .shadow(color: Color.black.opacity(0.15), radius: 20, x: 0, y: 8)
            .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
    }

    /// Applies a glass effect to a specific shape
    func glassEffect<S: Shape>(in shape: S) -> some View {
        self
            .background(shape.fill(.clear))
            .shadow(color: Color.black.opacity(0.15), radius: 20, x: 0, y: 8)
            .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
    }

    /// Applies a liquid glass effect to a specific insettable shape with optional selection state
    func liquidGlassEffect(in shape: some InsettableShape, isSelected: Bool = false) -> some View {
        self
            .background {
                if isSelected {
                    shape
                        .fill(Color.brandGradient)
                } else {
                    shape
                        .fill(Color(UIColor.systemGray6))
                }
            }
            .shadow(
                color: isSelected
                    ? Color(red: 124.0/255.0, green: 77.0/255.0, blue: 255.0/255.0).opacity(0.5)
                    : Color.black.opacity(0.08),
                radius: isSelected ? 12 : 20,
                x: 0,
                y: isSelected ? 4 : 8
            )
            .shadow(
                color: isSelected
                    ? Color(red: 124.0/255.0, green: 77.0/255.0, blue: 255.0/255.0).opacity(0.3)
                    : Color.black.opacity(0.04),
                radius: isSelected ? 6 : 4,
                x: 0,
                y: 2
            )
    }
}

// MARK: - Press Events Modifier

extension View {
    /// Adds press and release event handlers to a view
    func pressEvents(onPress: @escaping () -> Void, onRelease: @escaping () -> Void) -> some View {
        modifier(PressEventsModifier(onPress: onPress, onRelease: onRelease))
    }
}

private struct PressEventsModifier: ViewModifier {
    let onPress: () -> Void
    let onRelease: () -> Void

    func body(content: Content) -> some View {
        content
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in onPress() }
                    .onEnded { _ in onRelease() }
            )
    }
}
