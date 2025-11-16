//  UIGoalPlanResultView.swift
//  体重目標達成グラフの可視化ビュー
//


import SwiftUI
import Foundation

// 値受け渡し用: 直前ステップから結果を注入して、この画面で即表示する
public struct GoalPlanResultPrefill: Sendable {
    public var currentWeight: Double?
    public var goalWeight: Double?
    public var weeklyRateKg: Double?
    public var weeksNeeded: Double?
    public var targetDate: Date?

    public init(currentWeight: Double? = nil,
                goalWeight: Double? = nil,
                weeklyRateKg: Double? = nil,
                weeksNeeded: Double? = nil,
                targetDate: Date? = nil) {
        self.currentWeight = currentWeight
        self.goalWeight = goalWeight
        self.weeklyRateKg = weeklyRateKg
        self.weeksNeeded = weeksNeeded
        self.targetDate = targetDate
    }
}

// MARK: - 曲線グラフシェイプ
private struct SmoothCurveShape: Shape {
    let points: [CGPoint]
    let tension: CGFloat
    
    func path(in rect: CGRect) -> Path {
        guard points.count >= 2 else { return Path() }
        
        var path = Path()
        path.move(to: points[0])
        
        // より滑らかな曲線を描画
        for i in 0..<points.count - 1 {
            let current = points[i]
            let next = points[i + 1]
            
            // 前後のポイントを考慮したコントロールポイント計算
            let prev = i > 0 ? points[i - 1] : current
            let afterNext = i < points.count - 2 ? points[i + 2] : next
            
            // コントロールポイントを計算(Catmull-Romスプライン風)
            let t = tension
            let controlPoint1 = CGPoint(
                x: current.x + (next.x - prev.x) * t,
                y: current.y + (next.y - prev.y) * t
            )
            let controlPoint2 = CGPoint(
                x: next.x - (afterNext.x - current.x) * t,
                y: next.y - (afterNext.y - current.y) * t
            )
            
            path.addCurve(to: next, control1: controlPoint1, control2: controlPoint2)
        }
        
        return path
    }
}

// MARK: - 曲線下の領域シェイプ(グラデーション用)
private struct SmoothCurveAreaShape: Shape {
    let points: [CGPoint]
    let baselineY: CGFloat
    let tension: CGFloat
    
    func path(in rect: CGRect) -> Path {
        guard points.count >= 2 else { return Path() }
        
        var path = Path()
        
        // 曲線の開始点から開始
        path.move(to: points[0])
        
        // 曲線を描画
        for i in 0..<points.count - 1 {
            let current = points[i]
            let next = points[i + 1]
            
            let prev = i > 0 ? points[i - 1] : current
            let afterNext = i < points.count - 2 ? points[i + 2] : next
            
            let t = tension
            let controlPoint1 = CGPoint(
                x: current.x + (next.x - prev.x) * t,
                y: current.y + (next.y - prev.y) * t
            )
            let controlPoint2 = CGPoint(
                x: next.x - (afterNext.x - current.x) * t,
                y: next.y - (afterNext.y - current.y) * t
            )
            
            path.addCurve(to: next, control1: controlPoint1, control2: controlPoint2)
        }
        
        // 曲線の終点からベースラインまで垂直に降りる
        if let lastPoint = points.last {
            path.addLine(to: CGPoint(x: lastPoint.x, y: baselineY))
        }
        
        // ベースラインに沿って開始点のX座標まで戻る
        if let firstPoint = points.first {
            path.addLine(to: CGPoint(x: firstPoint.x, y: baselineY))
        }
        
        // 開始点に戻って閉じる
        path.closeSubpath()
        
        return path
      }
    }

