import Foundation
import Combine

// MARK: - MET Value Provider (Thread-safe, Dependency-injectable)

/// Protocol for MET value lookup - enables testing and flexibility
public protocol METValueProviding {
    func metValue(for name: String,
                  fallbackByDurationBased: Bool?,
                  defaultResistance: Double,
                  defaultAerobic: Double) -> Double
    func registerCustom(keys: [String], mets: Double)
    func resetCustom()
    func getAllEntries() async -> [METValueProvider.Entry]
}

/// A centralized provider for mapping exercise names (keywords) to MET values.
/// Thread-safe with @MainActor annotation. Supports dependency injection for testing.
public final class METValueProvider: METValueProviding {
    public static let shared = METValueProvider()
    
    // MARK: - Dependencies (injectable for testing)
    private let dataLoader: METDataLoading
    
    /// Default initializer using embedded JSON resource
    public convenience init() {
        self.init(dataLoader: DefaultMETDataLoader())
    }
    
    /// Dependency-injectable initializer for testing
    public init(dataLoader: METDataLoading = DefaultMETDataLoader()) {
        self.dataLoader = dataLoader
        Task {
            await loadData()
        }
    }
    
    private func loadData() async {
        if let loaded = await dataLoader.loadEntries() {
            await MainActor.run { self.builtIn = loaded }
        } else {
            #if DEBUG
            print("⚠️ Warning: MET data failed to load, using fallback table")
            #endif
        }
    }
    
    // MARK: - Data Storage
    @MainActor
    private var builtIn: [Entry] = METValueProvider.fallbackBuiltIn
    
    @MainActor
    private var custom: [Entry] = []
    
    // MARK: - Public API
    
    /// Returns a MET value for an exercise name by keyword matching.
    /// - Parameters:
    ///   - name: Exercise name (any language). Partial match (substring) and case-insensitive.
    ///   - isDurationBased: Optional hint; if `true` returns aerobic fallback; if `false` returns resistance fallback.
    ///   - defaultResistance: Default for resistance/rep-based when unmatched (default 3.8, mid-intensity)
    ///   - defaultAerobic: Default for time-based/aerobic when unmatched (default 6.0, moderate)
    @MainActor
    public func metValue(for name: String,
                         isDurationBased: Bool? = nil,
                         defaultResistance: Double = 3.8,
                         defaultAerobic: Double = 6.0) -> Double {
        let normalized = name.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
        
        // 1) Custom entries take precedence (newest first)
        for entry in custom.reversed() {
            if entry.matchesNormalized(normalized) {
                return max(1.0, entry.mets)
            }
        }
        
        // 2) Built-in entries
        for entry in builtIn {
            if entry.matchesNormalized(normalized) {
                return max(1.0, entry.mets)
            }
        }
        
        // 3) Fallback by activity type hint
        if let hint = isDurationBased {
            return hint ? defaultAerobic : defaultResistance
        }
        return defaultResistance
    }
    
    // Legacy method name for backward compatibility
    public func metValue(for name: String,
                         fallbackByDurationBased: Bool? = nil,
                         defaultResistance: Double = 3.8,
                         defaultAerobic: Double = 6.0) -> Double {
        Task { @MainActor in
            return self.metValue(for: name, isDurationBased: fallbackByDurationBased,
                               defaultResistance: defaultResistance, defaultAerobic: defaultAerobic)
        }
        // Synchronous fallback
        return defaultResistance
    }
    
    @MainActor
    public func registerCustom(keys: [String], mets: Double) {
        custom.append(Entry(keys: keys, mets: mets))
    }
    
    @MainActor
    public func resetCustom() {
        custom.removeAll()
    }
    
    /// Returns all available entries (custom + built-in)
    /// - Returns: Array of all MET entries
    @MainActor
    public func getAllEntries() async -> [Entry] {
        return custom + builtIn
    }
}

// MARK: - Data Model

