// Models.swift — updated for SwiftData best practices (iOS 18+)
import Foundation
import SwiftData

@Model
final class UserProfileEntity {
    // Uniqueness & indexes for fast lookups and sync logic
    #Unique<UserProfileEntity>([\.userID])
    #Index<UserProfileEntity>([\.userID], [\.updatedAt])

    var userID: String
    var deviceID: String
    var updatedAt: Date
    var version: Int

    // ========================================
    // 基本情報（個別フィールド）
    // ========================================
    var name: String?
    var gender: String? // Gender.rawValue を保存
    var age: Int?
    var heightCm: Double?
    var weightKg: Double?
    
    // ========================================
    // 複雑なモデル（JSONエンコードして保存）
    // ========================================
    var bodyTypeData: Data? // BodyTypeModel
    var activityLevelData: Data? // ActivityLevelModel
    var goalData: Data? // GoalProfile
    var workoutScheduleData: Data? // WorkoutSchedule
    
    // ========================================
    // 配列フィールド
    // ========================================
    var preferredActivities: [String]?
    var ownedEquipments: [String]?
    
    // ========================================
    // その他
    // ========================================
    var trainingPerWeek: Int?
    
    // ========================================
    // 旧フィールド（後方互換性のため残す）
    // ========================================
    @available(*, deprecated, message: "個別フィールドを使用してください")
    var goalTypeRaw: String?
    @available(*, deprecated, message: "個別フィールドを使用してください")
    var goalWeightKg: Double?
    @available(*, deprecated, message: "個別フィールドを使用してください")
    var targetDate: Date?
    @available(*, deprecated, message: "個別フィールド方式に移行したため非推奨")
    var payload: Data?

    // ログ(1:N)。プロフィール削除時は関連ログも削除
    @Relationship(deleteRule: .cascade) var weightLogs: [WeightLogEntity] = []

    init(userID: String, deviceID: String) {
        self.userID = userID
        self.deviceID = deviceID
        self.updatedAt = Date()
        self.version = 1
    }
}

@Model
final class GeneratedPlanRecord {
    @Attribute(.unique) var id: UUID
    var createdAt: Date
    var summary: String
    var dailyCalories: Int
    var motivationalMessage: String
    var json: String

    init(id: UUID = UUID(),
         createdAt: Date = .now,
         summary: String,
         dailyCalories: Int,
         motivationalMessage: String,
         json: String) {
        self.id = id
        self.createdAt = createdAt
        self.summary = summary
        self.dailyCalories = dailyCalories
        self.motivationalMessage = motivationalMessage
        self.json = json
    }
}

@Model
final class WeightLogEntity {
    // 1ユーザー×1日=1件 を保証(重複入力を防止)
    #Unique<WeightLogEntity>([\.userID, \.recordDate])
    #Index<WeightLogEntity>([\.userID], [\.recordDate])

    @Attribute(.unique) var id: UUID
    var userID: String
    var recordDate: Date
    var weightKg: Double
    var updatedAt: Date
    var deviceID: String

    // 逆参照(任意): View側のプリフェッチに有用
    @Relationship(inverse: \UserProfileEntity.weightLogs) var user: UserProfileEntity?

    init(userID: String, recordDate: Date, weightKg: Double, deviceID: String) {
        self.id = UUID()
        self.userID = userID
        self.recordDate = recordDate
        self.weightKg = weightKg
        self.updatedAt = Date()
        self.deviceID = deviceID
    }
}

enum OutboxOp: String, Codable { case upsertProfile, upsertWeight, deleteWeight }

@Model
final class OutboxItemEntity {
    // アップロード順と再送制御のためのindex
    #Index<OutboxItemEntity>([\.userID], [\.createdAt], [\.attempt])

    @Attribute(.unique) var id: UUID
    var userID: String
    var opRaw: String
    /// JSON等のバイト列(暗号化前提なら暗号化後を格納)
    var payload: Data
    var attempt: Int
    var createdAt: Date

    init(userID: String, op: OutboxOp, payload: Data) {
        self.id = UUID()
        self.userID = userID
        self.opRaw = op.rawValue
        self.payload = payload
        self.attempt = 0
        self.createdAt = Date()
    }

    // 型安全にアクセスしたい時用のcomputed property
    var op: OutboxOp? { OutboxOp(rawValue: opRaw) }
}

@Model
final class AuditLogEntity {
    #Index<AuditLogEntity>([\.userID], [\.ts])

    @Attribute(.unique) var id: UUID
    var userID: String
    var action: String
    var ts: Date
    var meta: String?

    init(userID: String, action: String, meta: String?) {
        self.id = UUID()
        self.userID = userID
        self.action = action
        self.meta = meta
        self.ts = Date()
    }
}

@Model
final class WorkoutSessionEntity {
    @Attribute(.unique) var id: UUID
    var userID: String // UserProfileEntityと紐付けるID
    var name: String // "Push Day" や "脚の日" など
    var sessionDate: Date // 実施日
    
    /// 集計済みメトリクス(セッション単位)
    var durationSeconds: Int = 0
    var caloriesKcal: Int = 0
    
    // 1セッションは複数のエクササイズを持つ (1:N)
    @Relationship(deleteRule: .cascade)
    var exercises: [LoggedExerciseEntity] = []
    
