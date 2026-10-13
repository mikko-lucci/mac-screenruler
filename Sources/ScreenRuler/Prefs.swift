import AppKit

enum RulerMode: Int, CaseIterable {
    case bounds, spacing, horizontal, vertical

    var title: String {
        switch self {
        case .bounds: return "Rajat (1)"
        case .spacing: return "Välit (2)"
        case .horizontal: return "Vaakasuora väli (3)"
        case .vertical: return "Pystysuora väli (4)"
        }
    }

    var symbol: String {
        switch self {
        case .bounds: return "rectangle.dashed"
        case .spacing: return "arrow.up.and.down.and.arrow.left.and.right"
        case .horizontal: return "arrow.left.and.right"
        case .vertical: return "arrow.up.and.down"
        }
    }
}

enum MeasureUnit: String, CaseIterable, Identifiable {
    case pixels, points, inches, centimeters, millimeters

    var id: String { rawValue }

    var title: String {
        switch self {
        case .pixels: return "Pikselit (px)"
        case .points: return "Pisteet (pt)"
        case .inches: return "Tuumat (in)"
        case .centimeters: return "Senttimetrit (cm)"
        case .millimeters: return "Millimetrit (mm)"
        }
    }

    var suffix: String {
        switch self {
        case .pixels: return "px"
        case .points: return "pt"
        case .inches: return "in"
        case .centimeters: return "cm"
        case .millimeters: return "mm"
        }
    }
}

enum Prefs {
    static let unitKey = "unit"
    static let toleranceKey = "pixelTolerance"
    static let perChannelKey = "perChannelEdgeDetection"
    static let continuousKey = "continuousCapture"
    static let lineColorKey = "lineColor"
    static let lastModeKey = "lastMode"

    static func registerDefaults() {
        UserDefaults.standard.register(defaults: [
            unitKey: MeasureUnit.pixels.rawValue,
            toleranceKey: 30.0,
            perChannelKey: false,
            continuousKey: false,
            lineColorKey: "#FF4F00",
            lastModeKey: RulerMode.spacing.rawValue,
        ])
    }

    static var lastMode: RulerMode {
        get { RulerMode(rawValue: UserDefaults.standard.integer(forKey: lastModeKey)) ?? .spacing }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: lastModeKey) }
    }
}

/// Snapshot of the settings, taken each time the ruler is launched.
struct RulerSettings {
    var unit: MeasureUnit
    var tolerance: Int
    var perChannel: Bool
    var continuous: Bool
    var lineColor: NSColor

    static func current() -> RulerSettings {
        let d = UserDefaults.standard
        return RulerSettings(
            unit: MeasureUnit(rawValue: d.string(forKey: Prefs.unitKey) ?? "") ?? .pixels,
            tolerance: Int(d.double(forKey: Prefs.toleranceKey)),
            perChannel: d.bool(forKey: Prefs.perChannelKey),
            continuous: d.bool(forKey: Prefs.continuousKey),
            lineColor: NSColor(hex: d.string(forKey: Prefs.lineColorKey) ?? "") ?? .systemOrange
        )
    }
}

extension NSColor {
    convenience init?(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespaces)
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6, let v = UInt32(s, radix: 16) else { return nil }
        self.init(srgbRed: CGFloat((v >> 16) & 0xFF) / 255,
                  green: CGFloat((v >> 8) & 0xFF) / 255,
                  blue: CGFloat(v & 0xFF) / 255,
                  alpha: 1)
    }

    var hexString: String {
        guard let c = usingColorSpace(.sRGB) else { return "#FF4F00" }
        return String(format: "#%02X%02X%02X",
                      Int((c.redComponent * 255).rounded()),
                      Int((c.greenComponent * 255).rounded()),
                      Int((c.blueComponent * 255).rounded()))
    }
}
