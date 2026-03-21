import SwiftUI

struct SearchFieldView: View {
    let placeholder: String
    @Binding var text: String
    let width: CGFloat
    let isDarkMode: Bool
    var focus: FocusState<Bool>.Binding?

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)

            if let focus {
                TextField(placeholder, text: $text)
                    .textFieldStyle(.plain)
                    .frame(width: width)
                    .focused(focus)
            } else {
                TextField(placeholder, text: $text)
                    .textFieldStyle(.plain)
                    .frame(width: width)
            }
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 9)
        .background(backgroundShape)
        .overlay(strokeShape)
    }

    private var backgroundShape: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(isDarkMode ? Color.black.opacity(0.14) : Color.white.opacity(0.7))
    }

    private var strokeShape: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .stroke(
                isDarkMode ? Color.white.opacity(0.08) : Color.black.opacity(0.07),
                lineWidth: 1
            )
    }
}
