import Foundation

public struct ProfileSnapshot: Sendable {
    public var name: String?
    public var gender: String?
    public var age: Int?
    public var heightCm: Double?
    public var weightKg: Double?
    public var goal: GoalProfile?

    public init(
        name: String? = nil,
        gender: String? = nil,
        age: Int? = nil,
        heightCm: Double? = nil,
        weightKg: Double? = nil,
        goal: GoalProfile? = nil
    ) {
        self.name = name
        self.gender = gender
        self.age = age
        self.heightCm = heightCm
        self.weightKg = weightKg
        self.goal = goal
    }
}
