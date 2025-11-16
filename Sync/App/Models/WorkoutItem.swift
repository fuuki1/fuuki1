import Foundation

// MARK: - Workout Item Model

/// Represents a single workout item with its properties
struct WorkoutItem: Identifiable {
    let id = UUID()
    let name: String
    let calories: Double
    let displayUnit: String
    let mets: Double
    let tags: [String]
    let bodyPart: String
}
