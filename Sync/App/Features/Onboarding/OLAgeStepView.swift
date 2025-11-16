import SwiftUI
import UIKit

struct OLAgeStepView: View, OnboardingValidatable {
    @Binding var age: Int?
    var gate: FlowGate
    var onContinue: () -> Void = {}
    var profileRepo: SyncingProfileRepository? = nil

    @AppStorage("ol_onboarding_name") private var storedName: String = ""

    @State private var ageText: String = ""
    @FocusState private var isFocused: Bool
    @State private var showError: Bool = false
    @State private var commitFeedback = UINotificationFeedbackGenerator()

    private let allowedRange: ClosedRange<Int> = 13...99

    private var displayName: String {
        let base = storedName.trimmingCharacters(in: .whitespacesAndNewlines)
        return base.isEmpty ? "あなたさん" : base + "さん"
    }
    
    private var parsedAge: Int? { Int(ageText) }
    
    // OnboardingValidatable準拠
    var isStepValid: Bool {
        if let a = parsedAge { return allowedRange.contains(a) } else { return false }
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            Palette.bg.ignoresSafeArea()

            VStack(spacing: 28) {
                VStack(spacing: 4) {
                    Text(displayName)
                        .font(.system(size: 34, weight: .heavy, design: .rounded))
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("年齢を教えて！")
                        .font(.system(size: 34, weight: .heavy, design: .rounded))
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 24)
                .padding(.top, 8)
                .frame(maxWidth: .infinity, alignment: .center)

                VStack(spacing: 10) {
                    TextField("", text: $ageText)
                        .font(.system(size: 45, weight: .semibold, design: .rounded))
                        .foregroundStyle(.primary)
                        .tint(Palette.accent)
                        .multilineTextAlignment(.center)
                        .keyboardType(.numberPad)
                        .focused($isFocused)
                        .submitLabel(.done)
                        .onSubmit { if isStepValid { commit() } else { showError = true } }
                        .onChange(of: ageText) { _, newValue in
                            var filtered = newValue.filter(\.isNumber)
                            if filtered.count > 2 { filtered = String(filtered.prefix(2)) }
                            if filtered != ageText { ageText = filtered }
                            showError = false
                            age = Int(filtered)
                            if let repo = profileRepo, let a = Int(filtered), allowedRange.contains(a) {
                                Task { try? await repo.updateAge(a) }
                            }
                        }

                    Rectangle()
                        .fill(Color.secondary.opacity(0.20))
                        .frame(height: 1)
                        .overlay(alignment: .leading) {
                            GeometryReader { geo in
                                Rectangle()
                                    .fill((showError && !isStepValid) ? Palette.error : .clear)
                                    .frame(width: underlineWidth(in: geo.size.width), height: 2)
                                    .offset(y: -0.5)
                            }
                        }
                        .frame(height: 2)

                    Group {
                        if showError && !isStepValid {
                            Text("13〜99の範囲の数字のみ入力できます")
                                .foregroundStyle(Palette.error)
                        }
                    }
                    .font(.footnote)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 6)
                }
                .padding(.horizontal, 36)
                .padding(.top, 10)

                Spacer()
            }
        }
        .task {
            isFocused = false
            if let a = age, a > 0 { ageText = String(a) }
            commitFeedback.prepare()
            if let repo = profileRepo {
                Task {
                    if let p = try? await repo.getProfile(),
                       let a = p.age,
                       allowedRange.contains(a),
                       ageText.isEmpty {
                        await MainActor.run { ageText = String(a) }
                    }
                }
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

    private func underlineWidth(in total: CGFloat) -> CGFloat {
        let minW = total * 0.08
        let maxW = total
        let ratio = min(1.0, Double((parsedAge ?? 0)) / 99.0)
        return minW + CGFloat(ratio) * (maxW - minW)
    }

    private func commit() {
        guard isStepValid, !gate.isNavigating else { return }
        if let a = parsedAge, isStepValid {
            age = a
            if let repo = profileRepo { Task { try? await repo.updateAge(a) } }
            onContinue()
        }
    }
}

// MARK: - Preview Helper

private struct StatefulPreviewWrapper<Value, Content: View>: View {
    @State private var value: Value
    private let content: (Binding<Value>) -> Content
    init(_ value: Value, @ViewBuilder content: @escaping (Binding<Value>) -> Content) {
        _value = State(initialValue: value)
        self.content = content
    }
    var body: some View { content($value) }
}

#Preview("OLAgeStepView") {
    StatefulPreviewWrapper(nil as Int?) { $age in
        OLAgeStepView(age: $age, gate: FlowGate())
    }
}
