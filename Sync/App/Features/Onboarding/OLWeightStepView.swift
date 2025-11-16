import SwiftUI
import UIKit

struct OLWeightStepView: View, OnboardingValidatable {
    @Binding var weightKg: Double?
    var gate: FlowGate
    var onContinue: () -> Void = {}
    var profileRepo: SyncingProfileRepository? = nil

    @AppStorage("ol_unit_weight") private var unitRaw: String = WeightUnit.kg.rawValue
    @AppStorage("ol_onboarding_name") private var storedName: String = ""
    @AppStorage("ol_height_cm") private var storedHeightCm: Double = 0
    @AppStorage("ol_goal_weight_kg") private var storedGoalWeightKg: Double = 0
    @AppStorage("ol_weight_kg") private var storedWeightKg: Double = 0

    @State private var valueKg: Double = 65.0
    @State private var isDragging: Bool = false
    @State private var commitFeedback = UINotificationFeedbackGenerator()

    private let minKg: Double = 30.0
    private let maxKg: Double = 200.0

    private var unit: WeightUnit { WeightUnit(rawValue: unitRaw) ?? WeightUnit.kg }

    private var displayName: String {
        let base = storedName.trimmingCharacters(in: .whitespacesAndNewlines)
        return base.isEmpty ? "あなたさん" : base + "さん"
    }

    var isStepValid: Bool { valueKg >= minKg && valueKg <= maxKg }

