import LSAppCategory
import SwiftUI

// MARK: - Running App Row

struct RunningAppRow: View {
    let app: AppViewModel.AppItem
    let isLoading: Bool
    let onHide: () -> Void

    @State private var hovering = false

    var body: some View {
        HStack(spacing: 12) {
            iconTile

            VStack(alignment: .leading, spacing: 2) {
                Text(app.name)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)

                HStack(spacing: 4) {
                    if app.category != .other {
                        Image(systemName: app.category.sfSymbol)
                            .font(.system(size: 9))
                            .foregroundColor(.accentColor)
                        Text(app.category.description)
                            .font(.system(size: 11))
                    } else {
                        Text(app.id)
                            .font(.system(size: 11))
                    }
                }
                .foregroundStyle(.secondary)
                .lineLimit(1)
            }

            Spacer()

            if isLoading {
                ProgressView()
                    .controlSize(.small)
            } else if hovering {
                Button {
                    onHide()
                } label: {
                    Image(systemName: "eye.slash")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .help("Hide from Dock")
                .transition(.opacity)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(hovering ? Color.primary.opacity(0.07) : Color.primary.opacity(0.025))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .strokeBorder(Color.primary.opacity(hovering ? 0.08 : 0.04), lineWidth: 1)
        )
        .onHover { hovering = $0 }
        .animation(.easeOut(duration: 0.15), value: hovering)
    }

    private var iconTile: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.primary.opacity(0.04))
            Image(nsImage: app.icon)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 44, height: 44)
        }
        .frame(width: 56, height: 56)
    }
}

// MARK: - Managed App Row

struct ManagedAppRow: View {
    let app: AppViewModel.AppItem
    let isLoading: Bool
    let onShow: () -> Void
    let onHide: () -> Void
    let onShowInFinder: () -> Void
    let onRemove: () -> Void

    @State private var hovering = false

    var body: some View {
        HStack(spacing: 12) {
            iconTile

            VStack(alignment: .leading, spacing: 2) {
                Text(app.name)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)

                HStack(spacing: 4) {
                    Circle()
                        .fill(app.isRunning ? (app.isHiddenFromDock ? .orange : .green) : .secondary.opacity(0.4))
                        .frame(width: 6, height: 6)
                    if app.isRunning {
                        Text(app.isHiddenFromDock ? "Hidden from Dock" : "Visible in Dock")
                            .font(.system(size: 11))
                    } else {
                        Text("Not Running")
                            .font(.system(size: 11))
                    }
                }
                .foregroundStyle(.secondary)
                .lineLimit(1)
            }

            Spacer()

            if isLoading {
                ProgressView()
                    .controlSize(.small)
            } else if app.isRunning {
                HStack(spacing: 4) {
                    Button {
                        onShow()
                    } label: {
                        Image(systemName: "eye")
                            .font(.system(size: 11))
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .help("Show in Dock")
                    .disabled(!app.isHiddenFromDock)

                    Button {
                        onHide()
                    } label: {
                        Image(systemName: "eye.slash")
                            .font(.system(size: 11))
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .help("Hide from Dock")
                    .disabled(app.isHiddenFromDock)
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(hovering ? Color.primary.opacity(0.07) : Color.primary.opacity(0.025))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .strokeBorder(Color.primary.opacity(hovering ? 0.08 : 0.04), lineWidth: 1)
        )
        .onHover { hovering = $0 }
        .animation(.easeOut(duration: 0.15), value: hovering)
        .contextMenu {
            Button("Show in Finder") { onShowInFinder() }
            Divider()
            Button("Remove") { onRemove() }
        }
    }

    private var iconTile: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.primary.opacity(0.04))
            Image(nsImage: app.icon)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 44, height: 44)
        }
        .frame(width: 56, height: 56)
    }
}
