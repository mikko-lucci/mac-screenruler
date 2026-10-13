import AppKit
import Carbon.HIToolbox

/// A measurement in screen pixels. Coordinates are inclusive, origin top-left.
struct Measurement {
    var mode: RulerMode
    var x0: Int, y0: Int, x1: Int, y1: Int
    var cursor: PixelPoint

    var width: Int { x1 - x0 + 1 }
    var height: Int { y1 - y0 + 1 }

    static func bounds(_ a: PixelPoint, _ b: PixelPoint) -> Measurement {
        Measurement(mode: .bounds, x0: min(a.x, b.x), y0: min(a.y, b.y),
                    x1: max(a.x, b.x), y1: max(a.y, b.y), cursor: b)
    }
}

final class RulerView: NSView {
    var mode: RulerMode = .spacing {
        didSet {
            dragStart = nil
            lastBounds = nil
            recompute()
            needsDisplay = true
        }
    }
    var pixels: PixelBuffer? {
        didSet {
            recompute()
            needsDisplay = true
        }
    }
    var displayID: CGDirectDisplayID = 0
    var settings = RulerSettings.current()
    var onClose: (() -> Void)?
    var onModeChange: ((RulerMode) -> Void)?

    private var cursor: PixelPoint?
    private var dragStart: PixelPoint?
    private var live: Measurement?
    private var lastBounds: Measurement?
    private var kept: [Measurement] = []
    private var toast: String?
    private var toastWork: DispatchWorkItem?

    override var isFlipped: Bool { true }
    override var acceptsFirstResponder: Bool { true }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    // MARK: - Geometry

    /// Screen pixels per view point.
    private var scale: CGFloat {
        if let pixels, bounds.width > 0 { return CGFloat(pixels.width) / bounds.width }
        return window?.backingScaleFactor ?? 2
    }

    private var pixelWidth: Int { pixels?.width ?? Int(bounds.width * scale) }
    private var pixelHeight: Int { pixels?.height ?? Int(bounds.height * scale) }

    /// Physical pixels per millimetre, used for inch / cm / mm units.
    private var pixelsPerMM: CGFloat {
        let mm = CGDisplayScreenSize(displayID).width
        if mm > 0 { return CGFloat(pixelWidth) / mm }
        return scale * 72 / 25.4
    }

    private func pt(_ px: Int) -> CGFloat { CGFloat(px) / scale }

    private func pixelPoint(_ event: NSEvent) -> PixelPoint {
        let p = convert(event.locationInWindow, from: nil)
        return PixelPoint(x: min(max(Int((p.x * scale).rounded(.down)), 0), pixelWidth - 1),
                          y: min(max(Int((p.y * scale).rounded(.down)), 0), pixelHeight - 1))
    }

    // MARK: - Measuring

    private func recompute() {
        guard let cursor else {
            live = nil
            return
        }
        switch mode {
        case .bounds:
            live = dragStart.map { Measurement.bounds($0, cursor) }
        case .spacing, .horizontal, .vertical:
            guard let pixels else {
                live = nil
                return
            }
            let tol = settings.tolerance, pc = settings.perChannel
            var m = Measurement(mode: mode, x0: cursor.x, y0: cursor.y, x1: cursor.x, y1: cursor.y, cursor: cursor)
            if mode != .vertical {
                m.x0 = pixels.edge(from: cursor, dx: -1, dy: 0, tolerance: tol, perChannel: pc)
                m.x1 = pixels.edge(from: cursor, dx: 1, dy: 0, tolerance: tol, perChannel: pc)
            }
            if mode != .horizontal {
                m.y0 = pixels.edge(from: cursor, dx: 0, dy: -1, tolerance: tol, perChannel: pc)
                m.y1 = pixels.edge(from: cursor, dx: 0, dy: 1, tolerance: tol, perChannel: pc)
            }
            live = m
        }
    }