extension METValueProvider {
    public struct Entry: Hashable, Sendable {
        public let keys: [String]
        public let normalizedKeys: [String]  // Pre-computed for performance
        public let mets: Double
        
        public init(keys: [String], mets: Double) {
            self.keys = keys
            self.normalizedKeys = keys.map { $0.lowercased() }
            self.mets = mets
        }
        
        func matchesNormalized(_ normalized: String) -> Bool {
            normalizedKeys.contains { normalized.contains($0) }
        }
    }
}

// MARK: - Data Loading Protocol

public protocol METDataLoading: Sendable {
    func loadEntries() async -> [METValueProvider.Entry]?
}

public struct DefaultMETDataLoader: METDataLoading {
    private struct EntryDTO: Codable {
        let keys: [String]
        let mets: Double
    }
    
    public init() {}
    
    public func loadEntries() async -> [METValueProvider.Entry]? {
        guard let url = Bundle.main.url(forResource: "mets_table", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let dtos = try? JSONDecoder().decode([EntryDTO].self, from: data) else {
            return nil
        }
        
        // Perform mapping off main thread
        return dtos.map { METValueProvider.Entry(keys: $0.keys, mets: $0.mets) }
    }
}

// MARK: - Fallback Built-in Table

extension METValueProvider {
    private static let fallbackVeryHigh: [Entry] = [
        // 10+ METs (Very High Intensity)
        Entry(keys: ["スライドボード"], mets: 11.0),
        Entry(keys: ["ランニング (10.9km/h)", "ラン (6分/km)"], mets: 11.0),
        Entry(keys: ["縄跳び (高速)", "二重跳び"], mets: 12.3),
        Entry(keys: ["サッカー (試合)"], mets: 10.0),
        Entry(keys: ["バトルロープ (高強度)", "パワーロープ", "パワーロープ (スラム)"], mets: 10.0),
        Entry(keys: ["ランニング (9.7km/h)"], mets: 9.8)
    ]
    private static let fallbackHigh: [Entry] = [
        // 8-9.9 METs (High Intensity)
        Entry(keys: ["ステアートレッドミル", "階段マシン", "ステッパー"], mets: 9.0),
        Entry(keys: ["ボクシング (スパーリング)", "キックボクシング"], mets: 9.0),
        Entry(keys: ["スピンバイク", "RPMクラス"], mets: 8.5),
        Entry(keys: ["サイクリング (20km/h以上)", "自転車 (高速)"], mets: 8.0),
        Entry(keys: ["テニス (シングルス)", "スカッシュ"], mets: 8.0),
        Entry(keys: ["バスケットボール (試合)"], mets: 8.0),
        Entry(keys: ["HIIT", "インターバル", "バービー", "サーキット (きつい)", "ケトルベル"], mets: 8.0),
        Entry(keys: ["プッシュアップ", "腕立て", "腕立て伏せ", "健康体操 (きつい)"], mets: 8.0),
        Entry(keys: ["バトルロープ (中強度)", "バトルロープ (波)"], mets: 8.0),
        Entry(keys: ["ラグビー", "rugby"], mets: 8.0),
        Entry(keys: ["格闘技", "総合格闘技", "MMA"], mets: 8.5)
    ]
    private static let fallbackModerateHigh: [Entry] = [
        // 6-7.9 METs (Moderate to High)
        Entry(keys: ["バイク", "サイクリング", "自転車", "固定式自転車", "エアロバイク"], mets: 7.5),
        Entry(keys: ["エアロビクス (高強度)", "ダンスエアロ"], mets: 7.3),
        Entry(keys: ["テニス"], mets: 7.3),
        Entry(keys: ["ローイングエルゴメータ", "ローイング", "ボート漕ぎ"], mets: 7.0),
        Entry(keys: ["ジョギング", "ラン", "ランニング"], mets: 7.0),
        Entry(keys: ["水泳 (クロール, 中速)", "スイム"], mets: 7.0),
        Entry(keys: ["ハイキング (登山)"], mets: 6.5),
        Entry(keys: ["バトルロープ (軽度)"], mets: 6.5),
        Entry(keys: ["ベンチプレス (フリーウェイト)", "ベンチプレス", "パワーリフティング", "ボディビルディング"], mets: 6.0),
        Entry(keys: ["ショルダープレス", "オーバーヘッドプレス", "ミリタリープレス", "ダンベルショルダープレス", "アーノルドプレス", "overhead press", "military press", "arnold press"], mets: 6.0),
        Entry(keys: ["ダンベルプレス", "ダンベルベンチプレス", "dumbbell bench press"], mets: 6.0),
        Entry(keys: ["インクラインベンチプレス", "インクラインプレス", "incline bench press", "incline press"], mets: 6.0),
        Entry(keys: ["ベントオーバーロー", "バーベルロウ", "bent-over row"], mets: 6.0),
        Entry(keys: ["懸垂", "懸垂", "pull-up", "chin-up", "チンアップ"], mets: 7.5),
        Entry(keys: ["ディップス", "dips", "ディップ"], mets: 7.5),
        Entry(keys: ["クラップ・プッシュアップ", "Clap Push-Up"], mets: 7.0),
        Entry(keys: ["クリーン", "Clean"], mets: 7.0),
        Entry(keys: ["マウンテン・クライマー", "Mountain Climbers"], mets: 7.0),
        Entry(keys: ["プッシュ・プレス", "Push Press"], mets: 6.0),
        Entry(keys: ["バレー", "バレーボール", "volleyball"], mets: 6.0),
        Entry(keys: ["スキー", "アルペンスキー", "skiing"], mets: 7.0),
        Entry(keys: ["スノーボード", "snowboard"], mets: 6.5),
        Entry(keys: ["サーフィン", "surfing"], mets: 5.5),
        Entry(keys: ["柔道", "judo"], mets: 7.0),
        Entry(keys: ["空手", "karate"], mets: 7.0),
        Entry(keys: ["剣道", "kendo"], mets: 6.0),
        Entry(keys: ["フェンシング", "fencing"], mets: 6.0)
    ]
    private static let fallbackModerate: [Entry] = [
        // 4-5.9 METs (Moderate)
        Entry(keys: ["バドミントン"], mets: 5.5),
        Entry(keys: ["スクワット", "バックスクワット", "フロントスクワット", "squat"], mets: 5.0),
        Entry(keys: ["デッドリフト", "deadlift"], mets: 5.0),
        Entry(keys: ["ブルガリアンスクワット", "ブルガリアン・スクワット", "split squat", "Bulgarian split squat"], mets: 5.0),
        Entry(keys: ["エリプティカル", "エリプティカルトレーナー"], mets: 5.0),
        Entry(keys: ["筋トレ (フリーウェイト, 中強度)", "バーベル"], mets: 5.0),
        Entry(keys: ["ウェイトマシン (中強度)"], mets: 4.5),
        Entry(keys: ["ゴルフ (担ぎ)"], mets: 4.3),
        Entry(keys: ["ラジオ体操 (第一・第二)"], mets: 4.0),
        Entry(keys: ["卓球"], mets: 4.0),
        Entry(keys: ["ヨガ (パワーヨガ)"], mets: 4.0),
        Entry(keys: ["チンアップ / 逆手懸垂", "Chin-Up"], mets: 4.0),
        Entry(keys: ["アーノルド・プレス", "Arnold Press"], mets: 4.5),
        Entry(keys: ["ミリタリー・プレス", "Military Press"], mets: 4.5),
        Entry(keys: ["逆立ち腕立て伏せ", "Handstand Push-Up"], mets: 5.0),
        Entry(keys: ["Zプレス", "Z Press"], mets: 4.5),
        Entry(keys: ["フロア・プレス", "Floor Press"], mets: 4.5),
        Entry(keys: ["グッドモーニング", "Good Morning"], mets: 4.0),
        Entry(keys: ["野球", "ベースボール", "baseball"], mets: 5.0),
        Entry(keys: ["ボウリング", "bowling"], mets: 3.0),
        Entry(keys: ["スケート", "アイススケート", "skating"], mets: 5.0),
        Entry(keys: ["アーチェリー", "archery"], mets: 3.5),
        Entry(keys: ["乗馬", "ホースライディング", "horseback riding"], mets: 4.0)
    ]
    private static let fallbackLightModerate: [Entry] = [
        // 3-3.9 METs (Light to Moderate)
        Entry(keys: ["レッグプレス", "ラットプルダウン", "アームカール", "トライセプス"], mets: 3.5),
        Entry(keys: ["レッグエクステンション", "レッグカール", "シーテッドロウ", "ペックデック", "アブドミナルマシン"], mets: 3.5),
        Entry(keys: ["筋トレ (マシン)", "筋トレ (ほどほど)", "レジスタンストレーニング"], mets: 3.5),
        Entry(keys: ["ウォーキング", "歩", "ウォーク"], mets: 3.5),
        Entry(keys: ["プランク"], mets: 3.3),
        Entry(keys: ["チェストプレス (マシン)", "筋トレ (マシン, 楽)"], mets: 3.0),
        Entry(keys: ["ストレッチ (動的)", "モビリティ"], mets: 3.0),
        Entry(keys: ["ピラティス"], mets: 3.0),
        Entry(keys: ["ペクトラルフライ", "ペックデック", "ダンベルフライ", "インクラインダンベルフライ", "ケーブルフライ", "ケーブルクロスオーバー", "pec deck", "dumbbell fly", "cable fly", "cable crossover"], mets: 3.5),
        Entry(keys: ["チェストプレス", "マシンチェストプレス", "chest press machine"], mets: 3.5),
        Entry(keys: ["レッグエクステンション", "leg extension"], mets: 3.5),
        Entry(keys: ["レッグカール", "leg curl"], mets: 3.5),
        Entry(keys: ["シーテッドロウ", "seated row", "ローマシン"], mets: 3.5),
        Entry(keys: ["サイドレイズ", "フロントレイズ", "リアレイズ", "リアデルト", "lateral raise", "front raise", "rear delt raise", "reverse fly"], mets: 3.5),
        Entry(keys: ["アップライトロウ", "upright row"], mets: 3.5),
        Entry(keys: ["バーベルカール", "EZバーカール", "ダンベルカール", "インクラインアームカール", "インクラインハンマーカール", "ハンマーカール", "cable curl", "ケーブルカール"], mets: 3.5),
        Entry(keys: ["ケーブルプレスダウン", "プレスダウン", "フレンチプレス", "スカルクラッシャー", "トライセプスエクステンション", "cable pressdown", "french press", "skull crusher", "triceps extension"], mets: 3.5),
        Entry(keys: ["ケーブルサイドレイズ", "インクラインサイドレイズ", "cable lateral raise", "incline lateral raise"], mets: 3.5),
        Entry(keys: ["ケーブルプルオーバー", "pull-over", "pullover"], mets: 3.5),
        Entry(keys: ["カーフレイズ", "calf raise"], mets: 3.5),
        Entry(keys: ["ワンハンドローイング", "one-arm row", "one-hand row", "ダンベルロウ"], mets: 3.5),
        Entry(keys: ["アブローラー", "ab roller", "ab wheel", "腹筋ローラー"], mets: 3.8),
        Entry(keys: ["ケーブル・チェストプレス", "Cable Chest Press"], mets: 3.5),
        Entry(keys: ["ケーブル・クロスオーバー", "Cable Crossover"], mets: 3.0),
        Entry(keys: ["ケーブル・フライ", "Cable Fly"], mets: 3.0),
        Entry(keys: ["インクライン・プッシュアップ", "Incline Push-Up"], mets: 3.0),
        Entry(keys: ["マシン・チェストプレス", "Machine Chest Press"], mets: 3.5),
        Entry(keys: ["プッシュアップ / 腕立て伏せ", "Push-Up"], mets: 3.8),
        Entry(keys: ["アシステッド・プルアップ", "Assisted Pull-Up"], mets: 3.0),
        Entry(keys: ["ラットプルダウン", "Lat Pulldown"], mets: 3.5),
        Entry(keys: ["パイク・プッシュアップ", "Pike Push-Up"], mets: 3.8),
        Entry(keys: ["クローズグリップ・プッシュアップ", "Close-Grip Push-Up", "ダイヤモンド腕立て伏せ"], mets: 3.8),
        Entry(keys: ["カーツィー・ランジ", "Curtsy Lunge"], mets: 3.8),
        Entry(keys: ["コペンハーゲン・プランク", "Copenhagen Plank"], mets: 3.0),
        Entry(keys: ["ノルディック・ハムストリング・エキセントリック", "Nordic Hamstring Eccentric"], mets: 3.5),
        Entry(keys: ["レッグ・エクステンション", "Leg Extension", "Machine Leg Extension"], mets: 3.0),
        Entry(keys: ["レッグ・プレス", "Leg Press", "Machine Leg Press"], mets: 3.5),
        Entry(keys: ["ライイング・レッグ・カール", "Lying Leg Curl", "Machine Lying Leg Curl"], mets: 3.0),
        Entry(keys: ["ヒップスラスト", "ヒップリフト", "ブリッジ", "hip thrust", "glute bridge"], mets: 3.5),
        Entry(keys: ["ドンキーキック", "donkey kick"], mets: 3.0),
        Entry(keys: ["レッグレイズ", "leg raise"], mets: 3.0),
        Entry(keys: ["バイシクルクランチ", "bicycle crunch"], mets: 3.0)
    ]
    private static let fallbackLight: [Entry] = [
        // 2-2.9 METs (Light)
        Entry(keys: ["ストレッチ", "stretch"], mets: 2.5),
        Entry(keys: ["ヨガ (ハタヨガ)"], mets: 2.5),
        Entry(keys: ["ストレッチ (静的)", "柔軟体操"], mets: 2.3),
        Entry(keys: ["膝つき腕立て伏せ", "Kneeling Push-Up"], mets: 2.8),
        Entry(keys: ["ケーブル・カール", "Cable Curl"], mets: 2.5),
        Entry(keys: ["コンセントレーション・カール", "Concentration Curl"], mets: 2.5),
        Entry(keys: ["ハンマー・カール", "Hammer Curl"], mets: 2.5),
        Entry(keys: ["ゾットマン・カール", "Zottman Curl"], mets: 2.5),
        Entry(keys: ["ケーブル・グルート・キックバック", "Cable Glute Kickback"], mets: 2.5),
        Entry(keys: ["クラムシェル", "Clamshells"], mets: 2.5),
        Entry(keys: ["ヒップ・アブダクション・マシン", "Hip Abduction Machine"], mets: 2.5),
        Entry(keys: ["ヒップ・アダクション・マシン", "Hip Adduction Machine"], mets: 2.5),
        Entry(keys: ["ケーブル・クランチ", "Cable Crunch"], mets: 2.8),
        Entry(keys: ["クランチ", "Crunch"], mets: 2.8),
        Entry(keys: ["マシン・クランチ", "Machine Crunch"], mets: 2.8),
        Entry(keys: ["パロフ・プレス", "Pallof Press"], mets: 2.8),
        Entry(keys: ["プランク", "Plank"], mets: 2.8),
        Entry(keys: ["グリッパー", "Gripper"], mets: 1.8),
        Entry(keys: ["プレート・ピンチ", "Plate Pinch"], mets: 1.8),
        Entry(keys: ["ライイング・ネック・カール", "Lying Neck Curl"], mets: 1.8),
        Entry(keys: ["ライイング・ネック・エクステンション", "Lying Neck Extension"], mets: 1.8),
        Entry(keys: ["シットアップ", "sit-up"], mets: 2.8),
        Entry(keys: ["サイドプランク", "side plank"], mets: 2.8)
    ]

