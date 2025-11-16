import Foundation

// MARK: - Body Part Keywords

/// Keywords for classifying exercises by body part
enum BodyPartKeywords {
    static let sports: [String] = [
        "バスケ", "サッカー", "テニス", "バドミントン", "バレー", "ラグビー", "野球", "ゴルフ", "卓球",
        "ボウリング", "スケート", "スキー", "スノーボード", "サーフィン", "ボクシング", "格闘技", "総合格闘技",
        "空手", "柔道", "剣道", "フェンシング", "アーチェリー", "射撃", "乗馬"
    ]

    static let chest: [String] = [
        "胸", "チェスト", "大胸筋",
        "ベンチプレス", "インクラインベンチプレス", "インクライン・プッシュアップ", "フロア・プレス",
        "プッシュアップ", "腕立て", "腕立て伏せ", "膝つき腕立て伏せ", "クラップ・プッシュアップ",
        "ダンベルフライ", "ケーブル・フライ", "ケーブル・チェストプレス", "チェストプレス", "マシン・チェストプレス", "ケーブル・クロスオーバー",
        "ディップス"
    ]

    static let shoulder: [String] = [
        "肩", "ショルダー", "三角筋",
        "ショルダープレス", "ショルダー・プレス", "オーバーヘッドプレス", "ミリタリー・プレス", "アーノルド・プレス", "Zプレス",
        "サイドレイズ", "フロントレイズ", "リアレイズ", "アップライトロウ", "フェイスプル",
        "ランドマイン・プレス", "パイク・プッシュアップ", "プッシュ・プレス"
    ]

    static let back: [String] = [
        "背中", "背筋", "バック", "広背筋", "僧帽筋",
        "懸垂", "プルアップ", "プルアップ / 懸垂", "アシステッド・プルアップ", "チンアップ", "チンアップ / 逆手懸垂",
        "ラットプルダウン", "ベントオーバーロウ", "ローイング", "シーテッドロウ", "ローマシン",
        "デッドリフト", "グッドモーニング",
        "クリーン"
    ]

    static let arm: [String] = [
        "腕", "アーム", "上腕", "前腕", "二頭筋", "三頭筋", "バイセップ", "トライセップ",
        "アームカール", "ハンマーカール", "ケーブル・カール", "コンセントレーション・カール", "ゾットマン・カール", "バーベルカール", "EZバーカール",
        "トライセップス", "ケーブルプレスダウン", "プレスダウン", "フレンチプレス", "スカルクラッシャー", "トライセプスエクステンション",
        "リストカール", "グリッパー", "プレート・ピンチ"
    ]

    static let leg: [String] = [
        "脚", "足", "レッグ", "太もも", "ふくらはぎ", "大腿四頭筋", "ハムストリング", "臀部", "ヒップ", "お尻",
        "スクワット", "バックスクワット", "フロントスクワット", "ブルガリアンスクワット", "カーツィー・ランジ", "ランジ",
        "レッグプレス", "レッグ・プレス", "レッグエクステンション", "レッグ・エクステンション", "レッグカール", "レッグ・カール",
        "ライイング・レッグ・カール", "ノルディック・ハムストリング・エキセントリック",
        "カーフレイズ",
        "ケーブル・グルート・キックバック", "クラムシェル", "ヒップ・アブダクション・マシン", "ヒップ・アダクション・マシン"
    ]

    static let abs: [String] = [
        "腹筋", "腹", "アブ", "腹直筋", "腹斜筋",
        "クランチ", "シットアップ", "レッグレイズ", "バイシクルクランチ",
        "ケーブル・クランチ", "マシン・クランチ",
        "マウンテン・クライマー", "コペンハーゲン・プランク"
    ]

    static let glutes: [String] = [
        "お尻", "臀部", "ヒップ", "グルート", "大臀筋",
        "ヒップスラスト", "ヒップリフト", "ブリッジ",
        "ドンキーキック", "ケーブル・グルート・キックバック", "クラムシェル",
        "ヒップ・アブダクション・マシン", "ヒップ・アダクション・マシン"
    ]

    static let cardio: [String] = [
        "ランニング", "ジョギング", "ウォーキング", "サイクリング", "自転車", "走る", "歩く", "有酸素",
        "水泳", "クロール", "背泳ぎ", "平泳ぎ", "バタフライ", "縄跳び", "ダンス", "エアロビクス",
        "クロスカントリー", "トライアスロン", "ハイキング", "登山"
    ]

    static let core: [String] = [
        "プランク", "サイドプランク", "コア", "体幹", "腰"
    ]

    /// Determine the body part category for an exercise based on keywords and MET value
    static func determineBodyPart(for keys: [String], mets: Double) -> String {
        let allText = keys.joined(separator: " ").lowercased()

        // Check keywords in priority order
        for keyword in chest {
            if allText.contains(keyword.lowercased()) {
                return "胸"
            }
        }

        for keyword in shoulder {
            if allText.contains(keyword.lowercased()) {
                return "肩"
            }
        }

        for keyword in back {
            if allText.contains(keyword.lowercased()) {
                return "背中"
            }
        }

        for keyword in arm {
            if allText.contains(keyword.lowercased()) {
                return "腕"
            }
        }

        for keyword in leg {
            if allText.contains(keyword.lowercased()) {
                return "脚"
            }
        }

        for keyword in abs {
            if allText.contains(keyword.lowercased()) {
                return "腹筋"
            }
        }

        for keyword in glutes {
            if allText.contains(keyword.lowercased()) {
                return "お尻"
            }
        }

        for keyword in cardio {
            if allText.contains(keyword.lowercased()) {
                return "有酸素"
            }
        }

        for keyword in sports {
            if allText.contains(keyword.lowercased()) {
                return "スポーツ"
            }
        }

        for keyword in core {
            if allText.contains(keyword.lowercased()) {
                return "腹筋"
            }
        }

        // Default to cardio based on MET value
        if mets >= 4.0 {
            return "有酸素"
        } else {
            return "有酸素"
        }
    }
}
