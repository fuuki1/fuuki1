import SwiftUI
import UIKit

// MARK: - UIKit-backed inertial scroller for Goal Ruler (OS standard physics)
private struct GoalInertiaScroller: UIViewRepresentable {
    @Binding var valueKg: Double
    @Binding var isDragging: Bool
    @Binding var hitEdge: Bool
    let minKg: Double
    let maxKg: Double
    let unit: WeightUnit
    let pxPerUnit: CGFloat

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    func makeUIView(context: Context) -> UIScrollView {
        let sv = UIScrollView()
        sv.showsHorizontalScrollIndicator = false
        sv.showsVerticalScrollIndicator = false
        sv.alwaysBounceHorizontal = true
        sv.alwaysBounceVertical = false
        sv.bounces = true
        sv.decelerationRate = .normal
        sv.delegate = context.coordinator

        let content = UIView()
        content.backgroundColor = .clear
        sv.addSubview(content)
        context.coordinator.contentView = content

        context.coordinator.rebuildMetrics(scrollView: sv)
        context.coordinator.syncOffsetFromValue(scrollView: sv, animated: false)
        return sv
    }

    func updateUIView(_ sv: UIScrollView, context: Context) {
        context.coordinator.parent = self
        context.coordinator.updateIfNeeded(scrollView: sv, animated: !isDragging)
    }

    class Coordinator: NSObject, UIScrollViewDelegate {
        var parent: GoalInertiaScroller
        weak var contentView: UIView?
        private var isProgrammatic = false
        private var lastSyncedKg: Double? = nil

        init(parent: GoalInertiaScroller) { self.parent = parent }

        private var unitsPerKg: Double { parent.unit == WeightUnit.kg ? 1.0 : 2.20462262 }
        private var minUnit: Double { parent.minKg * unitsPerKg }
        private var maxUnit: Double { parent.maxKg * unitsPerKg }
        private var totalUnits: Double { maxUnit - minUnit }
        private var viewWidth: CGFloat = 0

        func rebuildMetrics(scrollView: UIScrollView) {
            viewWidth = scrollView.bounds.width
            let contentWidth = CGFloat(totalUnits) * parent.pxPerUnit + viewWidth
            contentView?.frame = CGRect(x: 0, y: 0, width: max(contentWidth, 1), height: scrollView.bounds.height)
            scrollView.contentSize = CGSize(width: max(contentWidth, 1), height: scrollView.bounds.height)
            let inset = viewWidth / 2.0
            scrollView.contentInset = UIEdgeInsets(top: 0, left: inset, bottom: 0, right: inset)
        }

        func syncOffsetFromValue(scrollView: UIScrollView, animated: Bool) {
            let valueInUnit = parent.unit == WeightUnit.kg ? parent.valueKg : parent.valueKg * unitsPerKg
            let clampedUnit = max(minUnit, min(maxUnit, valueInUnit))
            let x = CGFloat(clampedUnit - minUnit) * parent.pxPerUnit
            let clampedX = min(max(x, 0), scrollView.contentSize.width)
            if abs(scrollView.contentOffset.x - clampedX) > 0.5 || animated {
                isProgrammatic = true
                scrollView.setContentOffset(CGPoint(x: clampedX, y: 0), animated: animated)
                DispatchQueue.main.async { self.isProgrammatic = false }
            }
        }

        func updateIfNeeded(scrollView: UIScrollView, animated: Bool) {
            rebuildMetrics(scrollView: scrollView)
            let currentKg = parent.valueKg
            if scrollView.isTracking || scrollView.isDecelerating { return }
            if let last = lastSyncedKg, abs(last - currentKg) < 0.001, !animated { return }
            lastSyncedKg = currentKg
            syncOffsetFromValue(scrollView: scrollView, animated: animated)
        }

        func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
            DispatchQueue.main.async { self.parent.isDragging = true }
        }

        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            if isProgrammatic { return }
            guard scrollView.isTracking || scrollView.isDecelerating else { return }

