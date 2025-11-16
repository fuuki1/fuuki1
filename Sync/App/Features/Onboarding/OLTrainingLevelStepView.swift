import SwiftUI

/// Onboarding step: トレーニング頻度（回/週）を選択する画面
/// - 1〜4 の 4ステップ（4 は 4+ と表示）
/// - 大見出し、カレンダー風のカード、選択値の見出し、補足テキスト、ステップスライダーで構成
struct OLTrainingLevelStepView: View {
    // リポジトリと完了ハンドラを外から渡せるようにする
    var profileRepo: (any SyncingProfileRepository)? = nil
    var onContinue: (() -> Void)? = nil

    /// アプリ全体のユーザープロファイルを保持する DataModel。
    ///
    /// ルートビューから `.environmentObject` で注入される想定で、
    /// 保存前に `trainingPerWeek` をこのモデルに反映させます。
    @EnvironmentObject private var dataModel: DataModel

    @AppStorage("ol_training_per_week") private var storedPerWeek: Int = 3
    @State private var perWeek: Int = 3
    @State private var hapticValue: Int = 3

    var body: some View {
        VStack(spacing: 36) {
            titleSection
            CalendarCard(perWeek: perWeek)
                .frame(width: 240, height: 220)
                .padding(.top, 8)

            // 選択値の見出しと補足＋スライダーを一塊に
            VStack(spacing: 14) {
                VStack(spacing: 6) {
                    Text(titleFor(perWeek))
                        .font(.system(size: 28, weight: .heavy))
                        .foregroundStyle(.primary)
                    Text(subtitleFor(perWeek))
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(.secondary)
                }

                VStack(spacing: 16) {
                    StepSlider(value: $perWeek, range: 1...4)
                        .frame(height: 44)
                    HStack {
                        Text("減らす").font(.system(size: 18, weight: .semibold)).foregroundStyle(.secondary)
                        Spacer()
                        Text("増やす").font(.system(size: 18, weight: .semibold)).foregroundStyle(.secondary)
                    }
                }
            }

            Spacer(minLength: 20)

            // 保存して次へ
            StartPrimaryButton(title: "次へ") {
                Task {
                    await saveTrainingPerWeek(perWeek)
                    onContinue?()
                }
            }
            .padding(.bottom, 4)
        }
        .padding(.horizontal, 24)
        .padding(.top, 32)
        .padding(.bottom, 12)
        .onAppear {
            perWeek = storedPerWeek.clamped(to: 1...4)
            hapticValue = perWeek
        }
        .onChange(of: perWeek) { oldValue, newValue in
            // Haptics（ステップが変わった時のみ）
            if newValue != hapticValue {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                hapticValue = newValue
            }
            storedPerWeek = newValue
        }
    }

    @MainActor
    private func saveTrainingPerWeek(_ value: Int) async {
        // 1) AppStorage（既存）
        storedPerWeek = value

        // 2) DataModel側に流す（環境オブジェクト）。
        dataModel.userProfile.trainingPerWeek = value

        // 3) リポジトリに保存（リモート/ローカル）
        if let repo = profileRepo {
            try? await repo.saveTrainingPerWeek(value)
        }
    }

    private var titleSection: some View {
        Text("ワークアウトを行う\n頻度は？")
            .font(.system(size: 36, weight: .heavy))
            .multilineTextAlignment(.center)
            .foregroundStyle(.primary)
            .padding(.top, 8)
    }

    private func titleFor(_ v: Int) -> String {
        if v >= 4 { return "4回/週" } // 表記はスクショ準拠（4+はカード側で表現）
        return "\(v)回/週"
    }

    private func subtitleFor(_ v: Int) -> String {
        switch v {
        case 1: return "軽めに始めるのが◎"
        case 2: return "無理なく継続しよう！"
        case 3: return "良いペースです！"
        default: return "頻繁なほど良いです！"
        }
    }
}

// MARK: - Calendar Card (画像アセット優先・1〜4対応)
private struct CalendarCard: View {
    let perWeek: Int

    private var imageName: String? {
        switch perWeek {
        case 1: return "カレンダー1"
        case 2: return "カレンダー2"
        case 3: return "カレンダー3"
        case 4: return "カレンダー4"   // 4は4+として扱う
        default: return nil               // 0回/週は画像がなければ描画にフォールバック
        }
    }

    var body: some View {
        if let name = imageName, UIImage(named: name) != nil {
            ZStack {
                RoundedRectangle(cornerRadius: 40, style: .continuous)
                    .fill(Color.white.opacity(0.0001))
                Image(name)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 184, height: 184)
                    .scaleEffect(scaleFor(name))   // ← 画像ごとに拡大率を変える
                    .clipped()
            }
            .frame(width: 240, height: 220)
            .shadow(color: .black.opacity(0.12), radius: 20, x: 0, y: 18)
        } else {
            // アセットがなかった場合の描画版（前と同じ）
            ZStack {
                RoundedRectangle(cornerRadius: 40, style: .continuous)
                    .fill(Color.white)
                    .shadow(color: .black.opacity(0.12), radius: 20, x: 0, y: 18)

                VStack(spacing: 0) {
                    RoundedRectangle(cornerRadius: 36, style: .continuous)
                        .fill(Color(red: 0.73, green: 0.87, blue: 0.76))
                        .frame(height: 62)
                        .overlay(SpiralRings().padding(.horizontal, 32).offset(y: 2))
                    Spacer()
                }
                .clipShape(RoundedRectangle(cornerRadius: 40, style: .continuous))

                Text(perWeek >= 4 ? "4+" : "\(perWeek)")
                    .font(.system(size: 118, weight: .black, design: .rounded))
                    .kerning(-4)
                    .foregroundStyle(Color(red: 74/255, green: 70/255, blue: 216/255))
                    .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
            }
        }
    }

    private func scaleFor(_ name: String) -> CGFloat {
        switch name {
        case "カレンダー1", "カレンダー2", "カレンダー3":
            return 2.6   // ← 4よりひとまわり小さかったので補正
        default:
            return 1.0
        }
    }
}

// 上部リング（綴じ具）
private struct SpiralRings: View {
    var body: some View {
        HStack(spacing: 18) {
            ForEach(0..<4) { _ in
                Capsule()
                    .fill(Color.white.opacity(0.18))
                    .overlay(
                        Capsule()
                            .stroke(Color.white.opacity(0.35), lineWidth: 1)
                    )
                    .frame(width: 28, height: 14)
            }
        }
    }
}

// 折り返し（三角形）
private struct PageFold: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.maxX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}

// MARK: - ステップスライダー (0...4)
private struct StepSlider: View {
    @Binding var value: Int
    let range: ClosedRange<Int>

    var body: some View {
        Slider(
            value: Binding(
                get: { Double(value) },
                set: { value = Int(round($0)).clamped(to: range) }
            ),
            in: Double(range.lowerBound)...Double(range.upperBound),
            step: 1
        )
        .tint(Color(red: 124/255, green: 77/255, blue: 255/255)) // brand purple only
        .accessibilityLabel("ワークアウト頻度")
        .accessibilityValue("\(value)回/週")
        .padding(.horizontal, 4)
    }
}

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}

// MARK: - Preview
struct OLTrainingLevelStepView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            ZStack {
                Color(.systemBackground).ignoresSafeArea()
                OLTrainingLevelStepView()
            }
            .preferredColorScheme(.dark)
            .previewDisplayName("Dark")

            ZStack {
                Color(.systemBackground).ignoresSafeArea()
                OLTrainingLevelStepView()
            }
            .preferredColorScheme(.light)
            .previewDisplayName("Light")
        }
    }
}
