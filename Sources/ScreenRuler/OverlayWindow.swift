import AppKit

final class OverlayWindow: NSWindow {
    let rulerView: RulerView

    init(screen: NSScreen) {
        rulerView = RulerView(frame: NSRect(origin: .zero, size: screen.frame.size))
        super.init(contentRect: screen.frame, styleMask: .borderless, backing: .buffered, defer: false)
        setFrame(screen.frame, display: false)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        level = .screenSaver
        ignoresMouseEvents = false
        acceptsMouseMovedEvents = true
        isReleasedWhenClosed = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        contentView = rulerView
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}
