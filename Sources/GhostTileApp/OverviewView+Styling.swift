import SwiftUI

extension OverviewView {
    var backgroundGlow: some View {
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
}
