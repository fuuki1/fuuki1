import Foundation

/// 性別を表すオプション。
///
/// アプリの UI では `GenderOption` として登場するが、
/// データ層では汎用的な名前に変更している。
public enum Gender: String, Codable, CaseIterable, Sendable {
    /// 男性を意味する
    case male
    /// 女性を意味する
    case female
    /// 男性でも女性でもない／回答しない
    case unspecified
}

// MARK: - App-wide DataModel (shared)
import Combine

/// アプリ全体で使う観測用データモデル。
/// 各オンボーディング画面からここを更新できるようにしておく。
@MainActor
final class DataModel: ObservableObject {
    /// オンボーディングで組み立てるユーザープロファイル全体。
    ///
    /// `UserProfile` にアプリで必要な情報をすべて保持するようにしたため、
    /// 以前はここに持っていた `trainingPerWeek` は `UserProfile` 内に移動しました。
    @Published var userProfile: UserProfile = .init()

    /// `DataModel` はシングルトンとしては扱わず、各ビュー階層で `@StateObject` として生成し、
    /// `.environmentObject` で渡す運用とします。これによりビュー間でデータを共有しつつ、
    /// グローバルな状態への依存を避けます。
    init() {}
}

/// 体型を表すオプション。
///
/// `BodyType` ステップで選択される値をそのまま保持するためのモデル。
public enum BodyTypeModel: String, Codable, CaseIterable, Sendable {
    /// 痩せ型
    case lean
    /// 標準的な体型
    case standard
    /// 筋肉質
    case muscular
    /// ぽっちゃりしている
    case chubby
}

/// 日常の活動レベルを表す。
///
/// `ActivityLevel` の UI 版と同義だが、データ層では説明文を持たないシンプルな表現とする。
public enum ActivityLevelModel: String, Codable, CaseIterable, Sendable {
    /// 座りがちな生活で運動はほとんどしない
    case sedentary
    /// 軽い運動を週1〜3回程度
    case light
    /// 中程度の強度で週3〜5回
    case moderate
    /// 週6〜7回アクティブに運動
    case active
    /// プロレベルの運動量
    case professional
}

/// 長期的な目標の種類。
///
/// `GoalTypeStep` で選択する「ダイエット」「筋肉増強」「健康維持」に対応する。
public enum GoalType: String, Codable, CaseIterable, Sendable {
    /// 体脂肪を減らして体重を落とすことを目標とする
    case loseFat
    /// 筋肉量を増やして全体的な体重を増やすことを目標とする
    case bulkUp
    /// 現状を維持し健康を保つことを目標とする
    case maintain
}

/// プランの難易度を表す。
///
/// `GoalPlanStepView` では「簡単」「普通」「難しい」の三択で提示される。
public enum PlanDifficulty: String, Codable, CaseIterable, Sendable {
    /// 消費カロリーと体重変化がゆるやかなプラン
    case easy
    /// 標準的なペースで目標を達成するプラン
    case normal
    /// より急速に目標達成を目指すプラン
    case hard
}

/// ユーザーが選択したプランの詳細。
///
/// `GoalPlanOption` から保存する値を抽出したデータモデル。画面表示用の詳細データではなく、
/// レポジトリ層に保存するためのコンパクトな表現とする。
public struct GoalPlanSelection: Codable, Equatable, Sendable {
    /// プランの難易度
    public var difficulty: PlanDifficulty
    /// 週間あたりの体重変化量(kg)。減量の場合は負値になる。
    public var weeklyRateKg: Double
    /// 1日あたりの摂取カロリー目標(kcal)
    public var dailyCalorieIntake: Double
    /// 目標達成までに必要な週数
    public var weeksNeeded: Double
    /// プランを選択した日時
    public var selectedAt: Date
    /// 表示名(「簡単」「普通」「難しい」など)
    public var planTitle: String
    
    public nonisolated init(
        difficulty: PlanDifficulty,
        weeklyRateKg: Double,
        dailyCalorieIntake: Double,
        weeksNeeded: Double,
        selectedAt: Date,
        planTitle: String
    ) {
        self.difficulty = difficulty
        self.weeklyRateKg = weeklyRateKg
        self.dailyCalorieIntake = dailyCalorieIntake
        self.weeksNeeded = weeksNeeded
        self.selectedAt = selectedAt
        self.planTitle = planTitle
    }
}

