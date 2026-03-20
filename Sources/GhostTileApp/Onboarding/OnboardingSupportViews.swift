import AppKit
import SwiftUI

struct PermissionCard: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let tint: Color
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(tint.opacity(0.12))
                Image(systemName: systemImage)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(tint)
            }
            .frame(width: 52, height: 52)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white.opacity(0.06))
        )
    }
}

struct OnboardingWindowCenterer: NSViewRepresentable {
    func makeNSView(context _: Context) -> NSView {
        NSView()
    }

    func updateNSView(_ nsView: NSView, context _: Context) {
        DispatchQueue.main.async {
            guard let window = nsView.window else { return }
            guard let screen = window.screen ?? NSScreen.main else {
                window.center()
                return
            }

            let visibleFrame = screen.visibleFrame
            var frame = window.frame
            frame.origin.x = visibleFrame.midX - (frame.width / 2)
            frame.origin.y = visibleFrame.midY - (frame.height / 2)
            window.setFrame(frame, display: false)
        }
    }
}
