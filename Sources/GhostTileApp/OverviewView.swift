import AppKit
import SwiftUI

struct OverviewView: View {
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject var vm: AppViewModel
    @ObservedObject var thumbnailStore: OverviewThumbnailStore
    let onDismiss: () -> Void

    @State private var query = ""
    @State private var selectedBundleId: String?
    @FocusState private var searchFocused: Bool
    private var isDarkMode: Bool { colorScheme == .dark }

    private var filteredApps: [AppViewModel.AppItem] {
        guard !query.isEmpty else { return vm.hiddenApps }
        let needle = query.lowercased()
        return vm.hiddenApps.filter { app in
            app.name.lowercased().contains(needle) || app.id.lowercased().contains(needle)
        }
    }

    private let columns = [
        GridItem(.adaptive(minimum: 228, maximum: 272), spacing: 16, alignment: .top)
    ]

    var body: some View {
        ZStack {
            if isDarkMode {
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .overlay(backgroundGlow)
                    .ignoresSafeArea()
            } else {
                Rectangle()
                    .fill(Color(nsColor: .windowBackgroundColor))
                    .overlay(backgroundGlow)
                    .ignoresSafeArea()
            }

            VStack(alignment: .leading, spacing: 16) {
                header
                if !thumbnailStore.supportsLivePreviews {
                    previewUnavailableBanner
                } else if thumbnailStore.capturePermissionState == .needsAccess {
                    permissionBanner
                }

                if filteredApps.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 16) {
                            ForEach(filteredApps) { app in
                                OverviewCard(
                                    app: app,
                                    thumbnail: thumbnailStore.thumbnail(for: app.id),
                                    isSelected: app.id == selectedBundleId,
                                    onOpen: {
                                        vm.handleAttentionNotificationClick(bundleId: app.id)
                                        onDismiss()
                                    },
                                    onShow: { vm.showAppInDock(app) },
                                    onHide: { vm.hideAppFromDock(app) },
                                    onReveal: { vm.revealAppInFinder(app) },
                                    onRemove: { vm.removeApp(app) }
                                )
                            }
                        }
                        .padding(.bottom, 20)
                    }
                    .scrollIndicators(.never)
                }
            }
            .padding(24)
        }
        .onAppear {
            searchFocused = true
            if selectedBundleId == nil {
                selectedBundleId = filteredApps.first?.id
            }
        }
        .onChange(of: vm.hiddenApps.map(\.id)) {
            syncSelection()
        }
        .onChange(of: query) {
            syncSelection()
        }
        .onMoveCommand(perform: moveSelection)
        .onSubmit {
            openSelectedApp()
        }
        .onExitCommand {
            onDismiss()
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 18) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Overview")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                Text("Managed apps. Click a card to reveal and activate.")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 16)

            VStack(alignment: .trailing, spacing: 10) {
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField("Search apps or bundle ID", text: $query)
                        .textFieldStyle(.plain)
                        .frame(width: 260)
                        .focused($searchFocused)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(isDarkMode ? Color.black.opacity(0.14) : Color.white.opacity(0.7))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(
                            isDarkMode ? Color.white.opacity(0.08) : Color.black.opacity(0.07),
                            lineWidth: 1
                        )
                )

                HStack(spacing: 10) {
                    Label("\(vm.hiddenApps.count)", systemImage: "eye.slash")
                        .font(.system(size: 12, weight: .semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(
                            Capsule()
                                .fill(isDarkMode ? Color.primary.opacity(0.08) : Color.white.opacity(0.7))
                        )

                    Button("Done") { onDismiss() }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Spacer()
            Image(systemName: "eye.slash.circle")
                .font(.system(size: 44, weight: .light))
                .foregroundStyle(.tertiary)
            Text(vm.hiddenApps.isEmpty ? "No managed apps" : "No matching apps")
                .font(.system(size: 16, weight: .medium))
            Text(vm.hiddenApps.isEmpty ? "Hide a few apps first, then open Overview." : "Try a different search term.")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private var permissionBanner: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: "rectangle.on.rectangle.slash")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 3) {
                Text("Window previews need Screen Recording access")
                    .font(.system(size: 13, weight: .semibold))
                Text("GhostTile can still show icon cards immediately. Grant access if you want live thumbnails.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("Grant Access") {
                thumbnailStore.requestCaptureAccess()
                thumbnailStore.warmCache(for: vm.hiddenApps, force: true)
            }
            .buttonStyle(.bordered)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(isDarkMode ? Color.orange.opacity(0.1) : Color.orange.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.orange.opacity(0.18), lineWidth: 1)
        )
    }

    private var previewUnavailableBanner: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: "photo.stack")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 3) {
                Text("Live window previews need a newer macOS build")
                    .font(.system(size: 13, weight: .semibold))
                Text("Overview still opens instantly with app icons, but live thumbnails require macOS 15.2 or newer.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(isDarkMode ? Color.primary.opacity(0.05) : Color.white.opacity(0.6))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(
                    isDarkMode ? Color.white.opacity(0.08) : Color.black.opacity(0.06),
                    lineWidth: 1
                )
        )
    }

    private var backgroundGlow: some View {
        ZStack {
            Circle()
                .fill(Color.blue.opacity(isDarkMode ? 0.12 : 0.07))
                .frame(width: 440, height: 440)
                .blur(radius: 80)
                .offset(x: -260, y: -180)

            Circle()
                .fill(Color.orange.opacity(isDarkMode ? 0.08 : 0.04))
                .frame(width: 320, height: 320)
                .blur(radius: 80)
                .offset(x: 240, y: 220)
        }
    }

    private func moveSelection(_ direction: MoveCommandDirection) {
        guard !filteredApps.isEmpty else { return }

        let currentIndex = filteredApps.firstIndex { $0.id == selectedBundleId } ?? 0
        let nextIndex: Int

        switch direction {
        case .left, .up:
            nextIndex = max(0, currentIndex - 1)
        case .right, .down:
            nextIndex = min(filteredApps.count - 1, currentIndex + 1)
        @unknown default:
            nextIndex = currentIndex
        }

        selectedBundleId = filteredApps[nextIndex].id
    }

    private func syncSelection() {
        guard !filteredApps.isEmpty else {
            selectedBundleId = nil
            return
        }

        if let selectedBundleId,
           filteredApps.contains(where: { $0.id == selectedBundleId }) {
            return
        }

        self.selectedBundleId = filteredApps.first?.id
    }

    private func openSelectedApp() {
        guard let selectedBundleId,
              let app = filteredApps.first(where: { $0.id == selectedBundleId })
        else { return }

        vm.handleAttentionNotificationClick(bundleId: app.id)
        onDismiss()
    }
}

