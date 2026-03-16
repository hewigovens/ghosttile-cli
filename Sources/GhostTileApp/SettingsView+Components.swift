import SwiftUI

extension SettingsView {
    var settingsBackground: some View {
        ZStack {
            Color(nsColor: .windowBackgroundColor)

            LinearGradient(
                colors: [
                    Color.blue.opacity(0.06),
                    Color.clear,
                    Color.green.opacity(0.05),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(Color.blue.opacity(0.05))
                .frame(width: 240, height: 240)
                .blur(radius: 55)
                .offset(x: -170, y: -180)

            Circle()
                .fill(Color.orange.opacity(0.05))
                .frame(width: 220, height: 220)
                .blur(radius: 55)
                .offset(x: 170, y: 180)
        }
    }

    func sectionCard<Content: View>(
        title: String,
        symbol: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 10) {
                Image(systemName: symbol)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.primary)
                    .frame(width: 28, height: 28)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color.primary.opacity(0.06))
                    )

                Text(title)
                    .font(.system(size: 14, weight: .semibold))
            }

            content()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
                )
        )
        .shadow(color: .black.opacity(0.04), radius: 12, y: 5)
    }

    func settingsRow(
        title: String,
        symbol: String,
        toggle: Binding<Bool>
    ) -> some View {
        HStack(alignment: .center, spacing: 12) {
            rowIcon(symbol)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
            }
            Spacer()
            Toggle("", isOn: toggle)
                .toggleStyle(.switch)
                .controlSize(.small)
                .labelsHidden()
        }
    }

    func shortcutRow<Recorder: View>(
        title: String,
        symbol: String,
        description: String,
        @ViewBuilder recorder: () -> Recorder
    ) -> some View {
        HStack(alignment: .center, spacing: 12) {
            rowIcon(symbol)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                Text(description)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            recorder()
                .labelsHidden()
        }
    }

    func infoRow(
        title: String,
        value: String,
        symbol: String?
    ) -> some View {
        HStack(alignment: .center, spacing: 12) {
            if let symbol, !symbol.isEmpty {
                rowIcon(symbol)
            } else {
                rowIcon(nil)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
            }

            Spacer()

            Text(value)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    func actionRow(
        title: String,
        value: String,
        symbol: String,
        action: @escaping () -> Void
    ) -> some View {
        HStack(alignment: .center, spacing: 12) {
            rowIcon(symbol)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
            }

            Spacer()

            Button(action: action) {
                HStack(spacing: 6) {
                    Text(value)
                        .font(.system(size: 12, weight: .medium))
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 11, weight: .semibold))
                }
            }
            .buttonStyle(.plain)
        }
    }

    func statusPill(text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(color.opacity(0.12))
            )
    }

    @ViewBuilder
    private func rowIcon(_ symbol: String?) -> some View {
        if let symbol, !symbol.isEmpty {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 28, height: 28)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.primary.opacity(0.05))
                )
        } else {
            Color.clear
                .frame(width: 28, height: 28)
        }
    }
}
