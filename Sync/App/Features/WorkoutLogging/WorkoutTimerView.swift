import SwiftUI
import UIKit

enum TimerMode: Sendable, Equatable {
    case workoutInProgress
    case resting
}

// Ensure Equatable is available from nonisolated contexts under Swift 6 mode
extension TimerMode {
    nonisolated static func == (lhs: Self, rhs: Self) -> Bool {
        switch (lhs, rhs) {
        case (.workoutInProgress, .workoutInProgress),
             (.resting, .resting):
            return true
        default:
            return false
        }
    }
}

struct WorkoutTimerView: View {
    
    let day: DaySchedule?
    @Binding var navigationPath: NavigationPath
    
    init(day: DaySchedule? = nil, navigationPath: Binding<NavigationPath>) {
        self.day = day
        self._navigationPath = navigationPath
    }
    
    @State private var showPauseOverlay = false
    
    @State private var exIndex: Int = 0
    @State private var setIndex: Int = 0
    @State private var mode: TimerMode = .workoutInProgress
    @State private var remaining: Int = 60
    @State private var isRunning: Bool = false
    @State private var timer: Timer?
    @State private var totalElapsedTime: Int = 0
    
    // ✅ 完了したエクササイズのインデックス配列を追跡
    @State private var completedExerciseIndices: [Int] = []
    
    // ✅ 回数式セットの開始時刻を記録
    @State private var currentSetStartTime: Date? = nil

    /// セッション中に記録された各セットのログを保持する
    /// exerciseIndex: エクササイズのインデックス、setIndex: 1始まりのセット番号
    /// weightKg: 使用重量(kg)、reps: 実施回数
    @State private var setLogs: [SetLog] = []

    // ✅ リファクタリング版の PaceProvider を使用
    @StateObject private var paceProvider = PaceProvider()
    
    var body: some View {
        VStack(spacing: 0) {
            if mode == .workoutInProgress {
                HStack {
                    Spacer()
                    progressPill
                }
                .padding(.horizontal, 24)
                .padding(.top, 24)
            }

            if mode == .workoutInProgress {
                workoutExecutionView
                    .transition(.scale.combined(with: .opacity))

                if let info = currentSetInfo() {
                    exerciseInfoCard(info: info)
                        .padding(.horizontal, 24)
                        .padding(.top, 24)
                }
            } else {
                restScreenContent
                    .transition(.scale.combined(with: .opacity))
            }

            Spacer()

            if mode == .workoutInProgress {
                controlButtons
                    .padding(.horizontal, 24)
                    .padding(.bottom, 32)
            }
        }
        .navigationBarBackButtonHidden(true)
        .overlay {
            if showPauseOverlay {
                PauseOverlay(
                    percent: overlayPercent,
                    remainingCount: overlayRemaining,
                    onResume: {
                        Haptics.tick()
                        isRunning = false
                        withAnimation(.easeOut(duration: 0.12)) {
                            showPauseOverlay = false
                        }
                    },
                    onRestart: {
                        Haptics.notification(.warning)
                        restartCurrentExercise()
                        showPauseOverlay = false
                    },
                    onQuit: {
                        Haptics.notification(.error)
                        isRunning = false
                        timer?.invalidate()
                        withAnimation(.easeOut(duration: 0.12)) {
                            showPauseOverlay = false
                        }
                        navigationPath.removeLast(navigationPath.count)
                    }
                )
                .zIndex(1000)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if !showPauseOverlay {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        Haptics.lightTick()
                        withAnimation(.easeOut(duration: 0.12)) {
                            isRunning = false
                            showPauseOverlay = true
                        }
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .labelStyle(.iconOnly)
                    .accessibilityLabel("閉じる")
                }
            }

            if !showPauseOverlay && mode == .workoutInProgress {
                ToolbarItem(placement: .principal) {
                    progressBar
                        .frame(width: 260, height: 6)
                        .fixedSize()
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }
            }
        }
        .onAppear {
            bootstrap()
            startTicking()
        }
        .onDisappear {
            timer?.invalidate()
        }
    }
    
    // MARK: - Top Info Bar
    
    private var progressPill: some View {
        HStack(spacing: 6) {
            Image(systemName: mode == .workoutInProgress ? "bolt.fill" : "flame.fill")
                .font(.caption)
                .foregroundStyle(
                    mode == .workoutInProgress ?
                    LinearGradient(colors: [Color.green, Color.blue], startPoint: .topLeading, endPoint: .bottomTrailing) :
                    LinearGradient(colors: [Color.orange, Color.red], startPoint: .topLeading, endPoint: .bottomTrailing)
                )
            
            Text("\(overlayPercent)%")
                .font(.caption.weight(.semibold))
                .monospacedDigit()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(.ultraThinMaterial)
                .glassEffect()
        )
    }
    
