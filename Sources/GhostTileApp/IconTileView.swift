import AppKit
import SwiftUI

struct IconTileView: View {
    let icon: NSImage
    let size: CGFloat
    var cornerRadius: CGFloat
    var iconInset: CGFloat
    var fill: AnyShapeStyle
    var strokeColor: Color? = nil

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(fill)
                .overlay {
                    if let strokeColor {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .stroke(strokeColor, lineWidth: 1)
                    }
                }

            Image(nsImage: icon)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: size - iconInset, height: size - iconInset)
        }
        .frame(width: size, height: size)
    }
}
