import AppKit

final class ToolbarPanel: NSPanel {
    var onSelect: ((RulerMode) -> Void)?
    var onClose: (() -> Void)?

    private let segmented: NSSegmentedControl

    init(mode: RulerMode) {
        let images = RulerMode.allCases.map {
            NSImage(systemSymbolName: $0.symbol, accessibilityDescription: $0.title) ?? NSImage()
        }
        segmented = NSSegmentedControl(images: images, trackingMode: .selectOne, target: nil, action: nil)
        segmented.segmentStyle = .separated
        segmented.controlSize = .large
        for m in RulerMode.allCases {
            segmented.setToolTip(m.title, forSegment: m.rawValue)
            segmented.setWidth(40, forSegment: m.rawValue)
        }
        segmented.selectedSegment = mode.rawValue

        let closeButton = NSButton(image: NSImage(systemSymbolName: "xmark", accessibilityDescription: "Sulje")!,
                                   target: nil, action: nil)
        closeButton.bezelStyle = .regularSquare
        closeButton.isBordered = false
        closeButton.toolTip = "Sulje (Esc)"
        closeButton.widthAnchor.constraint(equalToConstant: 32).isActive = true

        let divider = NSBox()
        divider.boxType = .separator

        let stack = NSStackView(views: [segmented, divider, closeButton])
        stack.orientation = .horizontal
        stack.spacing = 8
        stack.edgeInsets = NSEdgeInsets(top: 8, left: 10, bottom: 8, right: 8)
        stack.translatesAutoresizingMaskIntoConstraints = false

        let background = NSVisualEffectView()
        background.material = .hudWindow
        background.blendingMode = .behindWindow
        background.state = .active
        background.wantsLayer = true
        background.layer?.cornerRadius = 12
        background.layer?.masksToBounds = true
        background.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: background.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: background.trailingAnchor),
            stack.topAnchor.constraint(equalTo: background.topAnchor),
            stack.bottomAnchor.constraint(equalTo: background.bottomAnchor),
            divider.heightAnchor.constraint(equalToConstant: 22),
        ])

        let size = stack.fittingSize
        super.init(contentRect: NSRect(origin: .zero, size: size),
                   styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        contentView = background
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        level = NSWindow.Level(rawValue: NSWindow.Level.screenSaver.rawValue + 1)
        isMovableByWindowBackground = true
        becomesKeyOnlyIfNeeded = true
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]

        segmented.target = self
        segmented.action = #selector(segmentChanged)
        closeButton.target = self
        closeButton.action = #selector(closeClicked)
    }

    override var canBecomeKey: Bool { false }

    func select(_ mode: RulerMode) {
        segmented.selectedSegment = mode.rawValue
    }

    @objc private func segmentChanged() {
        if let mode = RulerMode(rawValue: segmented.selectedSegment) { onSelect?(mode) }
    }

    @objc private func closeClicked() {
        onClose?()
    }
}