    private var progressBar: some View {
        GeometryReader { geo in
            HStack(spacing: 8) {
                if let d = day {
                    ForEach(0..<d.exercises.count, id: \.self) { exerciseIndex in
                        let exercise = d.exercises[exerciseIndex]
                        let setCount = totalSets(for: exercise)
                        
                        HStack(spacing: 2) {
                            ForEach(0..<setCount, id: \.self) { setIndexInExercise in
                                Capsule()
                                    .fill(setSegmentFillColor(exerciseIndex: exerciseIndex, setIndexInExercise: setIndexInExercise))
                            }
                        }
                    }
                }
            }
        }
        .frame(height: 6)
        .overlay(
            LinearGradient(
                colors: [Color.green, Color.blue, Color.cyan],
                startPoint: .leading,
                endPoint: .trailing
            )
            .mask(
                GeometryReader { geo in
                    HStack(spacing: 8) {
                        if let d = day {
                            ForEach(0..<d.exercises.count, id: \.self) { exerciseIndex in
                                let exercise = d.exercises[exerciseIndex]
                                let setCount = totalSets(for: exercise)
                                
                                HStack(spacing: 2) {
                                    ForEach(0..<setCount, id: \.self) { setIndexInExercise in
                                        Capsule()
                                            .fill(setSegmentFillColor(exerciseIndex: exerciseIndex, setIndexInExercise: setIndexInExercise))
                                    }
                                }
                            }
                        }
                    }
                }
            )
        )
        .animation(.easeInOut(duration: 0.22), value: exIndex)
        .animation(.easeInOut(duration: 0.22), value: setIndex)
        .animation(.easeInOut(duration: 0.22), value: mode)
    }
    
    private func setSegmentFillColor(exerciseIndex: Int, setIndexInExercise: Int) -> AnyShapeStyle {
        if exerciseIndex < exIndex {
            return AnyShapeStyle(LinearGradient(colors: [Color.green, Color.blue], startPoint: .leading, endPoint: .trailing))
        } else if exerciseIndex == exIndex {
            if setIndexInExercise <= setIndex {
                return AnyShapeStyle(LinearGradient(colors: [Color.green, Color.blue], startPoint: .leading, endPoint: .trailing))
            } else {
                return AnyShapeStyle(Color.primary.opacity(0.18))
            }
        } else {
            return AnyShapeStyle(Color.primary.opacity(0.18))
        }
    }
    
    // MARK: - Rest Screen Content
    
    private var restScreenContent: some View {
        VStack(spacing: 0) {
            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "cup.and.saucer.fill")
                        .font(.title)
                        .foregroundStyle(
                            LinearGradient(colors: [Color.orange, Color.red], startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                    
                    Text("休憩中")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(colors: [Color.orange, Color.red], startPoint: .leading, endPoint: .trailing)
                        )
                }
                
                Text("水分補給をお忘れなく")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.bottom, 32)
            
            restTimerView
            
            restModeButtonsBelow
                .padding(.horizontal, 24)
                .padding(.top, 32)
            