    private func format(_ px: Int) -> String {
        let v = CGFloat(px)
        switch settings.unit {
        case .pixels: return "\(px)"
        case .points:
            let p = v / scale
            return p == p.rounded() ? "\(Int(p))" : String(format: "%.1f", p)
        case .inches: return String(format: "%.2f", v / pixelsPerMM / 25.4)
        case .centimeters: return String(format: "%.2f", v / pixelsPerMM / 10)
        case .millimeters: return String(format: "%.1f", v / pixelsPerMM)
        }
    }

    private func text(for m: Measurement) -> String {
        let unit = settings.unit.suffix
        switch m.mode {
        case .bounds, .spacing: return "\(format(m.width)) × \(format(m.height)) \(unit)"
        case .horizontal: return "\(format(m.width)) \(unit)"
        case .vertical: return "\(format(m.height)) \(unit)"
        }
    }

    private func copy(_ m: Measurement) {
        let s = text(for: m)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(s, forType: .string)
        showToast("Kopioitu: \(s)")
    }

    private func showToast(_ message: String) {
        toast = message
        toastWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.toast = nil
            self?.needsDisplay = true
        }
        toastWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2, execute: work)
        needsDisplay = true
    }

    private func clearKept() {
        kept.removeAll()
        lastBounds = nil
        needsDisplay = true
    }

    // MARK: - Mouse

    override func updateTrackingAreas() {
        trackingAreas.forEach(removeTrackingArea)
        addTrackingArea(NSTrackingArea(rect: .zero,
                                       options: [.mouseMoved, .mouseEnteredAndExited, .cursorUpdate, .activeAlways, .inVisibleRect],
                                       owner: self))
        super.updateTrackingAreas()
    }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .crosshair)
    }

    override func cursorUpdate(with event: NSEvent) {
        NSCursor.crosshair.set()
    }

    override func mouseEntered(with event: NSEvent) {
        window?.makeKey()
        window?.makeFirstResponder(self)
        NSCursor.crosshair.set()
    }

    override func mouseExited(with event: NSEvent) {
        guard dragStart == nil else { return }
        cursor = nil
        live = nil
        needsDisplay = true
    }

    override func mouseMoved(with event: NSEvent) {
        NSCursor.crosshair.set()
        cursor = pixelPoint(event)
        recompute()
        needsDisplay = true
    }

    override func mouseDown(with event: NSEvent) {
        let p = pixelPoint(event)
        cursor = p
        if mode == .bounds {
            if !event.modifierFlags.contains(.shift) { lastBounds = nil }
            dragStart = p
            recompute()
        } else {
            recompute()
            if let m = live {
                if event.modifierFlags.contains(.shift) { kept.append(m) }
                copy(m)
            }
        }
        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        cursor = pixelPoint(event)
        recompute()
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        guard mode == .bounds, dragStart != nil else { return }
        cursor = pixelPoint(event)
        recompute()
        if let m = live {
            if event.modifierFlags.contains(.shift) { kept.append(m) } else { lastBounds = m }
            copy(m)
        }
        dragStart = nil
        live = nil
        needsDisplay = true
    }

    override func rightMouseDown(with event: NSEvent) {
        clearKept()
    }

    // MARK: - Keyboard

    override func keyDown(with event: NSEvent) {
        switch Int(event.keyCode) {
        case kVK_Escape:
            onClose?()
        case kVK_ANSI_1: onModeChange?(.bounds)
        case kVK_ANSI_2: onModeChange?(.spacing)
        case kVK_ANSI_3: onModeChange?(.horizontal)
        case kVK_ANSI_4: onModeChange?(.vertical)
        case kVK_Delete, kVK_ForwardDelete:
            clearKept()
        case kVK_LeftArrow: nudge(dx: -1, dy: 0)
        case kVK_RightArrow: nudge(dx: 1, dy: 0)
        case kVK_UpArrow: nudge(dx: 0, dy: -1)
        case kVK_DownArrow: nudge(dx: 0, dy: 1)
        case kVK_ANSI_C where event.modifierFlags.contains(.command):
            if let m = live ?? lastBounds { copy(m) }
        default:
            super.keyDown(with: event)
        }
    }

    /// Moves the mouse cursor by whole screen pixels (Shift = 10 px).
    private func nudge(dx: Int, dy: Int) {
        guard var p = cursor, let window, let primary = NSScreen.screens.first else { return }
        let step = NSEvent.modifierFlags.contains(.shift) ? 10 : 1
        p.x = min(max(p.x + dx * step, 0), pixelWidth - 1)
        p.y = min(max(p.y + dy * step, 0), pixelHeight - 1)
        cursor = p

        let local = NSPoint(x: (CGFloat(p.x) + 0.5) / scale, y: (CGFloat(p.y) + 0.5) / scale)
        let screenPoint = window.convertPoint(toScreen: convert(local, to: nil))
        CGWarpMouseCursorPosition(CGPoint(x: screenPoint.x, y: primary.frame.height - screenPoint.y))
        CGAssociateMouseAndMouseCursorPosition(1)

        recompute()
        needsDisplay = true
    }

    // MARK: - Drawing

    override func draw(_ dirtyRect: NSRect) {
        // Nearly invisible fill so the transparent window still receives clicks everywhere.
        NSColor.black.withAlphaComponent(0.01).setFill()
        bounds.fill(using: .copy)

        let color = settings.lineColor
        for m in kept {
            draw(m, color: color)
            drawLabel(text(for: m), near: labelAnchor(for: m))
        }
        if let m = lastBounds {
            draw(m, color: color)
            drawLabel(text(for: m), near: labelAnchor(for: m))
        }
        if let m = live {
            draw(m, color: color)
            if let cursor {
                drawLabel(text(for: m), near: NSPoint(x: pt(cursor.x), y: pt(cursor.y)), offset: true)
            }
        }
        if pixels == nil, mode != .bounds {
            drawBanner("Näytön tallennuslupa puuttuu, joten reunantunnistus ei toimi. Salli ScreenRuler kohdassa Järjestelmäasetukset → Tietosuoja ja suojaus → Näytön ja äänen tallennus ja käynnistä sovellus uudelleen. Rajat-tila (1) toimii ilman lupaa.")
        }
        if let toast {
            drawToast(toast)
        }
    }

    private func labelAnchor(for m: Measurement) -> NSPoint {
        if m.mode == .bounds {
            return NSPoint(x: pt(m.x0) + (pt(m.x1 + 1) - pt(m.x0)) / 2, y: pt(m.y0) + (pt(m.y1 + 1) - pt(m.y0)) / 2)
        }
        return NSPoint(x: pt(m.cursor.x), y: pt(m.cursor.y))
    }

    private func draw(_ m: Measurement, color: NSColor) {
        let line: CGFloat = 1
        let tick: CGFloat = 5
        color.setStroke()

        func segment(_ a: NSPoint, _ b: NSPoint) {
            let path = NSBezierPath()
            path.move(to: a)
            path.line(to: b)
            path.lineWidth = line
            path.stroke()
        }

        switch m.mode {
        case .bounds:
            let rect = NSRect(x: pt(m.x0), y: pt(m.y0), width: pt(m.x1 + 1) - pt(m.x0), height: pt(m.y1 + 1) - pt(m.y0))
            color.withAlphaComponent(0.15).setFill()
            rect.fill(using: .sourceOver)
            let path = NSBezierPath(rect: rect.insetBy(dx: line / 2, dy: line / 2))
            path.lineWidth = line
            path.stroke()
        case .spacing, .horizontal, .vertical:
            if m.mode != .vertical {
                let y = (CGFloat(m.cursor.y) + 0.5) / scale
                let left = pt(m.x0), right = pt(m.x1 + 1)
                segment(NSPoint(x: left, y: y), NSPoint(x: right, y: y))
                segment(NSPoint(x: left + line / 2, y: y - tick), NSPoint(x: left + line / 2, y: y + tick))
                segment(NSPoint(x: right - line / 2, y: y - tick), NSPoint(x: right - line / 2, y: y + tick))
            }
            if m.mode != .horizontal {
                let x = (CGFloat(m.cursor.x) + 0.5) / scale
                let top = pt(m.y0), bottom = pt(m.y1 + 1)
                segment(NSPoint(x: x, y: top), NSPoint(x: x, y: bottom))
                segment(NSPoint(x: x - tick, y: top + line / 2), NSPoint(x: x + tick, y: top + line / 2))
                segment(NSPoint(x: x - tick, y: bottom - line / 2), NSPoint(x: x + tick, y: bottom - line / 2))
            }
        }
    }

    private static let labelAttributes: [NSAttributedString.Key: Any] = [
        .font: NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .semibold),
        .foregroundColor: NSColor.white,
    ]

    /// Draws a pill-shaped label. With `offset`, it sits beside the point (flipping
    /// to the other side near screen edges); otherwise it is centred on the point.
    private func drawLabel(_ text: String, near p: NSPoint, offset: Bool = false) {
        let size = (text as NSString).size(withAttributes: Self.labelAttributes)
        var r = NSRect(x: 0, y: 0, width: ceil(size.width) + 14, height: ceil(size.height) + 8)
        if offset {
            let gap: CGFloat = 16
            r.origin = NSPoint(x: p.x + gap, y: p.y + gap)
            if r.maxX > bounds.maxX - 4 { r.origin.x = p.x - gap - r.width }
            if r.maxY > bounds.maxY - 4 { r.origin.y = p.y - gap - r.height }
        } else {
            r.origin = NSPoint(x: p.x - r.width / 2, y: p.y - r.height / 2)
        }
        r.origin.x = min(max(r.origin.x, 4), bounds.maxX - r.width - 4)
        r.origin.y = min(max(r.origin.y, 4), bounds.maxY - r.height - 4)

        NSColor(white: 0.08, alpha: 0.85).setFill()
        NSBezierPath(roundedRect: r, xRadius: 6, yRadius: 6).fill()
        (text as NSString).draw(at: NSPoint(x: r.minX + 7, y: r.minY + 4), withAttributes: Self.labelAttributes)
    }

    private func drawBanner(_ text: String) {
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 14, weight: .medium),
            .foregroundColor: NSColor.white,
        ]
        let maxWidth = min(720, bounds.width - 40)
        let textRect = (text as NSString).boundingRect(with: NSSize(width: maxWidth, height: 400),
                                                       options: [.usesLineFragmentOrigin], attributes: attrs)
        let r = NSRect(x: bounds.midX - (ceil(textRect.width) + 32) / 2, y: 90,
                       width: ceil(textRect.width) + 32, height: ceil(textRect.height) + 24)
        NSColor(srgbRed: 0.75, green: 0.2, blue: 0.1, alpha: 0.95).setFill()
        NSBezierPath(roundedRect: r, xRadius: 10, yRadius: 10).fill()
        (text as NSString).draw(with: r.insetBy(dx: 16, dy: 12), options: [.usesLineFragmentOrigin], attributes: attrs)
    }

    private func drawToast(_ text: String) {
        let size = (text as NSString).size(withAttributes: Self.labelAttributes)
        let r = NSRect(x: bounds.midX - (size.width + 28) / 2, y: bounds.maxY - 90,
                       width: ceil(size.width) + 28, height: ceil(size.height) + 14)
        settings.lineColor.withAlphaComponent(0.95).setFill()
        NSBezierPath(roundedRect: r, xRadius: r.height / 2, yRadius: r.height / 2).fill()
        (text as NSString).draw(at: NSPoint(x: r.minX + 14, y: r.minY + 7), withAttributes: Self.labelAttributes)
    }
}
