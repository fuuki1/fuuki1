import SwiftUI

/// 名前入力ステップ（OnboardingValidatable準拠・FlowGate統合）
struct OLNameStepView: View, OnboardingValidatable {
    @Binding var name: String
    var gate: FlowGate
    var onContinue: () -> Void = {}
    var profileRepo: SyncingProfileRepository? = nil

    @AppStorage("ol_onboarding_name") private var storedName: String = ""

    private let maxLength: Int = 20
    @FocusState private var isFocused: Bool
    
    private var trimmed: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }
    
    // OnboardingValidatable準拠
    var isStepValid: Bool { !trimmed.isEmpty && trimmed.count <= maxLength }

    var body: some View {
        ZStack(alignment: .topLeading) {
            Palette.bg.ignoresSafeArea()

            VStack(spacing: 28) {
                Text("あなたの名前を教えて")
                    .font(.system(size: 34, weight: .heavy, design: .rounded))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)
                    .padding(.top, 8)
                    .frame(maxWidth: .infinity, alignment: .center)

                VStack(spacing: 10) {
                    TextField("", text: $name)
                        .font(.system(size: 45, weight: .semibold, design: .rounded))
                        .foregroundStyle(.primary)
                        .tint(Palette.accent)
                        .multilineTextAlignment(.center)
                        .textContentType(.name)
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled(false)
                        .focused($isFocused)
                        .submitLabel(.done)
                        .onSubmit { commit() }
                        .onChange(of: name) { _, newValue in
                            let clamped = String(newValue.trimmingCharacters(in: .whitespacesAndNewlines).prefix(maxLength))
                            if clamped != newValue { name = clamped }
                            storedName = clamped
                            if let repo = profileRepo {
                                Task { try? await repo.updateName(clamped) }
                            }
                        }

                    Rectangle()
                        .fill(Color.secondary.opacity(0.20))
                        .frame(height: 1)
                        .overlay(alignment: .leading) {
                            GeometryReader { geo in
                                Rectangle()
                                    .fill(.clear)
                                    .frame(width: underlineWidth(in: geo.size.width), height: 2)
                                    .offset(y: -0.5)
                                    .allowsHitTesting(false)
                            }
                        }
                        .frame(height: 2)
                }
                .padding(.horizontal, 36)
                .padding(.top, 10)

                Spacer()
            }
        }
        // ✅ キーボード初期フォーカスOFF
        .task {
            isFocused = false
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
        let final = String(trimmed.prefix(maxLength))
        name = final
        storedName = final
        if let repo = profileRepo {
            Task { try? await repo.updateName(final) }
        }
        onContinue()
    }

    private func underlineWidth(in total: CGFloat) -> CGFloat {
        let minW = total * 0.08
        let maxW = total
        let ratio = min(1.0, Double(trimmed.count) / 12.0)
        return minW + CGFloat(ratio) * (maxW - minW)
    }
}

// MARK: - Preview Helper

/// 便利: @State をバインディングで渡すためのラッパ
private struct StatefulPreviewWrapper<Value, Content: View>: View {
    @State private var value: Value
    private let content: (Binding<Value>) -> Content
    init(_ value: Value, @ViewBuilder content: @escaping (Binding<Value>) -> Content) {
        _value = State(initialValue: value)
        self.content = content
    }
    var body: some View { content($value) }
}

#Preview {
    StatefulPreviewWrapper("") { $name in
        OLNameStepView(name: $name, gate: FlowGate())
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(.systemBackground))
    }
}