    init(userID: String, name: String, sessionDate: Date) {
        self.id = UUID()
        self.userID = userID
        self.name = name
        self.sessionDate = sessionDate
    }
}

@Model
final class LoggedExerciseEntity {
    @Attribute(.unique) var id: UUID
    var exerciseName: String // "ベンチプレス"
    
    // 1エクササイズは複数のセットを持つ (1:N)
    @Relationship(deleteRule: .cascade)
    var sets: [LoggedSetEntity] = []
    
    // 逆参照: どのセッションに属しているか
    @Relationship(inverse: \WorkoutSessionEntity.exercises)
    var session: WorkoutSessionEntity?
    
    init(exerciseName: String) {
        self.id = UUID()
        self.exerciseName = exerciseName
    }
}

@Model
final class LoggedSetEntity {
    @Attribute(.unique) var id: UUID
    var setIndex: Int // 1セット目、2セット目...
    var weightKg: Double
    var reps: Int
    var isCompleted: Bool
    
    // 逆参照: どのエクササイズに属しているか
    @Relationship(inverse: \LoggedExerciseEntity.sets)
    var exercise: LoggedExerciseEntity?
    
    init(setIndex: Int, weightKg: Double, reps: Int, isCompleted: Bool) {
        self.id = UUID()
        self.setIndex = setIndex
        self.weightKg = weightKg
        self.reps = reps
        self.isCompleted = isCompleted
    }
}

// ✅ WorkoutProgress モデル
@Model
final class WorkoutProgress {
    #Unique<WorkoutProgress>([\.planRecordId, \.dayIdentifier])
    #Index<WorkoutProgress>([\.planRecordId], [\.dayIdentifier])
    
    @Attribute(.unique) var id: UUID
    var planRecordId: UUID
    var dayIdentifier: String // "月曜日", "水曜日" etc.
    var completedAt: Date?
    var isCompleted: Bool
    var difficultyFeedback: String?
    
    var elapsedSeconds: Int?       // 実行時間(秒)
    var estimatedCalories: Int?    // 推定消費カロリー
    
    init(id: UUID = UUID(), planRecordId: UUID, dayIdentifier: String, completedAt: Date? = nil, isCompleted: Bool = false) {
        self.id = id
        self.planRecordId = planRecordId
        self.dayIdentifier = dayIdentifier
        self.completedAt = completedAt
        self.isCompleted = isCompleted
    }
}

// MARK: - Custom Workout Entity

/// ユーザーが自由に作成したワークアウトを保持するエンティティ
@Model
final class CustomWorkoutEntity {
    /// ユニークID
    @Attribute(.unique) var id: UUID
    /// 所有ユーザーのID
    var userID: String
    /// ワークアウト名称
    var name: String
    /// 運動部位カテゴリ（胸・肩・脚など）
    var bodyPart: String
    /// タグやキーワード
    var tags: [String]
    /// 作成日時
    var createdAt: Date
    /// 1セッションあたりの運動時間（分）
    var durationMin: Double = 0
        /// 1セッションあたりの想定消費カロリー(kcal)
    var caloriesKcal: Int = 0
    
    init(id: UUID = UUID(), userID: String = "current_user", name: String, bodyPart: String = "カスタム", tags: [String] = [], createdAt: Date = Date()) {
        self.id = id
        self.userID = userID
        self.name = name
        self.bodyPart = bodyPart
        self.tags = tags
        self.createdAt = createdAt
    }
}

// MARK: - Global SwiftData Model Registry

/// アプリ全体で利用する SwiftData モデル一覧
let appModelTypes: [any PersistentModel.Type] = [
    UserProfileEntity.self,
    GeneratedPlanRecord.self,
    WeightLogEntity.self,
    OutboxItemEntity.self,
    AuditLogEntity.self,
    WorkoutSessionEntity.self,
    LoggedExerciseEntity.self,
    LoggedSetEntity.self,
    WorkoutProgress.self,
    CustomWorkoutEntity.self
]

// MARK: - UserProfileEntity Extension

extension UserProfileEntity {
    /// EntityからUserProfileドメインモデルに変換
    @MainActor
    func toUserProfile() -> UserProfile {
        var profile = UserProfile()
        
        profile.name = self.name
        profile.age = self.age
        
        if let genderStr = self.gender,
           let gender = Gender(rawValue: genderStr) {
            profile.gender = gender
        }
        
        if let data = self.bodyTypeData,
           let bodyType = try? JSONDecoder().decode(BodyTypeModel.self, from: data) {
            profile.bodyType = bodyType
        }
        
        profile.heightCm = self.heightCm
        profile.weightKg = self.weightKg
        
        if let data = self.activityLevelData,
           let activity = try? JSONDecoder().decode(ActivityLevelModel.self, from: data) {
            profile.activityLevel = activity
        }
        
        profile.preferredActivities = self.preferredActivities ?? []
        profile.ownedEquipments = self.ownedEquipments ?? []
        
        if let data = self.goalData,
           let goal = try? JSONDecoder().decode(GoalProfile.self, from: data) {
            profile.goal = goal
        }
        
        if let data = self.workoutScheduleData,
           let schedule = try? JSONDecoder().decode(WorkoutSchedule.self, from: data) {
            profile.workoutSchedule = schedule
        }
        
        profile.trainingPerWeek = self.trainingPerWeek
        
        return profile
    }
}
