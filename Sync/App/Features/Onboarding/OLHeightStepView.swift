import SwiftUI
import UIKit

struct OLHeightStepView: View, OnboardingValidatable {
    @Binding var heightCm: Double?
    var gate: FlowGate
    var onContinue: () -> Void = {}
    var profileRepo: SyncingProfileRepository? = nil
    
    @AppStorage("ol_unit_height") private var unitRaw: String = HeightUnit.cm.rawValue
    @AppStorage("ol_onboarding_name") private var storedName: String = ""
    
    @State private var valueCm: Double = 170
    @State private var isDragging: Bool = false
    @State private var commitFeedback = UINotificationFeedbackGenerator()
    
    private let rangeMin: Double = 120
    private let rangeMax: Double = 220
    
    private var unit: HeightUnit { HeightUnit(rawValue: unitRaw) ?? .cm }
    
    private var displayName: String {
        let base = storedName.trimmingCharacters(in: .whitespacesAndNewlines)
        return base.isEmpty ? "あなた" : base + "さん"
    }
    
    // OnboardingValidatable準拠
    var isStepValid: Bool { valueCm >= rangeMin && valueCm <= rangeMax }
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            Palette.bg.ignoresSafeArea()
            
            VStack(spacing: 24) {
                Text("\(displayName)の身長は？")
                    .font(.system(size: 34, weight: .heavy, design: .rounded))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)
                    .lineLimit(1)
                    .minimumScaleFactor(0.4)
                    .allowsTightening(true)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 24)
                
                InfoBubble()
                    .padding(.horizontal, 24)
                
                Picker("", selection: Binding(
                    get: { unit },
                    set: { unitRaw = $0.rawValue }
                )) {
                    Text("cm").tag(HeightUnit.cm)
                    Text("ft.").tag(HeightUnit.ft)
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
                        let valueFontSize: CGFloat = 64
                        let lineGap: CGFloat = max(30, valueFontSize * 0.30)
                        let selectionY = safeSelectionYOffset(containerHeight: geo.size.height, valueFontSize: valueFontSize, lineGap: lineGap)
                        let blockShift = geo.size.height * blockShiftPct(for: valueCm)
                        
                        let paddingV: CGFloat = 10
                        let halfTextHeight: CGFloat = valueFontSize * 0.66
                        let minSelForText = -geo.size.height/2 + halfTextHeight + paddingV + lineGap
                        let maxSelForText =  geo.size.height/2 - halfTextHeight - paddingV + lineGap
                        let clampedSelForText = min(max(selectionY, minSelForText), maxSelForText)
                        
                        Rectangle()
                            .fill(Palette.accent)
                            .frame(height: 2)
                            .frame(maxWidth: .infinity)
                            .padding(.leading, 24)
                            .padding(.trailing, 4)
                            .frame(maxHeight: .infinity, alignment: .center)
                            .offset(y: selectionY + blockShift)
                        
                        HStack(alignment: .center, spacing: 16) {
                            VStack(alignment: .center, spacing: 6) {
                                HStack(alignment: .firstTextBaseline, spacing: 8) {
                                    Text(displayValueText())
                                        .font(.system(size: valueFontSize, weight: .black, design: .rounded))
                                        .monospacedDigit()
                                        .foregroundStyle(.primary)
                                        .minimumScaleFactor(0.7)
                                    Text(unit == .cm ? "cm" : unit.ftLabel)
                                        .font(.system(size: 28, weight: .semibold, design: .rounded))
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.horizontal, 24)
                            .frame(maxHeight: .infinity, alignment: .center)
                            .offset(y: clampedSelForText - lineGap)
                            .transaction { tx in
                                tx.disablesAnimations = true
                            }
                            
                            RightRuler(valueCm: $valueCm,
                                       isDragging: $isDragging,
                                       minCm: rangeMin, maxCm: rangeMax,
                                       unit: unit)
                            .frame(width: 96)
                            .padding(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 4))
                        }
                        .offset(y: blockShift)
                    }
                }
                .frame(height: 360)
                
                Spacer()
            }
        }
        .task {
            commitFeedback.prepare()
            if let repo = profileRepo {
                Task {
                    if let p = try? await repo.getProfile(), let h = p.heightCm {
                        let rounded = Double(round(min(rangeMax, max(rangeMin, h))))
                        valueCm = rounded
                        heightCm = rounded
                    } else {
                        let fallback = heightCm ?? 170
                        let rounded = Double(round(min(rangeMax, max(rangeMin, fallback))))
                        valueCm = rounded
                        heightCm = rounded
                    }
                }
            } else {
                let fallback = heightCm ?? 170
                let rounded = Double(round(min(rangeMax, max(rangeMin, fallback))))
                valueCm = rounded
                heightCm = rounded
            }
        }
        .onChange(of: valueCm) { oldValue, newValue in
            let clamped = min(rangeMax, max(rangeMin, newValue))
            let rounded = Double(round(clamped))
            heightCm = rounded
            if let repo = profileRepo {
                Task { try? await repo.updateHeightCm(rounded) }
            }
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
    
    private func commit() {
        guard isStepValid, !gate.isNavigating else { return }
        let rounded = Double(round(valueCm))
        heightCm = rounded
        if let repo = profileRepo {
            Task { try? await repo.updateHeightCm(rounded) }
        }
        onContinue()
    }
    
    private func displayValueText() -> String {
        switch unit {
        case .cm:
            return String(Int(round(valueCm)))
        case .ft:
            let totalIn = valueCm / 2.54
            let ft = Int(totalIn / 12.0)
            let inch = Int(round(totalIn.truncatingRemainder(dividingBy: 12)))
            return "\(ft)' \(inch)\""
        }
    }
    
    private func safeSelectionYOffset(containerHeight h: CGFloat,
                                      valueFontSize: CGFloat,
                                      lineGap: CGFloat) -> CGFloat {
        let halfText: CGFloat = valueFontSize * 0.66
        let padding: CGFloat = 10
        let maxByText = (h / 2) - (halfText + lineGap + padding)
        let baseAmp: CGFloat = min(120.0, h * 0.25)
        let amplitude: CGFloat = max(0, min(baseAmp, maxByText))
        let t = max(0, min(1, (valueCm - rangeMin) / (rangeMax - rangeMin)))
        let normalized = (t - 0.5) * 2.0
        return -normalized * amplitude
    }
    
    private func blockShiftPct(for value: Double) -> CGFloat {
        let minV = rangeMin, maxV = rangeMax
        guard maxV > minV else { return 0 }
        let tRaw = (value - minV) / (maxV - minV)
        let t = max(0, min(1, tRaw))
        let eased = t * t * (3 - 2 * t)
        let minPct: CGFloat = 0.12
        let maxPct: CGFloat = -0.10
        return minPct + (maxPct - minPct) * CGFloat(eased)
    }
    private func clampRound(_ v: Double) -> Double {
        let clamped = min(rangeMax, max(rangeMin, v))
        return Double(round(clamped))
    }
}
// MARK: - Right-side ruler