    public static let fallbackBuiltIn: [Entry] = fallbackVeryHigh + fallbackHigh + fallbackModerateHigh + fallbackModerate + fallbackLightModerate + fallbackLight
}

// MARK: - Exercise Lexicon with Ordered Priority

public enum ExerciseLexicon {
    public enum Category: String, Codable, CaseIterable, Sendable {
        case squat, deadlift, benchPress, overheadPress, row, pullUp, dip
        case pushUp, lunge, stepUp, hinge, curl, triceps, crunch
        case legPress, legExtension, legCurl, latPulldown, seatedRow, pecDeck, abdominalMachine
        case burpee, jumpingJack, kettlebellSwing, mobility, cardio, other
    }
    
    private static let orderedMapping: [(Category, [String])] = [
        (.squat,           ["squat","スクワット","フリーウェイトスクワット"]),
        (.deadlift,        ["deadlift","デッド","rdl","romanian"]),
        (.benchPress,      ["bench","ベンチ","press (bench)","ベンチプレス"]),
        (.overheadPress,   ["overhead","ショルダー","military","ohp"]),
        (.row,             ["bent over", "バーベルロウ"]),
        (.pullUp,          ["pull-up","chin-up","懸垂"]),
        (.dip,             ["dip","ディップス"]),
        
        (.legPress,        ["leg press", "レッグプレス"]),
        (.legExtension,    ["leg extension", "レッグエクステンション"]),
        (.legCurl,         ["leg curl", "レッグカール"]),
        (.latPulldown,     ["lat pulldown", "ラットプルダウン"]),
        (.seatedRow,       ["seated row", "シーテッドロウ", "ローマシン"]),
        (.pecDeck,         ["pec deck", "ペックデック", "フライマシン"]),
        (.abdominalMachine,["abdominal", "アブドミナルマシン"]),
        
        (.pushUp,          ["push-up","腕立て","プッシュアップ"]),
        (.lunge,           ["lunge","ランジ"]),
        (.stepUp,          ["step-up","ステップアップ"]),
        (.hinge,           ["good morning","hip hinge","ヒップヒンジ"]),
        (.curl,            ["curl","カール","アームカール"]),
        (.triceps,         ["extension","kickback","トライセプス"]),
        (.crunch,          ["crunch","シットアップ","腹筋"]),
        
        (.burpee,          ["burpee","バービー"]),
        (.jumpingJack,     ["jumping jack","ジャンピングジャック"]),
        (.kettlebellSwing, ["swing","スイング","ケトルベル"]),
        (.mobility,        ["stretch","ストレッチ","モビリティ","動的","静的","ヨガ","ピラティス"]),
        (.cardio,          ["ラン","バイク","ジョギング","ウォーキング","ステッパー","エリプティカル","row","ローイング"]),
        (.other,           [])
    ]
    
