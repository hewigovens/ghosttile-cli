import SwiftUI

struct StatusPill: View {
    let text: String
    let color: Color
    var textSize: CGFloat = 10

    var body: some View {
        Text(text)
            .font(.system(size: textSize, weight: .semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(color.opacity(0.12))
            )
    }
}
