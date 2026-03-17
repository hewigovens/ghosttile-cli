import AppKit
import SwiftUI

struct OverviewView: View {
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject var vm: AppViewModel
    @StateObject var viewModel: OverviewViewModel
    @ObservedObject var thumbnailStore: OverviewThumbnailStore
    let onDismiss: () -> Void

    @FocusState var searchFocused: Bool
    var isDarkMode: Bool { colorScheme == .dark }

    init(vm: AppViewModel, thumbnailStore: OverviewThumbnailStore, onDismiss: @escaping () -> Void) {
        self.vm = vm
        self.thumbnailStore = thumbnailStore
        self.onDismiss = onDismiss
        _viewModel = StateObject(wrappedValue: OverviewViewModel(store: vm.managedAppsStore))
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
                                    isSelected: app.id == viewModel.selectedBundleId,
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
            viewModel.ensureInitialSelection()
        }
        .onMoveCommand { direction in
            viewModel.moveSelection(direction)
        }
        .onSubmit {
            openSelectedApp()
        }
        .onExitCommand {
            onDismiss()
        }
    }

    var filteredApps: [ManagedAppItem] {
        viewModel.filteredApps
    }

    func openSelectedApp() {
        guard let app = viewModel.selectedApp() else { return }
        vm.handleAttentionNotificationClick(bundleId: app.id)
        onDismiss()
    }
}
