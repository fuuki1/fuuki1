import Foundation

enum WeightUnit: String, CaseIterable, Codable, Sendable {
    case kg, lbs

    static let lbsPerKg = 2.2046226218

    func toKg(_ value: Double) -> Double { self == .kg ? value : value / Self.lbsPerKg }
    func fromKg(_ kg: Double) -> Double { self == .kg ? kg    : kg * Self.lbsPerKg }
}