private struct RightRuler: View {
    @Binding var valueCm: Double
    @Binding var isDragging: Bool
    let minCm: Double
    let maxCm: Double
    let unit: HeightUnit

    @State private var lastHapticStep: Int? = nil
    @State private var selectionFeedback = UISelectionFeedbackGenerator()
    @State private var isDecelerating: Bool = false

    var body: some View {
        GeometryReader { geo in
            let valueFontSize: CGFloat = 64
            let lineGap: CGFloat = max(14, valueFontSize * 0.30)
            let halfTextHeight: CGFloat = valueFontSize * 0.66
            let paddingV: CGFloat = 10

            let center = geo.size.height / 2
            let baseAmp = min(120.0, geo.size.height * 0.25)
            let maxByText = (geo.size.height / 2) - (halfTextHeight + lineGap + paddingV)
            let amplitude = max(0, min(baseAmp, maxByText))

            let selY_min = center + amplitude
            let selY_max = center - amplitude

            let pxPerCm_at_min = selY_min / 40.0
            let pxPerCm_at_max = (geo.size.height - selY_max) / 40.0

            let t = CGFloat(max(0, min(1, (valueCm - minCm) / (maxCm - minCm))))
            let basePxPerCm = pxPerCm_at_min + (pxPerCm_at_max - pxPerCm_at_min) * t
            let spacingScale: CGFloat = 1.25
            let pxPerCm = basePxPerCm * spacingScale

            let currentStepForHaptics: Int = {
                switch unit {
                case .cm:
                    return Int(round(valueCm))
                case .ft:
                    return Int(round(valueCm / 2.54))
                }
            }()

            ZStack(alignment: .trailing) {
                Canvas { ctx, size in
                    let t = max(0, min(1, (valueCm - minCm) / (maxCm - minCm)))
                    let normalized = (t - 0.5) * 2.0
                    let selectionY = center - CGFloat(normalized) * amplitude

                    let totalCmVisible = size.height / pxPerCm
                    let start = Swift.max(Int(floor(valueCm - Double(totalCmVisible/2) - 5)), Int(minCm))
                    let end = Swift.min(Int(ceil(valueCm + Double(totalCmVisible/2) + 5)), Int(maxCm))
                    let anchorValue: Double = (isDragging || isDecelerating) ? valueCm : (unit == .cm ? round(valueCm) : valueCm)

                    for cm in stride(from: start, to: end + 1, by: 1) {
                        let dy = CGFloat(anchorValue - Double(cm)) * pxPerCm
                        let y = selectionY + dy
                        if y < -10 || y > size.height + 10 { continue }

                        let isMajor = cm % 10 == 0
                        let isMid = cm % 5 == 0
                        let tickLen: CGFloat = isMajor ? 30 : (isMid ? 20 : 10)
                        let tickThickness: CGFloat = isMajor ? 2.0 : (isMid ? 1.5 : 1.0)
                        let tickRect = CGRect(x: size.width - tickLen,
                                              y: y - tickThickness/2,
                                              width: tickLen,
                                              height: tickThickness)
                        let tickColor: Color = isMajor ? .secondary.opacity(0.80) : (isMid ? .secondary.opacity(0.60) : .secondary.opacity(0.35))
                        ctx.fill(Path(tickRect), with: .color(tickColor))

                        if isMajor {
                            let label: String
                            switch unit {
                            case .cm:
                                label = "\(cm)"
                            case .ft:
                                let totalIn = Double(cm) / 2.54
                                let ft = Int(totalIn / 12.0)
                                let inch = Int(round(totalIn - Double(ft) * 12))
                                label = "\(ft)'\(inch)"
                            }
                            let text = Text(label)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(.secondary)
                            ctx.draw(text, at: CGPoint(x: size.width - tickLen - 22, y: y))
                        }
                    }
                }
            }
            .mask(
                LinearGradient(
                    gradient: Gradient(stops: [
                        .init(color: .clear, location: 0.0),
                        .init(color: .black, location: 0.18),
                        .init(color: .black, location: 0.82),
                        .init(color: .clear, location: 1.0)
                    ]),
                    startPoint: .top, endPoint: .bottom
                )
            )
            .clipped()
            .contentShape(Rectangle())
            .transaction { tx in
                if isDragging { tx.disablesAnimations = true }
            }
            .overlay(
                RulerScrollView(
                    value: $valueCm,
                    minValue: minCm,
                    maxValue: maxCm,
                    pxPerUnit: pxPerCm,
                    viewHeight: geo.size.height,
                    isDragging: $isDragging,
                    isDecelerating: $isDecelerating,
                    snapToInteger: unit == .cm
                )
                .allowsHitTesting(true)
            )
            .onAppear {
                lastHapticStep = currentStepForHaptics
                selectionFeedback.prepare()
            }
            .onChange(of: currentStepForHaptics) { _, newStep in
                guard isDragging || isDecelerating else { return }
                if lastHapticStep != newStep {
                    selectionFeedback.selectionChanged()
                    selectionFeedback.prepare()
                    lastHapticStep = newStep
                }
            }
            .onChange(of: isDragging) { _, dragging in
                if dragging {
                    selectionFeedback.prepare()
                    lastHapticStep = currentStepForHaptics
                }
            }
        }
    }
}

