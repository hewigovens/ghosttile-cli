import AppKit
import SwiftUI

struct MainWindowView: View {
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject var vm: AppViewModel
    @StateObject var viewModel: MainWindowViewModel
    @ObservedObject private var sponsorNudge = SponsorNudgeController.shared

    let runningSidebarWidth: CGFloat = 300

    var isDarkMode: Bool { colorScheme == .dark }

    init(vm: AppViewModel) {
        self.vm = vm
        _viewModel = StateObject(wrappedValue: MainWindowViewModel(store: vm.managedAppsStore))
    }

    var body: some View {
        ZStack {
            windowBackground

            VStack(spacing: 14) {
                header

                HStack(alignment: .top, spacing: 18) {
                    managedSection
                    runningSidebar
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)
            .padding(.bottom, 22)
        }
        .frame(minWidth: 940, idealWidth: 1040, minHeight: 680, idealHeight: 760)
        .onAppear { vm.refresh() }
        .alert("Error", isPresented: $vm.showError) {
            Button("OK") {}
        } message: {
            Text(vm.errorMessage)
        }
        .alert("Support GhostTile", isPresented: $sponsorNudge.isPresented) {
            Button("Sponsor on GitHub") {
                sponsorNudge.openSponsorsPage()
            }
            Button("Not Now", role: .cancel) {
                sponsorNudge.remindLater()
            }
            Button("Don't Ask Again", role: .destructive) {
                sponsorNudge.stopPrompting()
            }
        } message: {
            Text("If GhostTile is useful in your daily workflow, sponsoring helps fund ongoing macOS compatibility work.")
        }
        .sheet(isPresented: Binding(
            get: { vm.sudoCommand != nil },
            set: { if !$0 { vm.sudoCommand = nil } }
        )) {
            SudoCommandSheet(command: vm.sudoCommand ?? "")
        }
    }

}