// MARK: - 三角形シェイプ(吹き出し用)
private struct Triangle: Shape {
    let pointsDown: Bool
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        if pointsDown {
            path.move(to: CGPoint(x: rect.midX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        } else {
            path.move(to: CGPoint(x: rect.midX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        }
        path.closeSubpath()
        return path
    }
}

// MARK: - メインビュー
public struct UIGoalPlanResultView: View {
    let profileRepo: SyncingProfileRepository
    let onContinue: () -> Void
    let prefill: GoalPlanResultPrefill?

    @Environment(\.colorScheme) private var colorScheme

    @State private var currentWeight: Double = 0
    @State private var goalWeight: Double = 0
    @State private var targetDate: Date = Date()
    @State private var weeklyRate: Double = 0
    @State private var isLoading = true
    @State private var animateChart = false
    @State private var showMarker20 = false
    @State private var showMarker90 = false
    // 曲線の曲がり具合(0.0で直線、0.2~0.6で自然なカーブ)
    @State private var curveTension: CGFloat = 0.36

    public init(profileRepo: SyncingProfileRepository,
                onContinue: @escaping () -> Void,
                prefill: GoalPlanResultPrefill? = nil) {
        self.profileRepo = profileRepo
        self.onContinue = onContinue
        self.prefill = prefill

        // Stateの初期値をプレフィルから注入(あるものだけ設定)
        if let v = prefill?.currentWeight { _currentWeight = State(initialValue: v) }
        if let v = prefill?.goalWeight { _goalWeight = State(initialValue: v) }
        if let v = prefill?.weeklyRateKg { _weeklyRate = State(initialValue: v) }

        // 目標日付は (1) 指定あり → それ、(2) weeksNeeded → そこから算出、(3) weeklyRate から逆算、の優先順位
        if let date = prefill?.targetDate {
            _targetDate = State(initialValue: date)
        } else if let w = prefill?.weeksNeeded {
            let d = Calendar.current.date(byAdding: .day, value: Int(w * 7), to: Date()) ?? Date()
            _targetDate = State(initialValue: d)
        } else if let cw = prefill?.currentWeight, let gw = prefill?.goalWeight, let wr = prefill?.weeklyRateKg, wr != 0 {
            let weeks = abs(gw - cw) / abs(wr)
            let d = Calendar.current.date(byAdding: .day, value: Int(weeks * 7), to: Date()) ?? Date()
            _targetDate = State(initialValue: d)
        }

        // プレフィルがあるなら読み込み中フラグは最初からfalse
        _isLoading = State(initialValue: prefill == nil)
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(spacing: 24) {
                        // タイトル
                        titleSection
                        
                        // グラフ
                        chartSection
                            .padding(.vertical, 32)
                        
                    }
                    .padding(.top, 20)
                    .padding(.bottom, 120)
                }
                .safeAreaInset(edge: .bottom) {
                    VStack(spacing: 8) {
                        Text("後で設定で変更できます。")
                            .font(.footnote)
                            .foregroundStyle(Color.primary.opacity(colorScheme == .dark ? 0.9 : 0.75))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 20)
                            .offset(y: -15)

                        StartPrimaryButton(title: "次へ") {
                            onContinue()
                        }
                        .disabled(isLoading)
                        .padding(.horizontal, 20)
                    }
                    .padding(.vertical, 12)
                    .ignoresSafeArea()
                }
            }
        }
        .task {
            await loadData()
        }
    }
    
    // MARK: - タイトルセクション
    private var titleSection: some View {
        VStack(spacing: 8) {
            Text(formatTargetDate(targetDate))
                .font(.system(size: 34, weight: .bold))
                .foregroundStyle(.primary)
            
            Text("\(formatKg(goalWeight))に到達します")
                .font(.system(size: 34, weight: .bold))
                .foregroundStyle(.primary)

            Text("現在 \(formatKg(currentWeight)) → 目標 \(formatKg(goalWeight))")
                .font(.headline)
                .foregroundStyle(.secondary)
        }
        .multilineTextAlignment(.center)
    }
    
    // MARK: - グラフセクション
    private var chartSection: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height: CGFloat = 350
            let horizontalPadding: CGFloat = 0
            let verticalPadding: CGFloat = 50
            
            let chartWidth = width - horizontalPadding * 2
            let chartHeight = height - verticalPadding * 2
            
            // データポイントの生成
            let points = generateDataPoints(
                chartWidth: chartWidth,
                chartHeight: chartHeight,
                horizontalPadding: horizontalPadding,
                verticalPadding: verticalPadding
            )
            
            ZStack {
                // グラデーション領域(曲線の下全体)
                SmoothCurveAreaShape(
                    points: points,
                    baselineY: height,
                    tension: curveTension
                )
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 95/255, green: 134/255, blue: 1.0).opacity(0.3),
                            Color(red: 124/255, green: 77/255, blue: 1.0).opacity(0.2),
                            Color(red: 200/255, green: 200/255, blue: 255/255).opacity(0.1),
                            Color.clear
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .opacity(animateChart ? 1 : 0)
                
                // 曲線
                SmoothCurveShape(points: points, tension: curveTension)
                    .trim(from: 0, to: animateChart ? 1 : 0)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color(red: 95/255, green: 134/255, blue: 1.0),
                                Color(red: 124/255, green: 77/255, blue: 1.0)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        style: StrokeStyle(lineWidth: 6, lineCap: .round, lineJoin: .round)
                    )
                    .shadow(color: Color(red: 95/255, green: 134/255, blue: 1.0).opacity(0.3), radius: 8, x: 0, y: 4)
                
                // 点線グリッド
                VStack(spacing: 0) {
                    ForEach(0..<4) { i in
                        Rectangle()
                            .stroke(style: StrokeStyle(lineWidth: 1, dash: [5, 5]))
                            .foregroundColor(Color.gray.opacity(0.1))
                            .frame(height: 1)
                        if i < 3 {
                            Spacer()
                        }
                    }
                }
                .padding(.vertical, verticalPadding)
                // 20%の位置のポイント
                if showMarker20, points.count > 1 {
                    let index20 = Int(0.13 * Double(points.count - 1))
                    let point20 = points[index20]
                    
                    ZStack {
                        // ポイント円
                        Circle()
                            .fill(Color.white)
                            .frame(width: 20, height: 20)
                            .overlay(
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: [
                                                Color(red: 95/255, green: 134/255, blue: 1.0),
                                                Color(red: 124/255, green: 77/255, blue: 1.0)
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 14, height: 14)
                            )
                            .shadow(color: Color.black.opacity(0.15), radius: 4, x: 0, y: 2)
                            .position(point20)
                        
                        // 体重ラベル(VStackで三角形を下に配置)
                        VStack(spacing: 0) {
                            Text(formatKg(currentWeight))
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(Color(red: 100/255, green: 100/255, blue: 220/255))
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(Color(red: 210/255, green: 205/255, blue: 240/255))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 3)
                            
                            // 吹き出しの三角形(レイアウトの下)
                            Triangle(pointsDown: true)
                                .fill(Color(red: 210/255, green: 205/255, blue: 240/255))
                                .frame(width: 8, height: 4)
                        }
                        .position(x: point20.x, y: point20.y - 40)
                    }
                    .transition(.scale.combined(with: .opacity))
                }
                
                // 90%の位置のポイント
                if showMarker90, points.count > 1 {
                    let index90 = Int(0.9 * Double(points.count - 1))
                    let point90 = points[index90]
                    let progress90 = 0.9
                    let easedProgress90 = smoothCurveImage2(progress90)
                    let weight90 = currentWeight + (goalWeight - currentWeight) * easedProgress90
                    
                    ZStack {
                        // ポイント円
                        Circle()
                            .fill(Color.white)
                            .frame(width: 20, height: 20)
                            .overlay(
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: [
                                                Color(red: 95/255, green: 134/255, blue: 1.0),
                                                Color(red: 124/255, green: 77/255, blue: 1.0)
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 14, height: 14)
                            )
                            .shadow(color: Color.black.opacity(0.15), radius: 4, x: 0, y: 2)
                            .position(point90)
                        
                        // 体重ラベル(VStackで三角形を下に配置)
                        VStack(spacing: 0) {
                            Text(formatKg(weight90))
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(
                                    LinearGradient(
                                        colors: [
                                            Color(red: 95/255, green: 134/255, blue: 1.0),
                                            Color(red: 124/255, green: 77/255, blue: 1.0)
                                        ],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
                            
                            // 吹き出しの三角形(レイアウトの下、グラデーション適用)
                            Triangle(pointsDown: true)
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color(red: 95/255, green: 134/255, blue: 1.0),
                                            Color(red: 124/255, green: 77/255, blue: 1.0)
                                        ],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: 8, height: 4)
                        }
                        .position(x: point90.x, y: point90.y - 32)
                    }
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .frame(width: width, height: height)
        }
        .frame(height: 350)
        .onAppear {
            // 1. 曲線の描画アニメーション(1.5秒)
            withAnimation(.easeInOut(duration: 1.5)) {
                animateChart = true
            }
            
            // 2. 20%地点のマーカー表示(曲線が20%に到達する0.2秒後)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                    showMarker20 = true
                }
            }
            
            // 3. 90%地点のマーカー表示(曲線が90%に到達する1.35秒後)
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.35) {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                    showMarker90 = true
                }
            }
        }
    }
    
    // MARK: - データポイント生成
    private func generateDataPoints(chartWidth: CGFloat, chartHeight: CGFloat, horizontalPadding: CGFloat, verticalPadding: CGFloat) -> [CGPoint] {
        let steps = 100 // ポイント数を増やして非常に滑らかな曲線に
        var points: [CGPoint] = []
        
        let weightDiff = goalWeight - currentWeight
        
        for i in 0...steps {
            let progress = Double(i) / Double(steps)
            
            // 三次エルミート補間による滑らかなS字カーブ
            let easedProgress = smoothCurveImage2(progress)
            
            let x = horizontalPadding + chartWidth * CGFloat(progress)
            
            // 体重の変化を計算(シンプルなS字カーブのみ)
            let baseWeight = currentWeight + weightDiff * easedProgress
            let weight = baseWeight
            
            // Y座標を計算(上が大きい値、下が小さい値)
            let minWeight = min(currentWeight, goalWeight) - abs(weightDiff) * 0.1
            let maxWeight = max(currentWeight, goalWeight) + abs(weightDiff) * 0.1
            let weightRange = maxWeight - minWeight
            
            let normalizedWeight = (weight - minWeight) / weightRange
            let y = verticalPadding + chartHeight * CGFloat(1 - normalizedWeight)
            
            points.append(CGPoint(x: x, y: y))
        }
        
        return points
    }
    
    // MARK: - 画像2向け:滑らかなS字(C1連続・わずかな終盤の水平~微下り込み)
    @inline(__always)
    private func smoothCurveImage2(_ t: Double) -> Double {
        // 0~1 の進捗に対するアンカー(画像のプロポーションに合わせ調整)
        // xs: 進捗位置, ys: 高さ(正規化), ms: 各点の接線(傾き)
        let xs: [Double] = [0.00, 0.18, 0.38, 0.6, 0.75, 0.88, 0.9, 1.00]
        let ys: [Double] = [0.00, 0.06, 0.5, 0.65, 0.92, 0.98, 1.00, 1.00]
        // 接線は視覚合わせ。前半は弱~中、中央は強め、終盤は水平寄り、最後は微下り。
        let ms: [Double] = [0.20, 0.50, 1.30, 1.55, 0.70, 0.25, 0.10, -0.15]
        let x = max(0.0, min(1.0, t))
        // どの区間かを検索
        var i = xs.count - 2
        for j in 0..<(xs.count - 1) where x < xs[j + 1] {
            i = j; break
        }
        // 区間端点
        let x0 = xs[i], x1 = xs[i + 1]
        let y0 = ys[i], y1 = ys[i + 1]
        let m0 = ms[i], m1 = ms[i + 1]
        // 区間内変数
        let h = x1 - x0
        let u = (x - x0) / h
        // 三次エルミート基底(C1連続)
        let h00 = (2*u*u*u - 3*u*u + 1)
        let h10 = (u*u*u - 2*u*u + u)
        let h01 = (-2*u*u*u + 3*u*u)
        let h11 = (u*u*u - u*u)
        return h00*y0 + h10*h*m0 + h01*y1 + h11*h*m1
    }
    
    @inline(__always)
    private func smoothCurveImage2(_ t: CGFloat) -> CGFloat {
        CGFloat(smoothCurveImage2(Double(t)))
    }
    
    // MARK: - データ読み込み
    private func loadData() async {
        do {
            let profile = try await profileRepo.getProfile()
            let goal = profile.goal
            let plan = goal?.planSelection

            // Source of truth: repository first; treat 0 as unset so prefill can take precedence
            let repoCurrent = profile.weightKg
            let currentWt = (repoCurrent.flatMap { $0 > 0 ? $0 : nil } ?? prefill?.currentWeight) ?? 0
            let goalWt = (goal?.goalWeightKg ?? prefill?.goalWeight) ?? currentWt
            let weekly = (plan?.weeklyRateKg ?? prefill?.weeklyRateKg) ?? 0

            // Target date precedence: prefill.targetDate > goal.targetDate > computed from weekly rate
            var resolvedTarget = prefill?.targetDate ?? goal?.targetDate
            if resolvedTarget == nil, weekly != 0 {
                let weeks = abs(goalWt - currentWt) / abs(weekly)
                resolvedTarget = Calendar.current.date(byAdding: .day, value: Int(weeks * 7), to: Date())
            }

            await MainActor.run {
                self.currentWeight = currentWt
                self.goalWeight = goalWt
                self.weeklyRate = weekly
                if let d = resolvedTarget { self.targetDate = d }
                self.isLoading = false
            }
        } catch {
            print("Failed to load profile: \(error)")
            await MainActor.run { self.isLoading = false }
        }
    }
    
    // MARK: - ヘルパー関数
    private func formatTargetDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M月d日に"
        return formatter.string(from: date)
    }
    
    private func formatFullDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy年M月d日"
        return formatter.string(from: date)
    }
    private func formatKg(_ x: Double) -> String {
        String(format: "%.1fkg", x)
    }
    
    private func calculateWeeks() -> Int {
        if weeklyRate == 0 { return 0 }
        let weeks = abs(goalWeight - currentWeight) / abs(weeklyRate)
        return Int(weeks.rounded())
    }
}

// MARK: - プレビュー
#if DEBUG
struct UIGoalPlanResultView_Previews: PreviewProvider {
    static var previews: some View {
        let repo = DefaultSyncingProfileRepository.makePreview()
        
        UIGoalPlanResultView(
            profileRepo: repo,
            onContinue: {}
        )
        .task {
            try? await repo.updateWeightKg(55.0)
            try? await repo.updateGoal(
                GoalProfile(
                    type: .loseFat,
                    goalWeightKg: 75,
                    planSelection: GoalPlanSelection(
                        difficulty: .normal,
                        weeklyRateKg: 0.5,
                        dailyCalorieIntake: 2000,
                        weeksNeeded: 10,
                        selectedAt: Date(),
                        planTitle: "普通"
                    ),
                    targetDate: nil
                )
            )
        }
        .previewDisplayName("減量プラン結果")
    }
}
#endif
