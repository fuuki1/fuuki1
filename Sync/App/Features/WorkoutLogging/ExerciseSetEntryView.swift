//
//  ExerciseSetEntryView.swift
//  Sync
//
//  Created by 高橋風樹 on 2025/11/14.
//
import SwiftUI
import SwiftData
import Foundation

struct ExerciseSetEntryView: View {
    /// エクササイズ名
    let exerciseName: String
    /// WorkoutRecordViewで選択された日付
    let selectedDate: Date
    
    /// SwiftData用のModelContext
    @Environment(\.modelContext) private var modelContext
    /// ビューを閉じるためのdismissアクション
    @Environment(\.dismiss) private var dismiss
    
    @State private var timerSeconds: Int = 60
    @State private var sets: [ExerciseSet] = [
        ExerciseSet(number: 1),
        ExerciseSet(number: 2),
        ExerciseSet(number: 3),
        ExerciseSet(number: 4)
    ]
    @State private var isFavorite: Bool = false
    @State private var heartScale: CGFloat = 1.0
    @State private var heartRotation: Double = 0
    
    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            LinearGradient(
                colors: [
                    Color(hex: "F4ECFF"),
                    Color.white
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 16) {
                // 上部ヘッダー(お気に入りボタン+タイマー部)
                HStack {
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                            isFavorite.toggle()
                            
                            // ハートのスケールアニメーション
                            heartScale = 1.4
                            heartRotation = isFavorite ? 15 : -15
                        }
                        
                        // お気に入り状態を保存
                        persistFavoriteState()
                        
                        // スケールを元に戻す
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                                heartScale = 1.0
                                heartRotation = 0
                            }
                        }
                        
                        // お気に入りになった時のみパーティクル効果
                        if isFavorite {
                            triggerHapticFeedback()
                        }
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: isFavorite ? "heart.fill" : "heart")
                                .font(.system(size: 20, weight: .semibold))
                                .scaleEffect(heartScale)
                                .rotationEffect(.degrees(heartRotation))
                            Text("お気に入り")
                                .font(.caption2)
                                .fontWeight(.medium)
                        }
                        .foregroundStyle(isFavorite ? Color(hex: "7C4DFF") : .secondary)
                    }
                    .buttonStyle(.plain)
                    
                    Spacer()
                    
                    HStack(spacing: 8) {
                        Image(systemName: "stopwatch")
                            .font(.system(size: 16, weight: .medium))
                        Text("\(timerSeconds)")
                            .font(.headline)
                        Text("sec")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color.white)
                            .shadow(color: .black.opacity(0.08), radius: 6, x: 0, y: 3)
                    )
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                
                // セット一覧
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach($sets) { $set in
                            ExerciseSetRowView(set: $set)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                }
            }
            
            // 画面右下の+ボタン(セット追加)
            Button {
                let next = (sets.last?.number ?? 0) + 1
                sets.append(ExerciseSet(number: next))
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 56, height: 56)
                    .background(
                        Circle()
                            .fill(Color(hex: "7C4DFF"))
                            .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
                    )
            }
            .padding(.trailing, 24)
            .padding(.bottom, 24)
        }
        .navigationTitle(exerciseName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            // 右上に保存ボタンを配置
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("保存") {
                    saveSession()
                }
                .font(.headline)
            }
        }
        .onAppear {
            loadFavoriteState()
        }
    }
    
    // 触覚フィードバック
    private func triggerHapticFeedback() {
        let impact = UIImpactFeedbackGenerator(style: .medium)
        impact.impactOccurred()
    }
}

struct ExerciseSet: Identifiable {
    let id = UUID()
    let number: Int
    var weight: String = ""
    var reps: String = ""
    var memo: String = ""
}

struct ExerciseSetRowView: View {
    @Binding var set: ExerciseSet
    