    public static func category(for name: String) -> Category {
        let normalized = name.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
        
        for (cat, keywords) in orderedMapping {
            if keywords.contains(where: { normalized.contains($0.lowercased()) }) {
                return cat
            }
        }
        return .other
    }
}

// MARK: - User Defaults Key

public enum DefaultsKey {
    public static let goalType = "Sync.goalType"
}

// MARK: - User Goal Type

public enum UserGoalType: String, Codable, CaseIterable, Sendable {
    case loseFat, bulkUp, maintain
    
    var tempoMultiplier: Double {
        switch self {
        case .loseFat:  return 0.85
        case .bulkUp:   return 1.15
        case .maintain: return 1.00
        }
    }
}

// MARK: - Pace Provider (Thread-safe, Dependency-injectable)

extension Pace {
    public struct Profile: Codable, Equatable, Sendable {
        public var secondsPerRep: Double
        public var restPerSetSeconds: Int
    }
    
    public enum Difficulty: Sendable {
        case easy, normal, hard
        
        var paceMultiplier: Double {
            switch self {
            case .easy:   return 0.95
            case .normal: return 1.0
            case .hard:   return 1.08
            }
        }
        
        var restMultiplier: Double {
            switch self {
            case .easy:   return 0.9
            case .normal: return 1.0
            case .hard:   return 1.15
            }
        }
    }
    
