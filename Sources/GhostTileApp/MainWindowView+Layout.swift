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
                    statPill(title: "Managed", value: totalManagedCount, systemImage: "eye.slash")
                    statPill(title: "Running", value: runningCount, systemImage: "app.badge")
                    statPill(title: "Active Hidden", value: hiddenRunningCount, systemImage: "bolt.horizontal.circle")
                }
            }

            Spacer(minLength: 20)

            VStack(alignment: .trailing, spacing: 10) {
                HStack(spacing: 10) {
                    HStack(spacing: 10) {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(.secondary)
                        TextField("Search managed or running apps", text: $query)
                            .textFieldStyle(.plain)
                            .frame(width: 240)
                    }
                    .padding(.horizontal, 13)
                    .padding(.vertical, 9)
                    .background(searchFieldBackground)
                    .overlay(searchFieldStroke)

                    Button("Add App", action: selectAppToHide)
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                }
            }
        }
    }

    var managedSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center) {
                sectionHeading(
                    title: "Managed Apps",
                    subtitle: "Click a card to reveal or launch."
                )
                Spacer()
                if dropTargeted {
                    Text("Drop to manage")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.accentColor)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(Color.accentColor.opacity(0.14)))
                }
            }

            if filteredManagedApps.isEmpty {
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
                        ForEach(filteredManagedApps) { app in
                            ManagedAppCard(
                                app: app,
                                isLoading: vm.loading.contains(app.id),
                                onOpen: { vm.handleAttentionNotificationClick(bundleId: app.id) },
                                onPrimaryAction: {
                                    if app.isRunning {
                                        app.isHiddenFromDock ? vm.showAppInDock(app) : vm.hideAppFromDock(app)
                                    } else {
                                        vm.activateManagedApp(app)
                                    }
                                },
                                onReveal: { vm.revealAppInFinder(app) },
                                onRemove: { vm.removeApp(app) }
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
        .background(sectionBackground(isDropTargeted: dropTargeted))
        .onDrop(of: [.fileURL], isTargeted: $dropTargeted) { providers in
            handleFileDrop(providers)
        }
    }

    var runningSidebar: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center) {
                sectionHeading(title: "Running Apps", subtitle: "Hide active apps quickly.")
                Spacer()
                Button {
                    vm.refresh()
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 12, weight: .medium))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .help("Refresh")
            }

            if filteredRunningApps.isEmpty {
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
                        ForEach(filteredRunningApps) { app in
                            RunningAppSidebarRow(
                                app: app,
                                isLoading: vm.loading.contains(app.id),
                                onHide: { vm.hideRunningApp(app) }
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
        let emptyTitle = query.isEmpty ? "No managed apps yet" : "No matching managed apps"
        let emptySubtitle = query.isEmpty
            ? "Add an app or drag one in from Finder to start building your hidden set."
            : "Try a different search term or clear the search field."

        return VStack(spacing: 18) {
            ghostImage
                .frame(width: 60, height: 66)
                .opacity(dropTargeted ? 0.95 : 0.55)
                .scaleEffect(dropTargeted ? 1.08 : 1)
                .animation(.spring(response: 0.28), value: dropTargeted)

            VStack(spacing: 6) {
                Text(emptyTitle)
                    .font(.system(size: 20, weight: .semibold))

                Text(emptySubtitle)
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 420)
            }

            if query.isEmpty {
                Button("Add App", action: selectAppToHide)
                    .buttonStyle(.borderedProminent)
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
                            dropTargeted
                                ? Color.accentColor.opacity(0.34)
                                : (isDarkMode ? Color.white.opacity(0.06) : Color.black.opacity(0.06)),
                            style: StrokeStyle(lineWidth: 1.2, dash: [8, 8])
                        )
                )
        )
    }

    var searchFieldBackground: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(isDarkMode ? Color.black.opacity(0.14) : Color.white.opacity(0.7))
    }

    var searchFieldStroke: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .stroke(
                isDarkMode ? Color.white.opacity(0.08) : Color.black.opacity(0.07),
                lineWidth: 1
            )
    }
}