    var body: some View {
        VStack(spacing: 0) {
            // 1行目: セット / 重さ / 回数 / 補助
            HStack(alignment: .firstTextBaseline, spacing: 16) {
                // セット番号
                VStack(alignment: .leading, spacing: 4) {
                    Text("セット")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(set.number)")
                        .font(.headline)
                }
                .frame(width: 48, alignment: .leading)
                
                // 重さ
                VStack(alignment: .leading, spacing: 4) {
                    Text("重さ")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    TextField("kg", text: $set.weight)
                        .keyboardType(.decimalPad)
                        .textFieldStyle(.plain)
                        .font(.subheadline)
                        .tint(Color(hex: "7C4DFF"))
                    Divider()
                        .opacity(0.15)
                }
                
                // 回数
                VStack(alignment: .leading, spacing: 4) {
                    Text("回数")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    TextField("回", text: $set.reps)
                        .keyboardType(.numberPad)
                        .textFieldStyle(.plain)
                        .font(.subheadline)
                        .tint(Color(hex: "7C4DFF"))
                    Divider()
                        .opacity(0.15)
                }
                
                Spacer(minLength: 8)
                
                // 補助(今はラベルのみ。後でトグル等を追加)
                VStack(alignment: .trailing, spacing: 4) {
                    Text("補助")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    // プレースホルダー: 補助の状態を表示する場所
                    Text("-")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 8)
            
            // 2行目: メモ
            VStack(alignment: .leading, spacing: 4) {
                Text("メモ")
                    .font(.caption)
                    .foregroundColor(.secondary)
                TextField("メモ", text: $set.memo)
                    .textFieldStyle(.plain)
                    .font(.subheadline)
                    .tint(Color(hex: "7C4DFF"))
                Divider()
                    .opacity(0.15)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
        }
        .glassEffect(in: .rect(cornerRadius: 16))
    }
}

struct ExerciseSetEntryView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            // プレビューでは現在の日付を渡す
            ExerciseSetEntryView(
                exerciseName: "チェストプレス",
                selectedDate: Date()
            )
        }
    }
}

// MARK: - Private Helper Methods
extension ExerciseSetEntryView {
    /// ユーザーが入力したデータをWorkoutSessionEntityとして保存。
    /// セッション全体の運動時間と消費カロリーを計算してセットする。
    @MainActor
    private func saveSession() {
        // ユーザー識別子: 現状はデモ用に固定文字列を使用
        let userID = "current_user"
        // 新しいセッションを作成
        let session = WorkoutSessionEntity(
            userID: userID,
            name: exerciseName,
            sessionDate: selectedDate
        )
        
        // エクササイズ単位のエンティティを生成
        let loggedExercise = LoggedExerciseEntity(exerciseName: exerciseName)
        
        // 合計レップ数を取得
        var totalReps: Int = 0
        
        // ユーザーが入力した各セットを保存
        for (index, set) in sets.enumerated() {
            // 数値に変換(空白や記号を除外)
            let weightStr = set.weight.replacingOccurrences(of: "[^0-9.]+", with: "", options: .regularExpression)
            let repsStr = set.reps.replacingOccurrences(of: "[^0-9]+", with: "", options: .regularExpression)
            let weightKg = Double(weightStr) ?? 0
            let reps = Int(repsStr) ?? 0
            totalReps += reps
            let loggedSet = LoggedSetEntity(
                setIndex: index + 1,
                weightKg: weightKg,
                reps: reps,
                isCompleted: true
            )
            loggedExercise.sets.append(loggedSet)
        }
        
        // セッションにエクササイズを追加
        session.exercises.append(loggedExercise)
        
        // セッション全体の運動時間(秒)を計算 (1レップ ≒ 3秒と仮定)
        let totalSeconds = totalReps * 3
        session.durationSeconds = totalSeconds
        
        // ユーザー体重を取得
        let weight = currentUserWeightKg()
        // MET値を取得(repベースなので durationBased=false)
        let met = METValueProvider.shared.metValue(for: exerciseName, isDurationBased: false)
        // 消費カロリーを計算: 1.05 × MET × 体重(kg) × 運動時間(時間)
        let calories = 1.05 * met * weight * (Double(totalSeconds) / 3600.0)
        session.caloriesKcal = max(0, Int(calories.rounded()))
        
        // SwiftDataに挿入
        modelContext.insert(session)
        
        // 保存後に画面を閉じる
        dismiss()
    }
    
    /// ユーザーの体重(kg)を UserDefaults から取得。未設定の場合は70kgをデフォルトとする。
    private func currentUserWeightKg() -> Double {
        let candidateKeys = [
            "weightKg",
            "userWeightKg",
            "OLWeightStepView.userWeightKg",
            "OLWeightStepView.weight"
        ]
        for key in candidateKeys {
            let v = UserDefaults.standard.double(forKey: key)
            if v > 0 {
                return v
            }
        }
        // デフォルト体重(未設定の場合)
        return 70
    }
}

extension ExerciseSetEntryView {
    /// お気に入り状態を UserDefaults から読み込む
    private func loadFavoriteState() {
        let favorites = UserDefaults.standard.stringArray(forKey: "favoriteExerciseNames") ?? []
        isFavorite = favorites.contains(exerciseName)
    }
    
    /// お気に入り状態を UserDefaults に保存する
    private func persistFavoriteState() {
        var favorites = Set(UserDefaults.standard.stringArray(forKey: "favoriteExerciseNames") ?? [])
        if isFavorite {
            favorites.insert(exerciseName)
        } else {
            favorites.remove(exerciseName)
        }
        UserDefaults.standard.set(Array(favorites), forKey: "favoriteExerciseNames")
    }
}