    public enum Equipment: Sendable {
        case bodyweight, machine, dumbbell, barbell, kettlebell, band, other
        
        var paceMultiplier: Double {
            switch self {
            case .machine:    return 0.95
            case .barbell:    return 1.05
            case .kettlebell: return 1.00
            case .dumbbell:   return 1.00
            case .band:       return 0.95
            case .bodyweight: return 0.95
            case .other:      return 1.00
            }
        }
    }
    
    public struct Tempo: Sendable {
        public var ecc: Double
        public var pause: Double
        public var con: Double
        public var top: Double
        
        public var total: Double { ecc + pause + con + top }
        public static let `default` = Tempo(ecc: 2, pause: 0, con: 2, top: 0)
    }
}

// MARK: - Pace Provider

public protocol UserDefaultsProtocol {
    func string(forKey key: String) -> String?
    func data(forKey key: String) -> Data?
    func set(_ value: Any?, forKey key: String)
}

extension UserDefaults: UserDefaultsProtocol {}

@MainActor
public final class PaceProvider: ObservableObject {
    
    @Published public private(set) var currentGoal: UserGoalType = .maintain
    
    private let userDefaults: UserDefaultsProtocol
    private let goalBiasKey = DefaultsKey.goalType
    private let storeKey = "Pace.Provider.v1"
    
