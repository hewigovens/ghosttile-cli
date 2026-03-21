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

    func sectionCard(
        title: String,
        symbol: String,
        @ViewBuilder content: () -> some View
    ) -> some View {
        SettingsSectionCard(title: title, symbol: symbol) {
            content()
        }
    }

    func settingsRow(
        title: String,
        symbol: String,
        toggle: Binding<Bool>
    ) -> some View {
        HStack(alignment: .center, spacing: 12) {
            SettingsRowIcon(symbol: symbol)

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

    func shortcutRow(
        title: String,
        symbol: String,
        description: String,
        @ViewBuilder recorder: () -> some View
    ) -> some View {
        HStack(alignment: .center, spacing: 12) {
            SettingsRowIcon(symbol: symbol)

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
            SettingsRowIcon(symbol: symbol)

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
            SettingsRowIcon(symbol: symbol)

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
        StatusPill(text: text, color: color)
    }
}
