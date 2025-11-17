import SwiftUI
import SwiftData

struct CustomWorkoutCreateView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var name: String = ""
    @State private var durationMin: Int = 30
    @State private var unit: String = "Kcal"
    @State private var calories: Int = 100
    @State private var showingSaveError: Bool = false
    @State private var saveErrorMessage: String = ""

    /// 保存完了後に呼ばれるコールバック（オプショナル）
    var onSaveComplete: (() -> Void)? = nil

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // プレビュー
                    VStack(alignment: .leading, spacing: 12) {
                        Text("効果をプレビュー")
                            .font(.footnote)
                            .foregroundStyle(.secondary)

                        HStack(spacing: 14) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(Color(hex: "EDE7FF"))
                                    .frame(width: 64, height: 64)
                                Image(systemName: "bolt.heart")
                                    .font(.title2)
                                    .foregroundStyle(Color(hex: "7C4DFF"))
                            }
                            VStack(alignment: .leading, spacing: 6) {
                                Text(name.isEmpty ? "運動名" : name)
                                    .font(.headline)
                                Text("\(calories)\(unit)/\(durationMin)分")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                        }
                        .padding(16)
                        .glassEffect(in: .rect(cornerRadius: 16.0))
                    }

                    // 基本情報
                    VStack(alignment: .leading, spacing: 12) {
                        Text("基本情報 *")
                            .font(.subheadline)
                            .fontWeight(.semibold)

                        VStack(alignment: .leading, spacing: 20) {
                            LabeledContent("運動名") {
                                TextField("例：水泳", text: $name)
                                    .multilineTextAlignment(.trailing)
                            }

                            LabeledContent("時長") {
                                Stepper(value: $durationMin, in: 1...240) {
                                    Text("\(durationMin) 分")
                                        .monospacedDigit()
                                }
                            }

                            LabeledContent("カロリー単位") {
                                HStack(spacing: 6) {
                                    Text(unit)
                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }

                            LabeledContent("カロリー消費") {
                                Stepper(value: $calories, in: 1...2000, step: 5) {
                                    Text("\(calories) \(unit)")
                                        .monospacedDigit()
                                }
                            }
                        }
                        .padding(16)
                        .glassEffect(in: .rect(cornerRadius: 16.0))
                    }

                    // オプション情報
                    VStack(alignment: .leading, spacing: 12) {
                        Text("オプション情報")
                            .font(.subheadline)
                            .fontWeight(.semibold)

                        HStack {
                            Text("写真")
                            Spacer()
                            ZStack {
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(Color(white: 0.95))
                                    .frame(width: 44, height: 44)
                                Image(systemName: "camera")
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(16)
                        .glassEffect(in: .rect(cornerRadius: 16.0))
                    }

                    Text("過去の運動データを混同しないように、カスタム運動は作成後に変更できません")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .padding(.top, 8)
                }
                .padding(16)
            }
            .navigationTitle("カスタム運動を作成")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "chevron.backward")
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                                   Button("保存") {
                                       saveCustomWorkout()     // ✅ 保存処理を呼ぶ
                                   }
                                   .fontWeight(.semibold)
                                   .foregroundStyle(canSave ? Color(hex: "7C4DFF") : .secondary)
                                   .disabled(!canSave)
                }
            }
        }
        .tint(Color(hex: "7C4DFF"))
        .alert("保存エラー", isPresented: $showingSaveError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(saveErrorMessage)
        }
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func saveCustomWorkout() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }

        // CustomWorkoutEntity の定義に合わせて、WorkoutRecordView 側で必要なプロパティも埋める
        let workout = CustomWorkoutEntity(
            name: trimmedName
        )
        // 時間とカロリー
        workout.durationMin = Double(durationMin)
        workout.caloriesKcal = calories

        // タグと部位は、ひとまず名前と「カスタム」で初期化
        workout.tags = [trimmedName, "カスタム"]
        workout.bodyPart = "カスタム"

        // 並び替え用の作成日時
        workout.createdAt = Date()

        // ModelContextに挿入
        modelContext.insert(workout)

        // 保存を実行
        do {
            try modelContext.save()

            // 保存成功のハプティックフィードバック
            Haptics.notification(.success)

            // 保存成功後に画面を閉じる
            // Task.yieldで次のrunloopサイクルまで待機してから閉じる
            // これによりSwiftDataの更新が確実に反映される
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 100_000_000) // 0.1秒待機
                // コールバックを実行（カテゴリー切り替えなど）
                onSaveComplete?()
                dismiss()
            }
        } catch {
            // エラー時のハプティックフィードバック
            Haptics.notification(.error)
            // エラー時はアラートを表示
            saveErrorMessage = "カスタムワークアウトの保存に失敗しました: \(error.localizedDescription)"
            showingSaveError = true
        }
    }
}

#Preview {
    CustomWorkoutCreateView()
}