// MARK: - Native inertial scroll bridge for the ruler

private struct RulerScrollView: UIViewRepresentable {
    @Binding var value: Double
    let minValue: Double
    let maxValue: Double
    let pxPerUnit: CGFloat
    let viewHeight: CGFloat
    @Binding var isDragging: Bool
    @Binding var isDecelerating: Bool
    let snapToInteger: Bool

    func makeUIView(context: Context) -> UIScrollView {
        let scroll = UIScrollView()
        scroll.showsVerticalScrollIndicator = false
        scroll.showsHorizontalScrollIndicator = false
        scroll.decelerationRate = .normal
        scroll.bounces = true
        scroll.alwaysBounceVertical = true
        scroll.delegate = context.coordinator

        let content = UIView()
        content.backgroundColor = .clear
        scroll.addSubview(content)
        context.coordinator.contentView = content

        return scroll
    }

    func updateUIView(_ scroll: UIScrollView, context: Context) {
        context.coordinator.parent = self
        let contentHeight = CGFloat(maxValue - minValue) * pxPerUnit + viewHeight
        if context.coordinator.contentView?.frame.height != contentHeight {
            context.coordinator.contentView?.frame = CGRect(x: 0, y: 0, width: 1, height: contentHeight)
            scroll.contentSize = CGSize(width: 1, height: contentHeight)
            scroll.contentInset = UIEdgeInsets(top: viewHeight/2, left: 0, bottom: viewHeight/2, right: 0)
        }

        if !scroll.isDragging && !scroll.isDecelerating && !context.coordinator.isSettingOffset {
            let targetY = yOffset(for: value)
            if abs(scroll.contentOffset.y - targetY) > 0.5 {
                context.coordinator.isSettingOffset = true
                scroll.setContentOffset(CGPoint(x: 0, y: targetY), animated: false)
                context.coordinator.isSettingOffset = false
            }
        }
    }

