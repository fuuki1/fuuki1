import UIKit

// MARK: - Haptics Helper

/// Centralized haptic feedback helper
enum Haptics {
    /// Plays a medium impact haptic feedback
    static func tick() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }

    /// Plays a light impact haptic feedback
    static func lightTick() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }

    /// Plays a heavy impact haptic feedback
    static func heavyTick() {
        let generator = UIImpactFeedbackGenerator(style: .heavy)
        generator.impactOccurred()
    }

    /// Prepares the haptic engine for upcoming feedback
    static func prepare() {
        UIImpactFeedbackGenerator(style: .medium).prepare()
    }

    /// Plays a selection haptic feedback
    static func selection() {
        let generator = UISelectionFeedbackGenerator()
        generator.selectionChanged()
    }

    /// Plays a notification haptic feedback
    static func notification(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(type)
    }
}
