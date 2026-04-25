import SwiftUI

struct PermissionDragSourceRepresentable: NSViewRepresentable {
    let target: PermissionGuidanceTarget

    func makeNSView(context _: Context) -> PermissionDragSourceView {
        PermissionDragSourceView(target: target)
    }

    func updateNSView(_: PermissionDragSourceView, context _: Context) {}
}