    private func yOffset(for value: Double) -> CGFloat {
        return CGFloat(maxValue - value) * pxPerUnit
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UIScrollViewDelegate {
        var parent: RulerScrollView
        weak var contentView: UIView?
        var isSettingOffset: Bool = false

        init(_ parent: RulerScrollView) { self.parent = parent }

        func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
            parent.isDragging = true
            parent.isDecelerating = false
        }

        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            guard !isSettingOffset else { return }
            let y = max(0, min(scrollView.contentOffset.y, scrollView.contentSize.height))
            var v = parent.maxValue - Double(y / parent.pxPerUnit)
            v = min(parent.maxValue, max(parent.minValue, v))
            parent.value = v
        }

        func scrollViewWillEndDragging(_ scrollView: UIScrollView, withVelocity velocity: CGPoint, targetContentOffset: UnsafeMutablePointer<CGPoint>) {
            if parent.snapToInteger {
                let targetY = targetContentOffset.pointee.y
                let targetValue = parent.maxValue - Double(targetY / parent.pxPerUnit)
                let snapped = round(targetValue)
                targetContentOffset.pointee.y = CGFloat(parent.maxValue - snapped) * parent.pxPerUnit
            }
        }

        func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
            parent.isDragging = false
            parent.isDecelerating = decelerate
            if !decelerate, parent.snapToInteger {
                let snapped = round(parent.value)
                isSettingOffset = true
                scrollView.setContentOffset(CGPoint(x: 0, y: CGFloat(parent.maxValue - snapped) * parent.pxPerUnit), animated: true)
                isSettingOffset = false
                parent.value = snapped
            }
        }

        func scrollViewWillBeginDecelerating(_ scrollView: UIScrollView) {
            parent.isDecelerating = true
        }

        func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
            parent.isDecelerating = false
            if parent.snapToInteger {
                let snapped = round(parent.value)
                isSettingOffset = true
                scrollView.setContentOffset(CGPoint(x: 0, y: CGFloat(parent.maxValue - snapped) * parent.pxPerUnit), animated: true)
                isSettingOffset = false
                parent.value = snapped
            }
        }
    }
}

// MARK: - Unit toggle

private enum HeightUnit: String {
    case cm, ft
    var ftLabel: String { "ft" }
}

// MARK: - Info bubble

private struct InfoBubble: View {
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "brain.head.profile")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(Palette.accent)
                .frame(width: 28, height: 28)
                .padding(.top, 2)
            Text("正確身長でBMIを計算し、あなたの体型に最適なトレーニングを調整します！")
                .foregroundStyle(.primary)
                .font(.system(size: 16, weight: .regular))
                .lineSpacing(2)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Palette.card)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
        )
    }
}

// MARK: - Preview

#Preview("OLHeightStepView") {
    struct PreviewWrapper: View {
        @State var height: Double? = nil
        var body: some View {
            OLHeightStepView(heightCm: $height, gate: FlowGate())
        }
    }
    return PreviewWrapper()
}
