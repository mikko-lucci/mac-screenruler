import AppKit

/// Owns the overlay windows (one per screen) and the toolbar while the ruler is active.
final class RulerController {
    private var overlays: [OverlayWindow] = []
    private var toolbar: ToolbarPanel?
    private var captureTimer: Timer?
    private var isStarting = false
    private var isCapturing = false

    var isActive: Bool { !overlays.isEmpty }

    private var mode: RulerMode = Prefs.lastMode {
        didSet {
            Prefs.lastMode = mode
            overlays.forEach { $0.rulerView.mode = mode }
            toolbar?.select(mode)
        }
    }

    func toggle() {
        isActive ? stop() : start()
    }

    func start() {
        guard !isActive, !isStarting else { return }
        isStarting = true
        Task { @MainActor in
            let snapshots = await ScreenCapture.capture()
            self.isStarting = false
            self.present(snapshots)
        }
    }

    func stop() {
        captureTimer?.invalidate()
        captureTimer = nil
        overlays.forEach { $0.orderOut(nil) }
        overlays.removeAll()
        toolbar?.orderOut(nil)
        toolbar = nil
        NSCursor.arrow.set()
        NSApp.hide(nil)
    }

    private func present(_ snapshots: [CGDirectDisplayID: PixelBuffer]) {
        let settings = RulerSettings.current()
        mode = Prefs.lastMode

        for screen in NSScreen.screens {
            let window = OverlayWindow(screen: screen)
            let view = window.rulerView
            view.displayID = screen.displayID
            view.settings = settings
            view.mode = mode
            view.pixels = snapshots[screen.displayID]
            view.onClose = { [weak self] in self?.stop() }
            view.onModeChange = { [weak self] in self?.mode = $0 }
            window.orderFrontRegardless()
            overlays.append(window)
        }

        let mouse = NSEvent.mouseLocation
        let activeScreen = NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) } ?? NSScreen.main ?? NSScreen.screens[0]

        let panel = ToolbarPanel(mode: mode)
        panel.onSelect = { [weak self] in self?.mode = $0 }
        panel.onClose = { [weak self] in self?.stop() }
        let visible = activeScreen.visibleFrame
        panel.setFrameOrigin(NSPoint(x: visible.midX - panel.frame.width / 2,
                                     y: visible.maxY - panel.frame.height - 12))
        panel.orderFrontRegardless()
        toolbar = panel

        NSApp.activate(ignoringOtherApps: true)
        if let window = overlays.first(where: { $0.screen == activeScreen }) ?? overlays.first {
            window.makeKey()
            window.makeFirstResponder(window.rulerView)
        }

        if settings.continuous {
            captureTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true) { [weak self] _ in
                self?.recaptureScreenUnderMouse()
            }
        }
    }

    private func recaptureScreenUnderMouse() {
        guard !isCapturing else { return }
        let mouse = NSEvent.mouseLocation
        guard let window = overlays.first(where: { NSMouseInRect(mouse, $0.frame, false) }) else { return }
        let id = window.rulerView.displayID
        isCapturing = true
        Task { @MainActor in
            let snapshots = await ScreenCapture.capture(only: [id])
            self.isCapturing = false
            if self.isActive, let buffer = snapshots[id] {
                window.rulerView.pixels = buffer
            }
        }
    }
}
