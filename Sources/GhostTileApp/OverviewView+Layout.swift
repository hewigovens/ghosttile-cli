import AppKit
import SwiftUI

extension OverviewView {
    var header: some View {
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
                .background(searchFieldBackground)
                .overlay(searchFieldStroke)

                HStack(spacing: 10) {
                    Label("\(vm.hiddenApps.count)", systemImage: "eye.slash")
                        .font(.system(size: 12, weight: .semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(countPillBackground)

                    Button("Done") { onDismiss() }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                }
            }
        }
    }

    var emptyState: some View {
        let title = vm.hiddenApps.isEmpty ? "No managed apps" : "No matching apps"
        let subtitle = vm.hiddenApps.isEmpty
            ? "Hide a few apps first, then open Overview."
            : "Try a different search term."

        return VStack(spacing: 10) {
            Spacer()
            Image(systemName: "eye.slash.circle")
                .font(.system(size: 44, weight: .light))
                .foregroundStyle(.tertiary)
            Text(title)
                .font(.system(size: 16, weight: .medium))
            Text(subtitle)
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    var permissionBanner: some View {
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

    var previewUnavailableBanner: some View {
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
        .background(previewUnavailableBackground)
        .overlay(previewUnavailableStroke)
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

    var countPillBackground: some View {
        Capsule()
            .fill(isDarkMode ? Color.primary.opacity(0.08) : Color.white.opacity(0.7))
    }

    var previewUnavailableBackground: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(isDarkMode ? Color.primary.opacity(0.05) : Color.white.opacity(0.6))
    }

    var previewUnavailableStroke: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .stroke(
                isDarkMode ? Color.white.opacity(0.08) : Color.black.opacity(0.06),
                lineWidth: 1
            )
    }
}
