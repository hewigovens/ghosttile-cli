import AppKit
import Foundation

final class PermissionDragSourceView: NSView, NSDraggingSource, NSPasteboardItemDataProvider {
    private let target: PermissionGuidanceTarget
    private let rowView = NSView()
    private let iconChrome = NSView()
    private let label = NSTextField(labelWithString: "")

    init(target: PermissionGuidanceTarget) {
        self.target = target
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        setup()
        updateAppearance()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func acceptsFirstMouse(for _: NSEvent?) -> Bool {
        true
    }

    override func mouseDown(with event: NSEvent) {
        let pasteboardItem = NSPasteboardItem()
        pasteboardItem.setDataProvider(self, forTypes: [.fileURL])

        let draggingItem = NSDraggingItem(pasteboardWriter: pasteboardItem)
        draggingItem.setDraggingFrame(rowFrameInSelf(), contents: draggingImage())

        let session = beginDraggingSession(with: [draggingItem], event: event, source: self)
        session.animatesToStartingPositionsOnCancelOrFail = true
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        updateAppearance()
    }

    func pasteboard(
        _: NSPasteboard?,
        item: NSPasteboardItem,
        provideDataForType type: NSPasteboard.PasteboardType
    ) {
        guard type == .fileURL else { return }
        item.setData(target.bundleURL.dataRepresentation, forType: .fileURL)
    }

    func draggingSession(_: NSDraggingSession, willBeginAt _: NSPoint) {
        rowView.isHidden = true
    }

    func draggingSession(_: NSDraggingSession, sourceOperationMaskFor _: NSDraggingContext) -> NSDragOperation {
        .copy
    }

    func draggingSession(_: NSDraggingSession, endedAt _: NSPoint, operation _: NSDragOperation) {
        rowView.isHidden = false
    }

    private func setup() {
        wantsLayer = true

        rowView.wantsLayer = true
        rowView.layer?.cornerRadius = 13
        rowView.layer?.borderWidth = 0.5
        rowView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(rowView)

        iconChrome.wantsLayer = true
        iconChrome.layer?.cornerRadius = 8
        iconChrome.translatesAutoresizingMaskIntoConstraints = false
        rowView.addSubview(iconChrome)

        let iconView = NSImageView(image: target.icon)
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.imageScaling = .scaleProportionallyUpOrDown
        iconChrome.addSubview(iconView)

        label.stringValue = target.fileName
        label.font = .systemFont(ofSize: 14, weight: .semibold)
        label.lineBreakMode = .byTruncatingTail
        label.textColor = NSColor.labelColor.withAlphaComponent(0.86)
        label.translatesAutoresizingMaskIntoConstraints = false
        rowView.addSubview(label)

        NSLayoutConstraint.activate([
            rowView.leadingAnchor.constraint(equalTo: leadingAnchor),
            rowView.trailingAnchor.constraint(equalTo: trailingAnchor),
            rowView.topAnchor.constraint(equalTo: topAnchor),
            rowView.bottomAnchor.constraint(equalTo: bottomAnchor),
            rowView.heightAnchor.constraint(equalToConstant: 48),

            iconChrome.leadingAnchor.constraint(equalTo: rowView.leadingAnchor, constant: 12),
            iconChrome.centerYAnchor.constraint(equalTo: rowView.centerYAnchor),
            iconChrome.widthAnchor.constraint(equalToConstant: 30),
            iconChrome.heightAnchor.constraint(equalToConstant: 30),

            iconView.centerXAnchor.constraint(equalTo: iconChrome.centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: iconChrome.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 24),
            iconView.heightAnchor.constraint(equalToConstant: 24),

            label.leadingAnchor.constraint(equalTo: iconChrome.trailingAnchor, constant: 12),
            label.trailingAnchor.constraint(lessThanOrEqualTo: rowView.trailingAnchor, constant: -16),
            label.centerYAnchor.constraint(equalTo: rowView.centerYAnchor),
        ])
    }

    private func updateAppearance() {
        let isDark = effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        iconChrome.layer?.backgroundColor = NSColor.white.withAlphaComponent(isDark ? 0.12 : 0.84).cgColor
        rowView.layer?.backgroundColor = NSColor.controlBackgroundColor.withAlphaComponent(isDark ? 0.54 : 0.74).cgColor
        rowView.layer?.borderColor = NSColor.separatorColor.withAlphaComponent(isDark ? 0.22 : 0.34).cgColor
    }

    private func rowFrameInSelf() -> NSRect {
        rowView.convert(rowView.bounds, to: self)
    }

    private func draggingImage() -> NSImage {
        let bounds = rowView.bounds
        guard let representation = rowView.bitmapImageRepForCachingDisplay(in: bounds) else {
            return target.icon
        }

        rowView.cacheDisplay(in: bounds, to: representation)
        let image = NSImage(size: bounds.size)
        image.addRepresentation(representation)
        return image
    }
}
