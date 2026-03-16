import AppKit
import SwiftUI

struct OverviewView: View {
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject var vm: AppViewModel
    @ObservedObject var thumbnailStore: OverviewThumbnailStore
    let onDismiss: () -> Void

    @State var query = ""
    @State var selectedBundleId: String?
    @FocusState var searchFocused: Bool
    var isDarkMode: Bool { colorScheme == .dark }

    var filteredApps: [AppViewModel.AppItem] {
        guard !query.isEmpty else { return vm.hiddenApps }
        let needle = query.lowercased()
        return vm.hiddenApps.filter { app in
            app.name.lowercased().contains(needle) || app.id.lowercased().contains(needle)
        }
    }

    let columns = [
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
}