    var body: some View {
        ZStack(alignment: .topLeading) {
            Palette.bg.ignoresSafeArea()

            VStack(spacing: 24) {
                VStack(spacing: 4) {
                    Text("\(displayName)の")
                    HStack(alignment: .firstTextBaseline, spacing: 0) {
                        Text("現在")
                            .font(.system(size: 37, weight: .heavy, design: .rounded))
                            .foregroundStyle(Palette.accent)
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
                .tint(Palette.accent)
                .padding(.horizontal, 24)
                .padding(.vertical, 2)

                GeometryReader { geo in
                    ZStack {
                        VStack(spacing: 6) {
                            HStack(alignment: .firstTextBaseline, spacing: 8) {
                                Text(displayValueText())
                                    .font(.system(size: 64, weight: .black, design: .rounded))
                                    .monospacedDigit()
                                    .foregroundStyle(.primary)
                                    .minimumScaleFactor(0.7)
                                Text(unit == WeightUnit.kg ? "kg" : "lbs")
                                    .font(.system(size: 28, weight: .semibold, design: .rounded))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.horizontal, 24)
                        .frame(maxHeight: .infinity, alignment: .center)
                        .offset(y: -28)

                        HorizontalRuler(valueKg: $valueKg,
                                        isDragging: $isDragging,
                                        minKg: minKg, maxKg: maxKg,
                                        unit: unit)
                        .frame(height: 140)
                        .padding(.horizontal, 12)
                        .frame(maxHeight: .infinity, alignment: .center)
                    }
                }
                .frame(height: 220)

                VStack(spacing: 12) {
                    BMISummaryCard(
                        kind: .current,
                        context: BMIContext(
                            heightCm: (storedHeightCm > 0) ? storedHeightCm : nil,
                            weightKg: valueKg,
                            goalWeightKg: (storedGoalWeightKg > 0) ? storedGoalWeightKg : nil
                        )
                    )
                }
                .padding(.horizontal, 24)

                Spacer()
            }
        }
        .onAppear {
            if let w = weightKg, w >= minKg, w <= maxKg {
                valueKg = w
            } else if storedWeightKg > 0, storedWeightKg >= minKg, storedWeightKg <= maxKg {
                valueKg = storedWeightKg
            } else {
                valueKg = 65
            }
            
            commitFeedback.prepare()

            if let repo = profileRepo {
                Task {
                    if let p = try? await repo.getProfile() {
                        if let w = p.weightKg, w >= minKg, w <= maxKg {
                            valueKg = w
                        }
                        if let h = p.heightCm, h > 0 {
                            storedHeightCm = h
                        }
                    }
                }
            }
        }
        .onChange(of: valueKg) { _, newValue in
            let rounded = (newValue * 10).rounded() / 10
            weightKg = rounded
            storedWeightKg = rounded
            
            NotificationCenter.default.post(
                name: Notification.Name("profileWeightDidChange"),
                object: nil,
                userInfo: ["weightKg": rounded]
            )
        }
        .onChange(of: isDragging) { _, dragging in
            guard dragging == false else { return }
            let rounded = (valueKg * 10).rounded() / 10
            
            NotificationCenter.default.post(
                name: Notification.Name("profileWeightDidChange"),
                object: nil,
                userInfo: ["weightKg": rounded]
            )
        }
        .safeAreaInset(edge: .bottom) {
            StartPrimaryButton(title: "次へ") {
                commitFeedback.notificationOccurred(.success)
                commit()
            }
            .disabled(!isStepValid || gate.isNavigating)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
    }
}

extension OLWeightStepView {
    fileprivate func commit() {
        let rounded = (valueKg * 10).rounded() / 10
        weightKg = rounded
        storedWeightKg = rounded

        if let repo = profileRepo {
            Task {
                do {
                    // 保存を確実に完了させる
                    try await repo.updateWeightKg(rounded)
                    print("✅ Weight saved to repository: \(rounded)kg")
                } catch {
                    print("❌ Failed to save weight: \(error)")
                }
                
                // 保存完了後に遷移
                await MainActor.run { onContinue() }
            }
        } else {
            onContinue()
        }
    }

    fileprivate func displayValueText() -> String {
        switch unit {
        case .kg:
            return String(format: "%.1f", valueKg)
        case .lbs:
            return String(format: "%.1f", valueKg * 2.20462262)
        }
    }
}

// MARK: - Horizontal ruler
private struct HorizontalRuler: View {
    @Binding var valueKg: Double
    @Binding var isDragging: Bool
    let minKg: Double
    let maxKg: Double
    let unit: WeightUnit
    
    private let scrollSensitivity: CGFloat = 1.00
    
    @State private var lastHapticStep: Int? = nil
    @State private var selectionFeedback = UISelectionFeedbackGenerator()
    @State private var majorImpact = UIImpactFeedbackGenerator(style: .rigid)
    @State private var lastHapticHalfStep: Int? = nil
    @State private var midImpact = UIImpactFeedbackGenerator(style: .light)
    
    private let pxPerUnit: CGFloat = 60
    
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
                    
                    let valueInUnit: Double = {
                        switch unit {
                        case .kg:  return valueKg
                        case .lbs: return valueKg * 2.20462262
                        }
                    }()
                    
                    let startDeci = Int(floor((valueInUnit - Double(totalUnitsVisible / 2) - 2) * 10))
                    let endDeci   = Int(ceil((valueInUnit + Double(totalUnitsVisible / 2) + 2) * 10))
                    
                    for d in stride(from: startDeci, through: endDeci, by: 1) {
                        let u = Double(d) / 10.0
                        let kgOfU: Double = (unit == WeightUnit.kg) ? u : (u / 2.20462262)
                        if kgOfU < minKg || kgOfU > maxKg { continue }
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
                
                Rectangle()
                    .fill(Palette.accent)
                    .frame(width: 2, height: 56)
                    .position(x: geo.size.width / 2, y: geo.size.height / 2 + 28)
                    .allowsHitTesting(false)
            }
            .contentShape(Rectangle())
            .transaction { tx in
                if isDragging { tx.disablesAnimations = true }
            }
            .overlay(
                InertiaScroller(
                    valueKg: $valueKg,
                    isDragging: $isDragging,
                    minKg: minKg,
                    maxKg: maxKg,
                    unit: unit,
                    pxPerUnit: pxPerUnit,
                    viewWidth: geo.size.width
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
                    Task { @MainActor in
                        lastHapticStep = newStep
                    }
                }
            }
            .onChange(of: currentHalfStepForHaptics) { _, newHalf in
                guard isDragging else { return }
                if lastHapticHalfStep != newHalf, newHalf % 2 == 1 {
                    midImpact.impactOccurred()
                    midImpact.prepare()
                    selectionFeedback.selectionChanged()
                    selectionFeedback.prepare()
                    Task { @MainActor in
                        lastHapticHalfStep = newHalf
                    }
                }
            }
            .onChange(of: isDragging) { _, dragging in
                if dragging {
                    selectionFeedback.prepare()
                    majorImpact.prepare()
                    midImpact.prepare()
                    Task { @MainActor in
                        lastHapticHalfStep = currentHalfStepForHaptics
                        lastHapticStep = currentStepForHaptics
                    }
                }
            }
        }
    }
}

// MARK: - UIKit-backed inertial scroller
private struct InertiaScroller: UIViewRepresentable {
    @Binding var valueKg: Double
    @Binding var isDragging: Bool
    let minKg: Double
    let maxKg: Double
    let unit: WeightUnit
    let pxPerUnit: CGFloat
    let viewWidth: CGFloat

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
        var parent: InertiaScroller
        weak var contentView: UIView?
        private var isProgrammatic = false
        private var lastSyncedKg: Double? = nil

        init(parent: InertiaScroller) { self.parent = parent }

        private var unitsPerKg: Double { parent.unit == WeightUnit.kg ? 1.0 : 2.20462262 }
        private var minUnit: Double { parent.minKg * unitsPerKg }
        private var maxUnit: Double { parent.maxKg * unitsPerKg }
        private var totalUnits: Double { maxUnit - minUnit }

        func rebuildMetrics(scrollView: UIScrollView) {
            let contentWidth = CGFloat(totalUnits) * parent.pxPerUnit + parent.viewWidth
            contentView?.frame = CGRect(x: 0, y: 0, width: max(contentWidth, 1), height: scrollView.bounds.height)
            scrollView.contentSize = CGSize(width: max(contentWidth, 1), height: scrollView.bounds.height)
            let inset = parent.viewWidth / 2.0
            scrollView.contentInset = UIEdgeInsets(top: 0, left: inset, bottom: 0, right: inset)
        }

        func syncOffsetFromValue(scrollView: UIScrollView, animated: Bool) {
            let valueInUnit = parent.unit == WeightUnit.kg ? parent.valueKg : parent.valueKg * unitsPerKg
            let clamped = max(minUnit, min(maxUnit, valueInUnit))
            let x = CGFloat(clamped - minUnit) * parent.pxPerUnit
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
            }
        }
    }
}

#Preview("OLWeightStepView") {
    struct StatefulPreviewWrapper<Value, Content: View>: View {
        @State var value: Value
        var content: (Binding<Value>) -> Content
        
        init(_ initialValue: Value, @ViewBuilder content: @escaping (Binding<Value>) -> Content) {
            self._value = State(initialValue: initialValue)
            self.content = content
        }
        
        var body: some View {
            content($value)
        }
    }
    
    return StatefulPreviewWrapper(nil as Double?) { binding in
        OLWeightStepView(weightKg: binding, gate: FlowGate())
    }
}