            let x = max(0, min(scrollView.contentOffset.x, scrollView.contentSize.width))
            let valueInUnit = minUnit + Double(x / parent.pxPerUnit)
            let kg = parent.unit == WeightUnit.kg ? valueInUnit : valueInUnit / unitsPerKg
            let clampedKg = max(parent.minKg, min(parent.maxKg, kg))

            if abs(parent.valueKg - clampedKg) < 0.001 { return }

            DispatchQueue.main.async {
                self.parent.valueKg = clampedKg
                let atEdge = (abs(clampedKg - self.parent.minKg) < 0.0001) || (abs(clampedKg - self.parent.maxKg) < 0.0001)
                if atEdge != self.parent.hitEdge { self.parent.hitEdge = atEdge }
            }
        }

        func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
            DispatchQueue.main.async { self.parent.isDragging = decelerate }
            if !decelerate { snap(scrollView) }
        }

        func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
            DispatchQueue.main.async { self.parent.isDragging = false }
            snap(scrollView)
        }

        func scrollViewWillEndDragging(_ scrollView: UIScrollView, withVelocity velocity: CGPoint, targetContentOffset: UnsafeMutablePointer<CGPoint>) {
            let targetX = targetContentOffset.pointee.x
            let targetValueInUnit = minUnit + Double(targetX / parent.pxPerUnit)
            let targetKg = (parent.unit == WeightUnit.kg) ? targetValueInUnit : targetValueInUnit / unitsPerKg
            let snappedKg = (targetKg * 10).rounded() / 10
            let snappedUnit = (parent.unit == WeightUnit.kg) ? snappedKg : snappedKg * unitsPerKg
            let snappedX = CGFloat(snappedUnit - minUnit) * parent.pxPerUnit
            let clampedX = min(max(snappedX, 0), scrollView.contentSize.width)
            targetContentOffset.pointee.x = clampedX
        }

        private func snap(_ scrollView: UIScrollView) {
            let x = scrollView.contentOffset.x
            let valueInUnit = minUnit + Double(x / parent.pxPerUnit)
            let kg = (parent.unit == WeightUnit.kg) ? valueInUnit : valueInUnit / unitsPerKg
            let snappedKg = (kg * 10).rounded() / 10
            let snappedUnit = (parent.unit == WeightUnit.kg) ? snappedKg : snappedKg * unitsPerKg
            let snappedX = CGFloat(snappedUnit - minUnit) * parent.pxPerUnit
            let clampedX = min(max(CGFloat(snappedX), 0), scrollView.contentSize.width)
            if abs(clampedX - x) > 0.1 {
                isProgrammatic = true
                scrollView.setContentOffset(CGPoint(x: clampedX, y: 0), animated: true)
                DispatchQueue.main.async { self.isProgrammatic = false }
            }
            DispatchQueue.main.async {
                self.parent.valueKg = snappedKg
                let atEdge = (abs(snappedKg - self.parent.minKg) < 0.0001) || (abs(snappedKg - self.parent.maxKg) < 0.0001)
                if atEdge != self.parent.hitEdge { self.parent.hitEdge = atEdge }
            }
        }
    }
}

// MARK: - Goal Weight Step View

struct OLGoalWeightStepView: View, OnboardingValidatable {
    @Binding var goalWeightKg: Double?
    var currentWeightKg: Double?
    var currentHeightCm: Double?
    var gate: FlowGate
    var profileRepo: SyncingProfileRepository? = nil
    var onContinue: () -> Void = {}

    @AppStorage("ol_unit_weight") private var unitRaw: String = WeightUnit.kg.rawValue
    @AppStorage("ol_onboarding_name") private var storedName: String = ""
    @AppStorage("ol_height_cm") private var storedHeightCm: Double = 0

    @State private var repoHeight: Double? = nil
    @State private var repoWeight: Double? = nil
    @State private var valueKg: Double = 60.0
    @State private var isDragging: Bool = false
    @State private var hitEdge: Bool = false
    @State private var commitFeedback = UINotificationFeedbackGenerator()