    private let emaAlpha = 0.30
    private var learnedSecondsPerRep: [ExerciseLexicon.Category: Double] = [:]
    
    public convenience init() {
        self.init(userDefaults: UserDefaults.standard)
    }
    
    public init(userDefaults: UserDefaultsProtocol) {
        self.userDefaults = userDefaults
        loadGoalPreference()
        loadLearnedPace()
    }
    
    private func loadGoalPreference() {
        if let raw = userDefaults.string(forKey: goalBiasKey),
           let goal = UserGoalType(rawValue: raw) {
            currentGoal = goal
        }
    }
    
    public func setUserGoal(_ type: UserGoalType) {
        currentGoal = type
        userDefaults.set(type.rawValue, forKey: goalBiasKey)
    }
    
    public func setUserGoalRaw(_ raw: String) {
        if let type = UserGoalType(rawValue: raw) {
            setUserGoal(type)
        }
    }
    
    public func pace(for exerciseName: String,
                     difficulty: Pace.Difficulty = .normal,
                     equipment: Pace.Equipment = .other,
                     tempo: Pace.Tempo? = nil) -> Pace.Profile {
        let cat = ExerciseLexicon.category(for: exerciseName)
        var base = defaults[cat] ?? defaults[.other]!
        
        if let learned = learnedSecondsPerRep[cat] {
            base.secondsPerRep = learned
        }
        
        if let t = tempo {
            let tempoMult = max(t.total / max(0.5, base.secondsPerRep), 0.3)
            base.secondsPerRep *= tempoMult
        }
        
        base.secondsPerRep *= currentGoal.tempoMultiplier
        base.secondsPerRep *= difficulty.paceMultiplier * equipment.paceMultiplier
        base.restPerSetSeconds = Int(Double(base.restPerSetSeconds) * difficulty.restMultiplier)
        
        return base
    }
    
