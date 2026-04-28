import AppKit
import GhostTileCore
import SwiftUI

extension MainWindowView {
    var header: some View {
        HStack(alignment: .top, spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                Text("GhostTile")
                    .font(.system(size: 30, weight: .bold, design: .rounded))

                HStack(spacing: 8) {
                    statPill(title: "Managed", value: viewModel.totalManagedCount, systemImage: "eye.slash")
                    statPill(title: "Running", value: viewModel.runningCount, systemImage: "app.badge")
                    statPill(
                        title: "Active Hidden",
                        value: viewModel.hiddenRunningCount,
                        systemImage: "bolt.horizontal.circle"
                    )
                }
            }

            Spacer(minLength: 20)

            VStack(alignment: .trailing, spacing: 10) {
                HStack(spacing: 10) {
                    SearchFieldView(
                        placeholder: "Search managed or running apps",
                        text: $viewModel.query,
                        width: 240,
                        isDarkMode: isDarkMode
                    )

                    Button("Add App", action: { viewModel.selectAppToHide(with: appViewModel) })
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                }
            }
        }
    }

    var managedSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center) {
                SectionHeaderView(
                    title: "Managed Apps",
                    subtitle: "Click a card to reveal or launch."
                )
                Spacer()
                if viewModel.dropTargeted {
                    Text("Drop to manage")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.accentColor)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(Color.accentColor.opacity(0.14)))
                }
            }

            if viewModel.managedApps.isEmpty {
                managedEmptyState
            } else {
                ScrollView {
                    LazyVGrid(
                        columns: [
                            GridItem(.flexible(minimum: 220, maximum: 320), spacing: 14),
                            GridItem(.flexible(minimum: 220, maximum: 320), spacing: 14),
                        ],
                        spacing: 14
                    ) {
                        ForEach(viewModel.managedApps) { app in
                            ManagedAppCard(
                                app: app,
                                isLoading: appViewModel.loading.contains(app.id),
                                actions: appViewModel,
                                onPrimaryAction: {
                                    if app.isRunning {
                                        appViewModel.setDockVisibility(app, hidden: !app.isHiddenFromDock)
                                    } else {
                                        appViewModel.activateManagedApp(app)
                                    }
                                }
                            )
                        }
                    }
                    .padding(.bottom, 10)
                }
                .scrollIndicators(.never)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .padding(18)
        .background(sectionBackground(isDropTargeted: viewModel.dropTargeted))
        .onDrop(of: [.fileURL], isTargeted: $viewModel.dropTargeted) { providers in
            viewModel.handleFileDrop(providers, appViewModel: appViewModel)
        }
    }

    var runningSidebar: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center) {
                SectionHeaderView(title: "Running Apps", subtitle: "Hide active apps quickly.")
                Spacer()
                Button {
                    appViewModel.refresh()
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 12, weight: .medium))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .help("Refresh")
            }

            if viewModel.runningApps.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Nothing available")
                        .font(.system(size: 14, weight: .semibold))
                    Text("Launch an app or remove filters to hide it from the Dock.")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(isDarkMode ? Color.white.opacity(0.05) : Color.white.opacity(0.64))
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(viewModel.runningApps) { app in
                            RunningAppSidebarRow(
                                app: app,
                                isLoading: appViewModel.loading.contains(app.id),
                                onHide: { appViewModel.hideRunningApp(app) }
                            )
                        }
                    }
                    .padding(.bottom, 8)
                }
                .scrollIndicators(.never)
            }
        }
        .frame(width: runningSidebarWidth)
        .frame(maxHeight: .infinity, alignment: .top)
        .padding(16)
        .background(sidebarBackground)
    }

    var managedEmptyState: some View {
        let emptyTitle = viewModel.query.isEmpty ? "No managed apps yet" : "No matching managed apps"
        let emptySubtitle = viewModel.query.isEmpty
            ? "Drop an app here, or use Add App in the toolbar to choose one from Finder."
            : "Try a different search term or clear the search field."

        return VStack(spacing: 18) {
            ghostImage
                .frame(width: 60, height: 66)
                .opacity(viewModel.dropTargeted ? 0.95 : 0.55)
                .scaleEffect(viewModel.dropTargeted ? 1.08 : 1)
                .animation(.spring(response: 0.28), value: viewModel.dropTargeted)

            VStack(spacing: 6) {
                Text(emptyTitle)
                    .font(.system(size: 20, weight: .semibold))

                Text(emptySubtitle)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 420)
            }

        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(32)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(isDarkMode ? Color.white.opacity(0.04) : Color.white.opacity(0.58))
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(
                            viewModel.dropTargeted
                                ? Color.accentColor.opacity(0.34)
                                : (isDarkMode ? Color.white.opacity(0.06) : Color.black.opacity(0.06)),
                            style: StrokeStyle(lineWidth: 1.2, dash: [8, 8])
                        )
                )
        )
    }
}