private struct OverviewCard: View {
    @Environment(\.colorScheme) private var colorScheme
    let app: AppViewModel.AppItem
    let thumbnail: NSImage?
    let isSelected: Bool
    let onOpen: () -> Void
    let onShow: () -> Void
    let onHide: () -> Void
    let onReveal: () -> Void
    let onRemove: () -> Void

    @State private var hovering = false
    private var isDarkMode: Bool { colorScheme == .dark }
    private var cardFillColor: Color {
        isDarkMode ? Color.black.opacity(0.22) : Color.white.opacity(0.56)
    }

    private var cardStrokeColor: Color {
        if isSelected {
            return Color.accentColor.opacity(0.35)
        }

        return isDarkMode ? Color.white.opacity(hovering ? 0.12 : 0.05) : Color.black.opacity(hovering ? 0.08 : 0.05)
    }

    private var previewStrokeColor: Color {
        if isSelected {
            return Color.accentColor.opacity(0.75)
        }

        return isDarkMode ? Color.white.opacity(hovering ? 0.18 : 0.08) : Color.black.opacity(hovering ? 0.08 : 0.05)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ZStack(alignment: .bottomLeading) {
                thumbnailBody

                LinearGradient(
                    colors: [Color.clear, Color.black.opacity(0.55)],
                    startPoint: .top,
                    endPoint: .bottom
                )

                HStack(alignment: .center, spacing: 10) {
                    Image(nsImage: app.icon)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 28, height: 28)
                        .padding(6)
                        .background(iconChipBackground)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(app.name)
                            .font(.system(size: 15, weight: .semibold))
                            .lineLimit(1)
                        Text(app.id)
                            .font(.system(size: 11))
                            .foregroundStyle(.white.opacity(0.75))
                            .lineLimit(1)
                    }
                }
                .padding(14)
            }
            .frame(height: 154)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(previewStrokeColor, lineWidth: isSelected ? 2 : 1)
            )

            HStack(spacing: 8) {
                statusPill
                Spacer()
                actionButtons
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(cardFillColor)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(cardStrokeColor, lineWidth: isSelected ? 1.5 : 1)
        )
        .shadow(color: .black.opacity(isDarkMode ? 0.16 : 0.05), radius: 20, y: 10)
        .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .onTapGesture(perform: onOpen)
        .onHover { hovering = $0 }
        .animation(.easeOut(duration: 0.14), value: hovering)
        .contextMenu {
            if app.isRunning {
                if app.isHiddenFromDock {
                    Button("Show in Dock", action: onShow)
                } else {
                    Button("Hide from Dock", action: onHide)
                }
            }
            Button("Reveal in Finder", action: onReveal)
            Divider()
            Button("Remove from GhostTile", action: onRemove)
        }
    }

    @ViewBuilder
    private var thumbnailBody: some View {
        if let thumbnail {
            Image(nsImage: thumbnail)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(isDarkMode ? Color.black.opacity(0.75) : Color.white.opacity(0.64))
        } else {
            ZStack {
                LinearGradient(
                    colors: [
                        Color.blue.opacity(isDarkMode ? 0.25 : 0.14),
                        isDarkMode ? Color.black.opacity(0.7) : Color.white.opacity(0.56)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                Image(nsImage: app.icon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 76, height: 76)
                    .opacity(0.88)
            }
        }
    }

    private var iconChipBackground: some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(isDarkMode ? AnyShapeStyle(.ultraThinMaterial) : AnyShapeStyle(Color.white.opacity(0.74)))
    }

    private var statusPill: some View {
        Text(statusText)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(statusColor)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(
                Capsule()
                    .fill(statusColor.opacity(0.14))
            )
    }

    private var actionButtons: some View {
        HStack(spacing: 6) {
            if app.isRunning {
                Button {
                    app.isHiddenFromDock ? onShow() : onHide()
                } label: {
                    Image(systemName: app.isHiddenFromDock ? "eye" : "eye.slash")
                        .font(.system(size: 11, weight: .semibold))
                }
                .buttonStyle(.borderless)
                .foregroundStyle(.secondary)
            }

            Button(action: onReveal) {
                Image(systemName: "folder")
                    .font(.system(size: 11, weight: .semibold))
            }
            .buttonStyle(.borderless)
            .foregroundStyle(.secondary)

            Button(action: onRemove) {
                Image(systemName: "trash")
                    .font(.system(size: 11, weight: .semibold))
            }
            .buttonStyle(.borderless)
            .foregroundStyle(.secondary)
        }
    }

    private var statusText: String {
        if !app.isRunning {
            return "Not Running"
        }
        return app.isHiddenFromDock ? "Hidden" : "Visible"
    }

    private var statusColor: Color {
        if !app.isRunning {
            return .secondary
        }
        return app.isHiddenFromDock ? .orange : .green
    }
}