/// 目標に関する情報をまとめたモデル。
///
/// 体重に関連した目標や達成プランを保持し、将来的に拡張が容易な構造とする。
public struct GoalProfile: Codable, Equatable, Sendable {
    /// 選択された目標の種類(ダイエット／筋肉増強／健康維持)。
    public var type: GoalType?
    /// 目標体重(kg)。現体重と同一の場合は `nil`。
    public var goalWeightKg: Double?
    /// 目標達成までの詳細プラン。
    public var planSelection: GoalPlanSelection?
    /// 目標達成予定日。プラン選択時に計算される。
    public var targetDate: Date?
    
    public nonisolated init(
        type: GoalType? = nil,
        goalWeightKg: Double? = nil,
        planSelection: GoalPlanSelection? = nil,
        targetDate: Date? = nil
    ) {
        self.type = type
        self.goalWeightKg = goalWeightKg
        self.planSelection = planSelection
        self.targetDate = targetDate
    }
}

// MARK: - 修正 (FIXED)
// SyncingProfileRepository.swift から定義を移動

/// ワークアウトの時刻(時・分のみ)。
public struct WorkoutTime: Codable, Equatable, Sendable {
    public var hour: Int
    public var minute: Int
    public nonisolated init(hour: Int, minute: Int) { self.hour = hour; self.minute = minute }
}

/// ワークアウトスケジュール設定。
/// 曜日は 1=日, 2=月, …, 7=土 で表す(UI層の Weekday とは切り離す)。
public struct WorkoutSchedule: Codable, Equatable, Sendable {
    public var selectedWeekdays: [Int]              // 参加する曜日(1=日…7=土)
    public var dayTimes: [Int: WorkoutTime]         // 曜日ごとの時刻
    public var reminderOn: Bool                     // リマインドON/OFF
    public nonisolated init(selectedWeekdays: [Int], dayTimes: [Int: WorkoutTime], reminderOn: Bool) {
        self.selectedWeekdays = selectedWeekdays
        self.dayTimes = dayTimes
        self.reminderOn = reminderOn
    }
}


/// アプリのオンボーディングで構築されるユーザープロファイル。
///
/// 各ステップビュー (`OLNameStepView`、`OLAgeStepView` 等) から収集されたデータをひとまとめにする。
public struct UserProfile: Codable, Equatable, Sendable {
    /// ユーザーの表示名
    public var name: String?
    /// 年齢
    public var age: Int?
    /// 性別
    public var gender: Gender?
    /// 体型
    public var bodyType: BodyTypeModel?
    /// 身長(cm)
    public var heightCm: Double?
    /// 現在の体重(kg)
    public var weightKg: Double?
    /// 日常の活動レベル
    public var activityLevel: ActivityLevelModel?
    /// ユーザーの目標設定
    public var goal: GoalProfile?
    /// プランに取り入れたい活動(カテゴリ)
    /// 例: ["筋力トレーニング", "有酸素運動", "ヨガ・ピラティス"]
    public var preferredActivities: [String]?
    /// 所有している器具・詳細
    /// 例: ["ダンベル", "ベンチ", "プッシュアップバー"]
    public var ownedEquipments: [String]?
    /// 1週間あたりのトレーニング頻度。
    ///
    /// オンボーディングや設定画面でユーザーが選択する値であり、
    /// `DataModel` から切り離して `UserProfile` に保持します。nil の場合は未設定を意味します。
    public var trainingPerWeek: Int?
    
    // MARK: - 修正 (FIXED)
    /// ワークアウトのスケジュール
    public var workoutSchedule: WorkoutSchedule?
    
    public nonisolated init(
        name: String? = nil,
        age: Int? = nil,
        gender: Gender? = nil,
        bodyType: BodyTypeModel? = nil,
        heightCm: Double? = nil,
        weightKg: Double? = nil,
        activityLevel: ActivityLevelModel? = nil,
        goal: GoalProfile? = nil,
        preferredActivities: [String]? = nil,
        ownedEquipments: [String]? = nil,
        // MARK: - 修正 (FIXED)
        workoutSchedule: WorkoutSchedule? = nil, // init にも追加
        trainingPerWeek: Int? = nil
    ) {
        self.name = name
        self.age = age
        self.gender = gender
        self.bodyType = bodyType
        self.heightCm = heightCm
        self.weightKg = weightKg
        self.activityLevel = activityLevel
        self.goal = goal
        self.preferredActivities = preferredActivities
        self.ownedEquipments = ownedEquipments
        // MARK: - 修正 (FIXED)
        self.workoutSchedule = workoutSchedule // init にも追加
        self.trainingPerWeek = trainingPerWeek
    }
}