    private var hardMinKg: Double { 30.0 }
    private var hardMaxKg: Double { 200.0 }
    
    private var minKg: Double {
        guard let base = repoWeight, base > 0 else { return hardMinKg }
        return max(hardMinKg, base - 20.0)
    }
    
    private var maxKg: Double {
        guard let base = repoWeight, base > 0 else { return hardMaxKg }
        return min(hardMaxKg, base + 20.0)
    }
    
    private var unit: WeightUnit { WeightUnit(rawValue: unitRaw) ?? .kg }

    private var displayName: String {
        let base = storedName.trimmingCharacters(in: .whitespacesAndNewlines)
        return base.isEmpty ? "あなたさん" : base + "さん"
    }

    private var heightCm: Double {
        repoHeight ?? (storedHeightCm > 0 ? storedHeightCm : 0)
    }

    var isStepValid: Bool { valueKg >= minKg && valueKg <= maxKg }

    var body: some View {
        ZStack(alignment: .topLeading) {
            GoalPalette.bg.ignoresSafeArea()

            VStack(spacing: 24) {
                VStack(spacing: 4) {
                    Text("\(displayName)の")
                        .foregroundStyle(.primary)
                    HStack(alignment: .firstTextBaseline, spacing: 0) {
                        Text("目標")
                            .font(.system(size: 37, weight: .heavy, design: .rounded))
                            .foregroundStyle(GoalPalette.accent)
                        Text("の体重は?")
                            .font(.system(size: 34, weight: .heavy, design: .rounded))
                            .foregroundStyle(.primary)
                    }
                    .frame(maxWidth: .infinity)
                }
                .font(.system(size: 34, weight: .heavy, design: .rounded))
                .tracking(0.2)
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.horizontal, 24)
                
                Picker("", selection: Binding(
                    get: { unit },
                    set: { (newUnit: WeightUnit) in unitRaw = newUnit.rawValue }
                )) {
                    Text("kg").tag(WeightUnit.kg)
                    Text("lbs").tag(WeightUnit.lbs)
                }
                .pickerStyle(.segmented)
                .controlSize(.large)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .labelsHidden()
                .tint(GoalPalette.brand)
                .padding(.horizontal, 24)
                .padding(.vertical, 2)

                GeometryReader { _ in
                    ZStack {
                        VStack(spacing: 6) {
                            HStack(alignment: .firstTextBaseline, spacing: 12) {
                                if let base = repoWeight, base > 0 {
                                    HStack(spacing: 6) {
                                        Text(unit == .kg ? String(format: "%.1f", base) : String(format: "%.1f", base * 2.20462262))
                                            .font(.system(size: 28, weight: .semibold, design: .rounded))
                                            .foregroundStyle(.secondary)
                                            .monospacedDigit()
                                        Image(systemName: "chevron.right.2")
                                            .font(.system(size: 16, weight: .bold))
                                            .foregroundStyle(.secondary.opacity(0.6))
                                    }
                                }
                                
                                Text(displayValueText())
                                    .font(.system(size: 62, weight: .black, design: .rounded))
                                    .monospacedDigit()
                                    .foregroundStyle(.primary)
                                    .minimumScaleFactor(0.7)
                                
                                Text(unit == .kg ? "kg" : "lbs")
                                    .font(.system(size: 28, weight: .semibold, design: .rounded))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.horizontal, 24)
                        .frame(maxHeight: .infinity, alignment: .center)
                        .offset(y: -28)

                        GoalHorizontalRuler(
                            valueKg: $valueKg,
                            isDragging: $isDragging,
                            hitEdge: $hitEdge,
                            minKg: minKg,
                            maxKg: maxKg,
                            unit: unit,
                            baselineKg: repoWeight
                        )
                        .frame(height: 140)
                        .padding(.horizontal, 12)
                        .frame(maxHeight: .infinity, alignment: .center)
                    }
                }
                .frame(height: 160)

                BMISummaryCard(
                    kind: .goal,
                    context: BMIContext(
                        heightCm: heightCm > 0 ? heightCm : nil,
                        weightKg: repoWeight,
                        goalWeightKg: valueKg
                    ),
                    maxTextLines: 4
                )
                .padding(.horizontal, 24)

                Spacer()
            }
        }
        .onAppear {
            commitFeedback.prepare()
            
            // 🔥 CRITICAL: 親から渡された値を最優先で設定
            print("[GoalWeight] onAppear - currentWeightKg: \(String(describing: currentWeightKg))")
            print("[GoalWeight] onAppear - currentHeightCm: \(String(describing: currentHeightCm))")
            
            if let weight = currentWeightKg, weight > 0 {
                repoWeight = weight
                print("[GoalWeight] Set repoWeight from parent: \(weight)")
            }
            
            if let height = currentHeightCm, height > 0 {
                repoHeight = height
                storedHeightCm = height
                print("[GoalWeight] Set repoHeight from parent: \(height)")
            }
            
            // リポジトリから追加データを取得（非同期）
            if let repo = profileRepo {
                Task {
                    do {
                        let p = try await repo.getProfile()
                        
                        await MainActor.run {
                            // 親からの値がない場合のみリポジトリの値を使用
                            if repoHeight == nil, let h = p.heightCm {
                                repoHeight = h
                                storedHeightCm = h
                                print("[GoalWeight] Set repoHeight from repo: \(h)")
                            }
                            
                            if repoWeight == nil, let w = p.weightKg {
                                repoWeight = w
                                print("[GoalWeight] Set repoWeight from repo: \(w)")
                            }
                            
                            // 目標体重の初期値を設定
                            let currentMin = minKg
                            let currentMax = maxKg
                            
                            if let gw = p.goal?.goalWeightKg, gw >= currentMin, gw <= currentMax {
                                valueKg = gw
                                goalWeightKg = gw
                                print("[GoalWeight] Set goal from repo: \(gw)")
                            } else if let w = repoWeight, w > 0 {
                                valueKg = w
                                goalWeightKg = w
                                print("[GoalWeight] Set goal to current weight: \(w)")
                            }
                        }
                    } catch {
                        print("[GoalWeight] ERROR loading profile: \(error)")
                    }
                }
            } else {
                // リポジトリがない場合、親からの値で初期化
                if let w = repoWeight, w > 0 {
                    valueKg = w
                    goalWeightKg = w
                    print("[GoalWeight] Set goal to parent weight: \(w)")
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("profileWeightDidChange"))) { note in
            if let kg = note.userInfo?["weightKg"] as? Double {
                print("[GoalWeight] Received weight change notification: \(kg)")
                applyNewRepoWeight(kg)
            }
        }
        // MARK: - 修正 (FIXED)
        // .onChange からリポジトリ保存タスクを削除し、競合を防ぐ
        .onChange(of: valueKg) { _, newValue in
            let rounded = (newValue * 10).rounded() / 10
            goalWeightKg = rounded
            //
            // if let repo = profileRepo {
            //     Task {
            //         ...
            //         try? await repo.updateGoal(g)
            //     }
            // }
            // ↑↑↑ 保存処理を削除
        }
        .safeAreaInset(edge: .bottom) {
            StartPrimaryButton(title: "次へ") {
                commit()
            }
            .disabled(!isStepValid || gate.isNavigating)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
    }

    private func applyNewRepoWeight(_ w: Double) {
        Task { @MainActor in
            self.repoWeight = w
            let newMin = self.minKg
            let newMax = self.maxKg
            if self.valueKg < newMin { self.valueKg = newMin }
            if self.valueKg > newMax { self.valueKg = newMax }
            print("[GoalWeight] Applied new weight: \(w), range: \(newMin)~\(newMax)")
        }
    }

    // MARK: - 修正 (FIXED)
    // onContinue() を Task の内側に移動し、保存完了を待ってから遷移する
    private func commit() {
        guard isStepValid, !gate.isNavigating else { return }
        let rounded = (valueKg * 10).rounded() / 10
        goalWeightKg = rounded
        var g = GoalProfile(goalWeightKg: rounded)
        
        if let repo = profileRepo {
            Task { // <-- Task で全体を囲む
                if let existing = try? await repo.getProfile().goal {
                    g.type = existing.type
                    g.planSelection = existing.planSelection
                    g.targetDate = existing.targetDate
                }
                // 保存が完了するのを待つ (await)
                try? await repo.updateGoal(g)
                
                // 保存完了後にメインスレッドで画面遷移を実行
                await MainActor.run { onContinue() }
            }
        } else {
            // repo がない場合はそのまま遷移
            onContinue()
        }
    }

    private func displayValueText() -> String {
        switch unit {
        case .kg:  return String(format: "%.1f", valueKg)
        case .lbs: return String(format: "%.1f", valueKg * 2.20462262)
        }
    }
}

// MARK: - Ruler

private struct GoalHorizontalRuler: View {
    @Binding var valueKg: Double
    @Binding var isDragging: Bool
    @Binding var hitEdge: Bool
    let minKg: Double
    let maxKg: Double
    let unit: WeightUnit
    let baselineKg: Double?

    private let pxPerUnit: CGFloat = 60
    private let hardMinKg: Double = 30.0
    private let hardMaxKg: Double = 200.0

    @State private var lastHapticStep: Int? = nil
    @State private var selectionFeedback = UISelectionFeedbackGenerator()
    @State private var majorImpact = UIImpactFeedbackGenerator(style: .rigid)
    @State private var lastHapticHalfStep: Int? = nil
    @State private var midImpact = UIImpactFeedbackGenerator(style: .light)

    var body: some View {
        GeometryReader { geo in
            let currentStepForHaptics: Int = {
                let u: Double = (unit == WeightUnit.kg) ? valueKg : valueKg * 2.20462262
                return Int(floor(u + 1e-6))
            }()
            let currentHalfStepForHaptics: Int = {
                let u: Double = (unit == WeightUnit.kg) ? valueKg : valueKg * 2.20462262
                return Int(floor(u * 2 + 1e-6))
            }()
            
            ZStack {
                Canvas { ctx, size in
                    let centerX = size.width / 2
                    let totalUnitsVisible = size.width / pxPerUnit
                    let valueInUnit: Double = (unit == .kg) ? valueKg : (valueKg * 2.20462262)

                    if let baseKg = baselineKg {
                        let baseUnit = (unit == .kg) ? baseKg : (baseKg * 2.20462262)
                        let baseX = centerX + CGFloat(baseUnit - valueInUnit) * pxPerUnit
                        let startX = max(-10, min(centerX, baseX))
                        let endX   = min(size.width + 10, max(centerX, baseX))
                        if abs(endX - startX) >= 0.5 {
                            let bandHeight: CGFloat = 44
                            let rect = CGRect(x: startX, y: size.height - bandHeight, width: endX - startX, height: bandHeight)
                            ctx.fill(Path(rect), with: .color(GoalPalette.brand.opacity(0.22)))
                        }
                    }

                    let startDeci = Int(floor((valueInUnit - Double(totalUnitsVisible / 2) - 2) * 10))
                    let endDeci   = Int(ceil((valueInUnit + Double(totalUnitsVisible / 2) + 2) * 10))

                    for d in stride(from: startDeci, through: endDeci, by: 1) {
                        let u = Double(d) / 10.0
                        let kgOfU: Double = (unit == .kg) ? u : (u / 2.20462262)
                        if kgOfU < hardMinKg || kgOfU > hardMaxKg { continue }
                        let dx = CGFloat(u - valueInUnit) * pxPerUnit
                        let x = centerX + dx
                        if x < -10 || x > size.width + 10 { continue }

                        let isMajor = (d % 10 == 0)
                        let isMid   = !isMajor && (d % 5 == 0)
                        let tickH: CGFloat = isMajor ? 28 : (isMid ? 18 : 10)
                        let alpha: CGFloat = isMajor ? 0.85 : (isMid ? 0.60 : 0.34)

                        let rect = CGRect(x: x - 0.5, y: size.height - tickH, width: 1, height: tickH)
                        ctx.fill(Path(rect), with: .color(.secondary.opacity(alpha)))

                        if isMajor {
                            let labelText = Text("\(Int(u))")
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                .monospacedDigit()
                                .foregroundStyle(.secondary.opacity(0.8))
                            let resolved = ctx.resolve(labelText)
                            let labelY = size.height - tickH - 6
                            ctx.draw(resolved, at: CGPoint(x: x, y: labelY), anchor: .bottom)
                        }
                    }
                }
                .mask(
                    LinearGradient(
                        gradient: Gradient(stops: [
                            .init(color: .clear, location: 0.0),
                            .init(color: .black, location: 0.10),
                            .init(color: .black, location: 0.90),
                            .init(color: .clear, location: 1.0)
                        ]),
                        startPoint: .leading, endPoint: .trailing
                    )
                )

                RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                    .fill(GoalPalette.brand)
                    .frame(width: 3, height: 56)
                    .position(x: geo.size.width / 2, y: geo.size.height / 2 + 28)
                    .allowsHitTesting(false)
            }
            .contentShape(Rectangle())
            .sensoryFeedback(.impact, trigger: hitEdge)
            .transaction { tx in
                if isDragging { tx.disablesAnimations = true }
            }
            .overlay(
                GoalInertiaScroller(
                    valueKg: $valueKg,
                    isDragging: $isDragging,
                    hitEdge: $hitEdge,
                    minKg: minKg,
                    maxKg: maxKg,
                    unit: unit,
                    pxPerUnit: pxPerUnit
                )
            )
            .onAppear {
                lastHapticStep = currentStepForHaptics
                selectionFeedback.prepare()
                majorImpact.prepare()
                lastHapticHalfStep = currentHalfStepForHaptics
                midImpact.prepare()
            }
            .onChange(of: currentStepForHaptics) { _, newStep in
                guard isDragging else { return }
                if lastHapticStep != newStep {
                    majorImpact.impactOccurred(intensity: 1.0)
                    majorImpact.prepare()
                    selectionFeedback.selectionChanged()
                    selectionFeedback.prepare()
                    lastHapticStep = newStep
                }
            }
            .onChange(of: currentHalfStepForHaptics) { _, newHalf in
                guard isDragging else { return }
                if lastHapticHalfStep != newHalf, newHalf % 2 == 1 {
                    midImpact.impactOccurred()
                    midImpact.prepare()
                    selectionFeedback.selectionChanged()
                    selectionFeedback.prepare()
                    lastHapticHalfStep = newHalf
                }
            }
            .onChange(of: isDragging) { _, dragging in
                if dragging {
                    selectionFeedback.prepare()
                    majorImpact.prepare()
                    midImpact.prepare()
                    lastHapticHalfStep = currentHalfStepForHaptics
                    lastHapticStep = currentStepForHaptics
                }
            }
        }
    }
}

// MARK: - Palette

private enum GoalPalette {
    static let bg = Color(.systemBackground)
    static let brand = Color(red: 124/255, green: 77/255, blue: 255/255)
    static let accent = Color(red: 0.10, green: 0.78, blue: 0.60)
    static let button = brand
    static let disabled = Color.secondary.opacity(0.16)
    static let disabledFill = Color(.systemGray5)
    static let card = Color.primary.opacity(0.04)
}

// MARK: - Preview

#Preview("OLGoalWeightStepView") {
    struct PreviewWrapper: View {
        @State var goalWeight: Double? = 65.8
        var body: some View {
            OLGoalWeightStepView(
                goalWeightKg: $goalWeight,
                currentWeightKg: 61.0,
                currentHeightCm: 170.0,
                gate: FlowGate()
            )
        }
    }
    return PreviewWrapper()
}