    public func record(exerciseName: String, reps: Int, elapsedSeconds: Int, restSeconds: Int) {
        guard reps > 0 else { return }
        
        let cat = ExerciseLexicon.category(for: exerciseName)
        let activeSeconds = max(0, elapsedSeconds - restSeconds)
        let measuredSecPerRep = Double(activeSeconds) / Double(reps)
        
        let previousPace = learnedSecondsPerRep[cat] ?? defaults[cat]?.secondsPerRep ?? 3.0
        let updatedPace = emaAlpha * measuredSecPerRep + (1 - emaAlpha) * previousPace
        
        learnedSecondsPerRep[cat] = clamp(updatedPace, min: 0.6, max: 8.0)
        
        save()
    }
    
    private func save() {
        let payload = Dictionary(uniqueKeysWithValues:
            learnedSecondsPerRep.map { ($0.key.rawValue, $0.value) }
        )
        
        if let data = try? JSONEncoder().encode(payload) {
            userDefaults.set(data, forKey: storeKey)
        }
    }
    
    private func loadLearnedPace() {
        guard let data = userDefaults.data(forKey: storeKey),
              let dict = try? JSONDecoder().decode([String: Double].self, from: data) else {
            return
        }
        
        var restored: [ExerciseLexicon.Category: Double] = [:]
        for (key, value) in dict {
            if let cat = ExerciseLexicon.Category(rawValue: key) {
                restored[cat] = value
            }
        }
        learnedSecondsPerRep = restored
    }
    
