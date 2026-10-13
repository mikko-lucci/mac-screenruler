import AppKit
import ScreenCaptureKit

enum ScreenCapture {
    static var hasPermission: Bool { CGPreflightScreenCaptureAccess() }

    static func requestPermission() {
        CGRequestScreenCaptureAccess()
    }

    /// Captures the given displays (all when nil) at native pixel resolution,
    /// excluding ScreenRuler's own windows.
    static func capture(only displayIDs: Set<CGDirectDisplayID>? = nil) async -> [CGDirectDisplayID: PixelBuffer] {
        do {
            let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
            let pid = ProcessInfo.processInfo.processIdentifier
            let ownApps = content.applications.filter { $0.processID == pid }

            var result: [CGDirectDisplayID: PixelBuffer] = [:]
            for display in content.displays where displayIDs?.contains(display.displayID) ?? true {
                let filter = SCContentFilter(display: display, excludingApplications: ownApps, exceptingWindows: [])
                let config = SCStreamConfiguration()
                let scale = CGFloat(filter.pointPixelScale)
                config.width = Int((filter.contentRect.width * scale).rounded())
                config.height = Int((filter.contentRect.height * scale).rounded())
                config.showsCursor = false
                config.captureResolution = .best

                let image = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
                if let buffer = PixelBuffer(image: image) {
                    result[display.displayID] = buffer
                }
            }
            return result
        } catch {
            NSLog("ScreenRuler: screen capture failed: \(error)")
            return [:]
        }
    }
}

extension NSScreen {
    var displayID: CGDirectDisplayID {
        (deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value ?? 0
    }
}
