import Foundation
import SwiftData

// MARK: - Errors

public enum ProfileError: Error, Sendable {
    case notFound
    case persistenceFailed
    case encodingFailed
}

// MARK: - Remote sync abstraction

protocol RemoteProfileService: Sendable {
    func fetchProfile(id: UUID) async throws -> UserProfile?
    func pushProfile(_ profile: UserProfile) async throws
}

public final class NoopRemoteProfileService: RemoteProfileService, @unchecked Sendable {
    public static let shared = NoopRemoteProfileService()
    private init() {}
    public func fetchProfile(id: UUID) async throws -> UserProfile? { nil }
    public func pushProfile(_ profile: UserProfile) async throws {}
}

// MARK: - Repository API

public protocol SyncingProfileRepository: AnyObject {
    func getProfile() async throws -> UserProfile
    func updateName(_ name: String) async throws
    func updateAge(_ age: Int) async throws
    func updateGender(_ gender: Gender) async throws
    func updateBodyType(_ bodyType: BodyTypeModel) async throws
    func updateHeightCm(_ cm: Double) async throws
    func updateWeightKg(_ kg: Double) async throws
    func updateActivityLevel(_ level: ActivityLevelModel) async throws
    func updatePreferredActivities(_ activities: [String]) async throws
    func updateOwnedEquipments(_ equipments: [String]) async throws
    func updateGoal(_ goal: GoalProfile) async throws
    func updateWorkoutSchedule(_ schedule: WorkoutSchedule) async throws
    func saveTrainingPerWeek(_ value: Int) async throws

    func updateHeightIfPresent(_ cm: Double?) async throws
    func updateWeightIfPresent(_ kg: Double?) async throws
    func updatePreferredActivitiesIfPresent(_ activities: [String]?) async throws
    func updateOwnedEquipmentsIfPresent(_ equipments: [String]?) async throws

    func syncWithRemote() async
}

// MARK: - Default implementation

public final class DefaultSyncingProfileRepository: SyncingProfileRepository {

    private let remote: any RemoteProfileService
    private let context: ModelContext

    private init(context: ModelContext, remote: any RemoteProfileService) {
        self.context = context
        self.remote = remote
    }

    convenience init(context: ModelContext) {
        self.init(context: context, remote: NoopRemoteProfileService.shared)
    }

    public static func make(context: ModelContext) -> DefaultSyncingProfileRepository {
        DefaultSyncingProfileRepository(context: context)
    }

    @MainActor
    public static func makePreview() -> DefaultSyncingProfileRepository {
        let schema = Schema([
            UserProfileEntity.self,
            WeightLogEntity.self,
            OutboxItemEntity.self,
            AuditLogEntity.self
        ])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: schema, configurations: [config])
        let ctx = ModelContext(container)
        return DefaultSyncingProfileRepository(context: ctx)
    }

    // MARK: - Public API

    @MainActor
    public func getProfile() async throws -> UserProfile {
        let entity = try getOrCreateEntity()
        return entity.toUserProfile()
    }

    @MainActor
    public func updateName(_ name: String) async throws {
        let entity = try getOrCreateEntity()
        entity.name = name
        entity.updatedAt = .now
        try saveContext()
    }
    
    @MainActor
    public func updateAge(_ age: Int) async throws {
        let entity = try getOrCreateEntity()
        entity.age = age
        entity.updatedAt = .now
        try saveContext()
    }
    
    @MainActor
    public func updateGender(_ gender: Gender) async throws {
        let entity = try getOrCreateEntity()
        entity.gender = gender.rawValue
        entity.updatedAt = .now
        try saveContext()
    }
    
    @MainActor
    public func updateBodyType(_ bodyType: BodyTypeModel) async throws {
        let entity = try getOrCreateEntity()
        entity.bodyTypeData = try encodeJSON(bodyType)
        entity.updatedAt = .now
        try saveContext()
    }
    
    @MainActor
    public func updateHeightCm(_ cm: Double) async throws {
        let entity = try getOrCreateEntity()
        entity.heightCm = cm
        entity.updatedAt = .now
        try saveContext()
    }
    
    @MainActor
    public func updateWeightKg(_ kg: Double) async throws {
        let entity = try getOrCreateEntity()
        entity.weightKg = kg
        entity.updatedAt = .now
        try saveContext()
    }
    
    @MainActor
    public func updateActivityLevel(_ level: ActivityLevelModel) async throws {
        let entity = try getOrCreateEntity()
        entity.activityLevelData = try encodeJSON(level)
        entity.updatedAt = .now
        try saveContext()
    }
    
    @MainActor
    public func updatePreferredActivities(_ activities: [String]) async throws {
        let entity = try getOrCreateEntity()
        entity.preferredActivities = activities
        entity.updatedAt = .now
        try saveContext()
    }
    
    @MainActor
    public func updateOwnedEquipments(_ equipments: [String]) async throws {
        let entity = try getOrCreateEntity()
        entity.ownedEquipments = equipments
        entity.updatedAt = .now
        try saveContext()
    }
    
    @MainActor
    public func updateGoal(_ goal: GoalProfile) async throws {
        let entity = try getOrCreateEntity()
        entity.goalData = try encodeJSON(goal)
        entity.updatedAt = .now
        try saveContext()
    }
    
    @MainActor
    public func updateWorkoutSchedule(_ schedule: WorkoutSchedule) async throws {
        let entity = try getOrCreateEntity()
        entity.workoutScheduleData = try encodeJSON(schedule)
        entity.updatedAt = .now
        try saveContext()
    }

    @MainActor
    public func saveTrainingPerWeek(_ value: Int) async throws {
        let entity = try getOrCreateEntity()
        entity.trainingPerWeek = value
        entity.updatedAt = .now
        try saveContext()
    }

    @MainActor
    public func updateHeightIfPresent(_ cm: Double?) async throws {
        if let cm { try await updateHeightCm(cm) }
    }
    
    @MainActor
    public func updateWeightIfPresent(_ kg: Double?) async throws {
        if let kg { try await updateWeightKg(kg) }
    }
    
    @MainActor
    public func updatePreferredActivitiesIfPresent(_ activities: [String]?) async throws {
        if let activities { try await updatePreferredActivities(activities) }
    }
    
    @MainActor
    public func updateOwnedEquipmentsIfPresent(_ equipments: [String]?) async throws {
        if let equipments { try await updateOwnedEquipments(equipments) }
    }

    public func syncWithRemote() async {
        // 今はNoop
    }

    // MARK: - Private Helpers

    @MainActor
    private func fetchEntity() throws -> UserProfileEntity? {
        let fetch = FetchDescriptor<UserProfileEntity>(
            predicate: #Predicate { $0.userID == "singleton" }
        )
        return try context.fetch(fetch).first
    }

    @MainActor
    private func getOrCreateEntity() throws -> UserProfileEntity {
        if let existing = try fetchEntity() {
            return existing
        }
        
        let entity = UserProfileEntity(userID: "singleton", deviceID: "local")
        context.insert(entity)
        return entity
    }

    @MainActor
    private func saveContext() throws {
        do {
            try context.save()
        } catch {
            throw ProfileError.persistenceFailed
        }
    }
    
    private func encodeJSON<T: Encodable>(_ value: T) throws -> Data {
        do {
            return try JSONEncoder().encode(value)
        } catch {
            throw ProfileError.encodingFailed
        }
    }
}
