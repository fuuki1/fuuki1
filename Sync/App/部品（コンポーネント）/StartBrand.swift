import SwiftUI

struct StartBrand: View {
    var text: String

    var body: some View {
        HStack(spacing: 8) {
            Text(text)
                .font(.caption.weight(.heavy))
                .tracking(1.0)
                .textCase(.uppercase)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(
            Capsule(style: .circular)
                .fill(.white.opacity(0.15))
        )
        .overlay(
            Capsule(style: .circular)
                .stroke(.white.opacity(0.25), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
    }
}



#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        StartBrand(text: "SYNC  FITNESS")
    }
}