            if let nextInfo = nextSetInfo() {
                nextSessionCard(info: nextInfo)
                    .padding(.horizontal, 24)
                    .padding(.top, 20)
            }
        }
    }
    
    // MARK: - Workout Execution View
    
    @ViewBuilder
    private var workoutExecutionView: some View {
        if isTimerBased() {
            timerBasedWorkoutView
        } else {
            // TimelineViewで1秒ごとに更新
            TimelineView(.periodic(from: Date(), by: 1.0)) { context in
                repBasedWorkoutView
            }
        }
    }
    
    private var timerBasedWorkoutView: some View {
        VStack(spacing: 16) {
            Text("⏱️ タイマー式エクササイズ")
                .font(.headline)
                .foregroundStyle(.green)

            ZStack {
                Circle()
                    .strokeBorder(.ultraThinMaterial, lineWidth: 20)
                    .frame(width: 280, height: 280)

                Circle()
                    .trim(from: 0, to: workoutProgressFraction)
                    .stroke(
                        AngularGradient(
                            gradient: Gradient(colors: [
                                Color.green,
                                Color.blue,
                                Color.cyan,
                                Color.green
                            ]),
                            center: .center
                        ),
                        style: StrokeStyle(lineWidth: 20, lineCap: .round)
                    )
                    .frame(width: 260, height: 260)
                    .rotationEffect(.degrees(-90))
                    .shadow(color: Color.green.opacity(0.5), radius: 10)
                    .animation(.spring(response: 0.6, dampingFraction: 0.8), value: workoutProgressFraction)

                VStack(spacing: 8) {
                    Text(timeText(remaining))
                        .monospacedDigit()
                        .font(.system(size: 64, weight: .bold, design: .rounded))
                        .foregroundStyle(.green)

                    Text(isRunning ? "実行中" : "一時停止")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                        .tracking(1.2)
                }
            }
        }
        .padding(.top, 1)
    }
    
    private var repBasedWorkoutView: some View {
        let targetRepsValue = targetReps() ?? 0
        let estimate = estimatedSecondsForCurrentRepSet()
        let elapsed = currentSetElapsedSeconds()
        
        return VStack(spacing: 32) {
            VStack(spacing: 16) {
                Text("💪 回数式エクササイズ")
                    .font(.headline)
                    .foregroundStyle(.blue)
                
                ZStack {
                    // Background circle
                    Circle()
                        .strokeBorder(.ultraThinMaterial, lineWidth: 20)
                        .frame(width: 280, height: 280)
                    
                    // Estimated time guide ring (static, light)
                    if estimate != nil {
                        Circle()
                            .trim(from: 0, to: 1.0)
                            .stroke(
                                Color.blue.opacity(0.15),
                                style: StrokeStyle(lineWidth: 20, lineCap: .round)
                            )
                            .frame(width: 260, height: 260)
                            .rotationEffect(.degrees(-90))
                    }
                    
                    // Actual elapsed time ring
                    if let est = estimate, elapsed > 0 {
                        Circle()
                            .trim(from: 0, to: min(Double(elapsed) / Double(est), 1.5))
                            .stroke(
                                AngularGradient(
                                    gradient: Gradient(colors:
                                        elapsed <= est ? [
                                            Color.blue,
                                            Color.cyan,
                                            Color.purple,
                                            Color.blue
                                        ] : [
                                            Color.orange,
                                            Color.red,
                                            Color.pink,
                                            Color.orange
                                        ]
                                    ),
                                    center: .center
                                ),
                                style: StrokeStyle(lineWidth: 20, lineCap: .round)
                            )
                            .frame(width: 260, height: 260)
                            .rotationEffect(.degrees(-90))
                            .shadow(color: (elapsed <= est ? Color.blue : Color.orange).opacity(0.5), radius: 10)
                            .animation(.spring(response: 0.6, dampingFraction: 0.8), value: elapsed)
                    }
                    
                    VStack(spacing: 8) {
                        Text("目標回数")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)
                            .tracking(1.2)
                        
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text("\(targetRepsValue)")
                                .font(.system(size: 80, weight: .bold, design: .rounded))
                                .foregroundStyle(.blue)
                                .monospacedDigit()
                            
                            Text("回")
                                .font(.title2.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .baselineOffset(4)
                        }
                        
                        if let est = estimate {
                            HStack(spacing: 16) {
                                VStack(spacing: 2) {
                                    Text("目安")
                                        .font(.caption2)
                                        .foregroundStyle(.tertiary)
                                    Text(timeText(est))
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(.secondary)
                                        .monospacedDigit()
                                }
                                
                                if elapsed > 0 {
                                    Divider()
                                        .frame(height: 30)
                                    
                                    VStack(spacing: 2) {
                                        Text("経過")
                                            .font(.caption2)
                                            .foregroundStyle(.tertiary)
                                        Text(timeText(elapsed))
                                            .font(.subheadline.weight(.bold))
                                            .foregroundStyle(elapsed <= est ? .blue : .orange)
                                            .monospacedDigit()
                                    }
                                }
                            }
                            .padding(.top, 8)
                        }
                    }
                }
            }
        }
        .padding(.vertical, 2)
        .onAppear {
            if !isTimerBased() && currentSetStartTime == nil {
                currentSetStartTime = Date()
            }
        }
    }
    
    // 現在のセットの経過秒数を計算
    private func currentSetElapsedSeconds() -> Int {
        guard let startTime = currentSetStartTime else { return 0 }
        return max(0, Int(Date().timeIntervalSince(startTime)))
    }
    
    private var restTimerView: some View {
        ZStack {
            Circle()
                .strokeBorder(.ultraThinMaterial, lineWidth: 20)
                .frame(width: 280, height: 280)
            
            Circle()
                .trim(from: 0, to: restProgressFraction)
                .stroke(
                    AngularGradient(
                        gradient: Gradient(colors: [
                            Color.orange,
                            Color.red,
                            Color.pink,
                            Color.orange
                        ]),
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: 20, lineCap: .round)
                )
                .frame(width: 260, height: 260)
                .rotationEffect(.degrees(-90))
                .shadow(color: Color.orange.opacity(0.5), radius: 10)
                .animation(.spring(response: 0.6, dampingFraction: 0.8), value: restProgressFraction)
            
            VStack(spacing: 8) {
                Text(timeText(remaining))
                    .monospacedDigit()
                    .font(.system(size: 64, weight: .bold, design: .rounded))
                    .foregroundStyle(.orange)
                
                Text(isRunning ? "カウントダウン中" : "一時停止")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .tracking(1.2)
            }
        }
    }
    
    private var workoutProgressFraction: Double {
        guard let ex = currentExercise() else { return 0 }
        let initial = Double(workoutDuration(for: ex))
        let current = Double(max(0, remaining))
        return (initial - current) / max(1, initial)
    }
    
    private var restProgressFraction: Double {
        let initial = Double(suggestedRestForCurrent() ?? 30)
        let current = Double(max(0, remaining))
        return (initial - current) / max(1, initial)
    }
    
    private func exerciseInfoCard(info: (name: String, setNow: Int, setAll: Int, workloadText: String)) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: mode == .workoutInProgress ? "figure.run" : "figure.cooldown")
                    .font(.title2)
                    .foregroundStyle(
                        mode == .workoutInProgress ?
                        LinearGradient(colors: [Color.green, Color.blue], startPoint: .topLeading, endPoint: .bottomTrailing) :
                        LinearGradient(colors: [Color.orange, Color.red], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                
                Text(info.name)
                    .font(.title2.weight(.semibold))
                
                Spacer()
            }

            if let tips = standbyNotesForCurrent(), !tips.isEmpty {
                TipsFlowLayout(spacing: 12, lineSpacing: 6, maxItemWidth: 240) {
                    ForEach(tips, id: \.self) { tip in
                        noteItem(tip)
                    }
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color(.systemGray5).opacity(0.35))
                        .glassEffect()
                )
            }
            
            HStack(spacing: 20) {
                statPill(label: "セット", value: "\(info.setNow)/\(info.setAll)")
                statPill(label: "負荷", value: info.workloadText)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.ultraThinMaterial)
                .glassEffect()
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(
                            mode == .workoutInProgress ?
                            LinearGradient(colors: [Color.green, Color.blue], startPoint: .topLeading, endPoint: .bottomTrailing) :
                            LinearGradient(colors: [Color.orange, Color.red], startPoint: .topLeading, endPoint: .bottomTrailing),
                            lineWidth: 0.5
                        )
                )
        )
    }
    
    // MARK: - Next Session Card
    
    private func nextSessionCard(info: (name: String, setNow: Int, setAll: Int, workloadText: String)) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "arrow.right.circle.fill")
                    .font(.title3)
                    .foregroundStyle(
                        LinearGradient(colors: [Color.blue, Color.cyan], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                
                Text("次のセッション")
                    .font(.headline)
                    .foregroundStyle(.blue)
                
                Spacer()
            }
            
            Divider()
                .background(Color.blue.opacity(0.3))
            
            HStack {
                Image(systemName: "figure.run")
                    .font(.title2)
                    .foregroundStyle(
                        LinearGradient(colors: [Color.blue, Color.cyan], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                
                Text(info.name)
                    .font(.title3.weight(.semibold))
                
                Spacer()
            }
            
            HStack(spacing: 20) {
                statPill(label: "セット", value: "\(info.setNow)/\(info.setAll)")
                statPill(label: "負荷", value: info.workloadText)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.ultraThinMaterial)
                .glassEffect()
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(
                            LinearGradient(colors: [Color.blue, Color.cyan], startPoint: .topLeading, endPoint: .bottomTrailing),
                            lineWidth: 1.5
                        )
                )
        )
    }
    
    private func statPill(label: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.footnote.weight(.medium))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.5)
            
            Text(value)
                .font(.title3.weight(.semibold))
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(.systemGray6).opacity(0.5))
                .glassEffect()
        )
    }
    
    // MARK: - Control Buttons
    
    private var controlButtons: some View {
        HStack(spacing: 12) {
            if mode == .workoutInProgress {
                workoutModeButtons
            } else {
                restModeButtons
            }
        }
    }
    
    @ViewBuilder
    private var workoutModeButtons: some View {
        if isTimerBased() {
            Button {
                toggleTimer()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: isRunning ? "pause.fill" : "play.fill")
                        .font(.title3)
                    Text(isRunning ? "一時停止" : "開始")
                        .font(.title3.weight(.semibold))
                }
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .foregroundStyle(.white)
                .background(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .fill(LinearGradient(colors: [Color.green, Color.blue], startPoint: .topLeading, endPoint: .bottomTrailing))
                )
            }
            .buttonStyle(ScaleButtonStyle())

            Button {
                startRestThenSkipCurrentSet()
            } label: {
                Image(systemName: "forward.fill")
                    .font(.title3)
                    .foregroundColor(.white)
            }
            .frame(width: 56, height: 56)
            .background(
                Circle()
                    .fill(Color.syncGreen)
                    .glassEffect(in: .circle)
                    .overlay(
                        Circle().stroke(.white.opacity(0.18), lineWidth: 1)
                    )
            )
            .buttonStyle(ScaleButtonStyle())
            .accessibilityLabel("スキップ")
            .overlay(alignment: .bottom) {
                Text("スキップ")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .offset(y: 18)
                    .allowsHitTesting(false)
            }
        } else {
            Button {
                goToPreviousSet()
            } label: {
                Image(systemName: "backward.fill")
                    .font(.title3)
                    .foregroundColor(.blue)
            }
            .frame(width: 56, height: 56)
            .background(Circle().fill(.ultraThinMaterial).glassEffect())
            .buttonStyle(ScaleButtonStyle())
            .disabled(exIndex == 0 && setIndex == 0)
            .opacity((exIndex == 0 && setIndex == 0) ? 0.3 : 1.0)
            .accessibilityLabel("戻る")
            
            Button {
                completeWorkoutSet()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                    Text("完了")
                        .font(.title3.weight(.semibold))
                }
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .foregroundStyle(.white)
                .background(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .fill(LinearGradient(colors: [Color.blue, Color.cyan], startPoint: .topLeading, endPoint: .bottomTrailing))
                )
            }
            .buttonStyle(ScaleButtonStyle())
            
            Button {
                startRestThenSkipCurrentSet()
            } label: {
                Image(systemName: "forward.fill")
                    .font(.title3)
                    .foregroundColor(.blue)
            }
            .frame(width: 56, height: 56)
            .background(Circle().fill(.ultraThinMaterial).glassEffect())
            .buttonStyle(ScaleButtonStyle())
            .accessibilityLabel("スキップ")
            .overlay(alignment: .bottom) {
                Text("スキップ")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .offset(y: 18)
                    .allowsHitTesting(false)
            }
        }
    }
    
    private var restModeButtons: some View {
        Group {
            Button {
                goToPreviousSet()
            } label: {
                Image(systemName: "backward.fill")
                    .font(.title3)
                    .foregroundColor(.orange)
            }
            .frame(width: 56, height: 56)
            .background(Circle().fill(.ultraThinMaterial))
            .buttonStyle(ScaleButtonStyle())
            .disabled(exIndex == 0 && setIndex == 0)
            .opacity((exIndex == 0 && setIndex == 0) ? 0.3 : 1.0)

            Button {
                toggleTimer()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: isRunning ? "pause.fill" : "play.fill")
                        .font(.title3)
                    Text(isRunning ? "一時停止" : "開始")
                        .font(.title3.weight(.semibold))
                }
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .foregroundStyle(.white)
                .background(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .fill(LinearGradient(colors: [Color.orange, Color.red], startPoint: .topLeading, endPoint: .bottomTrailing))
                )
            }
            .buttonStyle(ScaleButtonStyle())

            Button {
                remaining = 0
                skipToNextSet()
            } label: {
                Image(systemName: "forward.fill")
                    .font(.title3)
                    .foregroundColor(.orange)
            }
            .frame(width: 56, height: 56)
            .background(Circle().fill(.ultraThinMaterial).glassEffect())
            .buttonStyle(ScaleButtonStyle())
            .accessibilityLabel("スキップ")
            .overlay(alignment: .bottom) {
                Text("スキップ")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .offset(y: 18)
                    .allowsHitTesting(false)
            }
        }
    }
    
    private var restModeButtonsBelow: some View {
        HStack(spacing: 12) {
            Button {
                remaining += 20
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                    Text("+20秒")
                        .font(.title3.weight(.semibold))
                }
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .foregroundStyle(.white)
                .background(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .fill(LinearGradient(colors: [Color.blue, Color.cyan], startPoint: .topLeading, endPoint: .bottomTrailing))
                )
            }
            .buttonStyle(ScaleButtonStyle())

            Button {
                remaining = 0
                skipToNextSet()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "forward.fill")
                        .font(.title3)
                    Text("スキップ")
                        .font(.title3.weight(.semibold))
                }
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .foregroundStyle(.white)
                .background(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .fill(LinearGradient(colors: [Color.orange, Color.red], startPoint: .topLeading, endPoint: .bottomTrailing))
                )
            }
            .buttonStyle(ScaleButtonStyle())
        }
    }
    
    // MARK: - Logic
    
    private func bootstrap() {
        mode = .workoutInProgress
        
        if isTimerBased() {
            remaining = workoutDuration(for: currentExercise() ?? PlanExercise(name: "", sets: "0", reps: "", weight: "", duration: "", notes: ""))
            currentSetStartTime = nil
        } else {
            currentSetStartTime = Date()
        }
        
        totalElapsedTime = 0
        completedExerciseIndices = []
    }
    
    private func startRestThenSkipCurrentSet() {
        // セットタイマーをリセット
        currentSetStartTime = nil
        
        withAnimation(.easeInOut(duration: 0.3)) {
            mode = .resting
        }
        remaining = 30
        isRunning = true
    }
    
    private func startTicking() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            guard isRunning else { return }

            totalElapsedTime += 1

            guard remaining > 0 else {
                if mode == .workoutInProgress && isTimerBased() {
                    completeWorkoutSet()
                } else if mode == .resting {
                    skipToNextSet()
                }
                return
            }
            remaining -= 1
        }
        timer?.tolerance = 0.1
    }
    
    private func toggleTimer() {
        isRunning.toggle()
    }
    
    private func completeWorkoutSet() {
        guard let d = day else { return }

        // まず現在のセットをログに記録する
        recordCurrentSetLog()
        
        if let ex = currentExercise() {
            let total = totalSets(for: ex)
            let isLastSetOfExercise = (setIndex + 1 >= total)
            let isLastExercise = (exIndex >= d.exercises.count - 1)
            
            // ✅ 最後のセットを完了したら、このエクササイズを完了リストに追加
            if isLastSetOfExercise && !completedExerciseIndices.contains(exIndex) {
                completedExerciseIndices.append(exIndex)
            }
            
            // 最後のエクササイズの最後のセットなら、完了画面に直接遷移
            if isLastSetOfExercise && isLastExercise {
                isRunning = false
                timer?.invalidate()
                
                navigationPath.append(
                    WorkoutNavigationDestination.completionView(
                        day: d,
                        elapsedSeconds: totalElapsedTime,
                        isFullCompletion: true,
                        completedExerciseIndices: completedExerciseIndices,
                        setLogs: setLogs
                    )
                )
                return
            }
        }
        
        // セットタイマーをリセット
        currentSetStartTime = nil
        
        withAnimation(.easeInOut(duration: 0.3)) {
            mode = .resting
        }
        remaining = 30
        isRunning = true
    }
    
    private func skipToNextSet() {
        guard let d = day else { return }

        // スキップ前に現在のセットをログに記録する
        recordCurrentSetLog()
        
        if let ex = currentExercise() {
            let total = totalSets(for: ex)
            if setIndex + 1 < total {
                setIndex += 1
            } else {
                setIndex = 0
                exIndex += 1
                
                if exIndex >= d.exercises.count {
                    isRunning = false
                    timer?.invalidate()
                    
                    navigationPath.append(
                        WorkoutNavigationDestination.completionView(
                            day: d,
                            elapsedSeconds: totalElapsedTime,
                            isFullCompletion: completedExerciseIndices.count == d.exercises.count,
                            completedExerciseIndices: completedExerciseIndices,
                            setLogs: setLogs
                        )
                    )
                    return
                }
            }
        }
        
        withAnimation(.easeInOut(duration: 0.3)) {
            mode = .workoutInProgress
        }
        
        if isTimerBased() {
            remaining = workoutDuration(for: currentExercise() ?? PlanExercise(name: "", sets: "0", reps: "", weight: "", duration: "", notes: ""))
        } else {
            // 回数式の場合、セットタイマーをリセット
            currentSetStartTime = Date()
        }
        
        isRunning = false
    }
    
    private func goToPreviousSet() {
        guard !(exIndex == 0 && setIndex == 0) else { return }
        
        if setIndex > 0 {
            setIndex -= 1
        } else {
            exIndex -= 1
            if let ex = currentExercise() {
                setIndex = max(0, totalSets(for: ex) - 1)
            }
        }
        
        withAnimation(.easeInOut(duration: 0.3)) {
            mode = .workoutInProgress
        }
        
        if isTimerBased() {
            remaining = workoutDuration(for: currentExercise() ?? PlanExercise(name: "", sets: "0", reps: "", weight: "", duration: "", notes: ""))
        } else {
            // 回数式の場合、セットタイマーをリセット
            currentSetStartTime = Date()
        }
        
        isRunning = false
    }
    
    // MARK: - Helpers
    
    private func currentExercise() -> PlanExercise? {
        guard let d = day, d.exercises.indices.contains(exIndex) else { return nil }
        return d.exercises[exIndex]
    }
    
    private func currentSetInfo() -> (name: String, setNow: Int, setAll: Int, workloadText: String)? {
        guard let ex = currentExercise() else { return nil }
        let all = totalSets(for: ex)
        let now = min(setIndex + 1, max(1, all))
        let work = ex.reps.isEmpty ? ex.duration : ex.reps
        return (ex.name, now, all, work.isEmpty ? "—" : work)
    }
    
    private func nextSetInfo() -> (name: String, setNow: Int, setAll: Int, workloadText: String)? {
        guard let d = day else { return nil }
        
        var nextExIndex = exIndex
        var nextSetIndex = setIndex
        
        if let ex = currentExercise() {
            let total = totalSets(for: ex)
            if nextSetIndex + 1 < total {
                nextSetIndex += 1
            } else {
                nextSetIndex = 0
                nextExIndex += 1
            }
        }
        
        guard d.exercises.indices.contains(nextExIndex) else { return nil }
        
        let nextEx = d.exercises[nextExIndex]
        let all = totalSets(for: nextEx)
        let now = min(nextSetIndex + 1, max(1, all))
        let work = nextEx.reps.isEmpty ? nextEx.duration : nextEx.reps
        
        return (nextEx.name, now, all, work.isEmpty ? "—" : work)
    }
    
    private func standbyNotesForCurrent() -> [String]? {
        guard let ex = currentExercise() else { return nil }
        let raw = ex.notes.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else { return nil }

        let separators = CharacterSet(charactersIn: "\n・;|")
        let parts = raw.components(separatedBy: separators)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return parts.isEmpty ? [raw] : parts
    }

    private func timeText(_ sec: Int) -> String {
        let m = max(0, sec) / 60
        let s = max(0, sec) % 60
        return String(format: "%02d:%02d", m, s)
    }
    
    private func isTimerBased() -> Bool {
        guard let ex = currentExercise() else { return false }
        return !ex.duration.isEmpty
    }
    
    private func workoutDuration(for ex: PlanExercise) -> Int {
        guard let seconds = digits(in: ex.duration) else { return 30 }
        return max(1, seconds)
    }
    
    private func targetReps() -> Int? {
        guard let ex = currentExercise() else { return nil }
        return digits(in: ex.reps)
    }
    
    private func inferEquipment(from ex: PlanExercise) -> Pace.Equipment {
        let n = ex.name.lowercased()
        if n.contains("ダンベル") { return .dumbbell }
        if n.contains("バーベル") { return .barbell }
        if n.contains("ケトルベル") { return .kettlebell }
        if n.contains("マシン") || n.contains("ケーブル") { return .machine }
        if ex.weight.contains("自重") || ex.weight.isEmpty { return .bodyweight }
        return .other
    }

    private func estimatedSecondsForCurrentRepSet() -> Int? {
        guard let ex = currentExercise(), let reps = targetReps() else { return nil }
        let equipment = inferEquipment(from: ex)
        
        // ✅ リファクタリング版の PaceProvider を使用
        let profile = paceProvider.pace(
            for: ex.name,
            difficulty: Pace.Difficulty.normal,
            equipment: equipment,
            tempo: (nil as Pace.Tempo?)
        )
        return Int((Double(reps) * profile.secondsPerRep).rounded())
    }
    
    private func suggestedRestForCurrent() -> Int? {
        return 30
    }
    
    private func totalSets(for ex: PlanExercise) -> Int {
        return digits(in: ex.sets) ?? 1
    }
    
    private func digits(in s: String) -> Int? {
        let only = s.replacingOccurrences(of: "[^0-9]", with: "", options: .regularExpression)
        return only.isEmpty ? nil : Int(only)
    }
    
    private var overlayPercent: Int {
        guard let d = day, !d.exercises.isEmpty else { return 0 }
        let totalSetsAll = d.exercises.map { totalSets(for: $0) }.reduce(0, +)
        let doneSetsBefore = d.exercises.prefix(exIndex).map { totalSets(for: $0) }.reduce(0, +)
        let currentDone = min(setIndex, max(0, totalSets(for: currentExercise() ?? PlanExercise(name: "", sets: "0", reps: "", weight: "", duration: "", notes: ""))))
        let progress = Double(doneSetsBefore + currentDone)
        let total = Double(max(1, totalSetsAll))
        return max(0, min(100, Int((progress / total) * 100)))
    }
    
    private var overlayRemaining: Int {
        guard let d = day else { return 0 }
        return max(0, d.exercises.count - exIndex)
    }
    
    private func restartCurrentExercise() {
        exIndex = 0
        setIndex = 0
        mode = .workoutInProgress
        isRunning = false
        totalElapsedTime = 0
        completedExerciseIndices = []
        currentSetStartTime = isTimerBased() ? nil : Date()
        
        if isTimerBased() {
            remaining = workoutDuration(for: currentExercise() ?? PlanExercise(name: "", sets: "0", reps: "", weight: "", duration: "", notes: ""))
        }
    }

    /// 現在のセットをログに追加する。
    /// 現在のエクササイズとセット番号から重量と回数を推定し、setLogs に記録する。
    private func recordCurrentSetLog() {
        guard let ex = currentExercise() else { return }
        // exerciseIndex は現在のエクササイズのインデックス
        let exerciseIdx = exIndex
        // setIndex は 1 から始まる番号
        let setNumber = setIndex + 1
        // weightKg を PlanExercise.weight から抽出（小数点も許可）
        var weightValue: Double = 0
        let weightString = ex.weight
        // 例: "2.5kg" → "2.5" / "60kg" → "60"
        let weightSanitized = weightString.replacingOccurrences(of: "[^0-9.]", with: "", options: .regularExpression)
        if let w = Double(weightSanitized) {
            weightValue = w
        }
        // reps は PlanExercise.reps から数字を抽出
        // 例: "8-10回" / "8〜10回" → 8 (範囲指定の下限を採用)
        let repsText = ex.reps
        let rangeSeparators = CharacterSet(charactersIn: "-〜~")
        let parts = repsText.components(separatedBy: rangeSeparators)
        let repsValue: Int
        if parts.count >= 2 {
            // 範囲指定がある場合は、先頭の部分から数字だけを取り出す
            repsValue = digits(in: parts[0]) ?? 0
        } else {
            // 単一の数値の場合は従来通り
            repsValue = digits(in: repsText) ?? 0
        }
        let log = SetLog(exerciseIndex: exerciseIdx, setIndex: setNumber, weightKg: weightValue, reps: repsValue)
        setLogs.append(log)
    }
    
    @ViewBuilder
    private func noteItem(_ tip: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Image(systemName: "exclamationmark.circle")
                .font(.footnote)
                .foregroundStyle(.secondary)
            Text(tip)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .lineLimit(nil)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: - Preview

#Preview {
    @Previewable @State var path = NavigationPath()
    
    NavigationStack(path: $path) {
        WorkoutTimerView(
            day: DaySchedule(day: "月曜日", exercises: [
                PlanExercise(name: "ダイナミックストレッチ", sets: "1セット", reps: "", weight: "自重", duration: "30秒", notes: "背筋を伸ばす・肩は下げる・反動を使わない;呼吸は止めない"),
                PlanExercise(name: "ベンチプレス", sets: "3セット", reps: "8回", weight: "60kg", duration: "", notes: "肩甲骨を寄せる・足は床に固定"),
                PlanExercise(name: "ダンベルフライ", sets: "2セット", reps: "12回", weight: "10kg", duration: "", notes: "")
            ]),
            navigationPath: $path
        )
        .preferredColorScheme(.dark)
    }
}