    private let defaults: [ExerciseLexicon.Category: Pace.Profile] = [
        .squat:           .init(secondsPerRep: 4.5, restPerSetSeconds: 120),
        .deadlift:        .init(secondsPerRep: 5.0, restPerSetSeconds: 150),
        .benchPress:      .init(secondsPerRep: 4.0, restPerSetSeconds: 120),
        .overheadPress:   .init(secondsPerRep: 4.0, restPerSetSeconds: 120),
        .row:             .init(secondsPerRep: 4.0, restPerSetSeconds: 90),
        .pullUp:          .init(secondsPerRep: 4.5, restPerSetSeconds: 120),
        .dip:             .init(secondsPerRep: 3.5, restPerSetSeconds: 90),
        
        .legPress:        .init(secondsPerRep: 4.0, restPerSetSeconds: 90),
        .legExtension:    .init(secondsPerRep: 3.5, restPerSetSeconds: 60),
        .legCurl:         .init(secondsPerRep: 3.5, restPerSetSeconds: 60),
        .latPulldown:     .init(secondsPerRep: 4.0, restPerSetSeconds: 75),
        .seatedRow:       .init(secondsPerRep: 4.0, restPerSetSeconds: 75),
        .pecDeck:         .init(secondsPerRep: 3.5, restPerSetSeconds: 60),
        .abdominalMachine:.init(secondsPerRep: 3.0, restPerSetSeconds: 60),
        
        .pushUp:          .init(secondsPerRep: 3.0, restPerSetSeconds: 60),
        .lunge:           .init(secondsPerRep: 4.0, restPerSetSeconds: 90),
        .stepUp:          .init(secondsPerRep: 3.8, restPerSetSeconds: 90),
        .hinge:           .init(secondsPerRep: 3.5, restPerSetSeconds: 90),
        .curl:            .init(secondsPerRep: 3.0, restPerSetSeconds: 60),
        .triceps:         .init(secondsPerRep: 3.0, restPerSetSeconds: 60),
        .crunch:          .init(secondsPerRep: 2.5, restPerSetSeconds: 45),
        
        .burpee:          .init(secondsPerRep: 3.0, restPerSetSeconds: 60),
        .jumpingJack:     .init(secondsPerRep: 1.3, restPerSetSeconds: 45),
        .kettlebellSwing: .init(secondsPerRep: 2.2, restPerSetSeconds: 75),
        .mobility:        .init(secondsPerRep: 3.0, restPerSetSeconds: 30),
        .cardio:          .init(secondsPerRep: 1.0, restPerSetSeconds: 30),
        .other:           .init(secondsPerRep: 3.5, restPerSetSeconds: 60),
    ]
    
    private func clamp(_ v: Double, min: Double, max: Double) -> Double {
        Swift.max(min, Swift.min(max, v))
    }
}

public enum Pace {
    // All nested types defined above
}

