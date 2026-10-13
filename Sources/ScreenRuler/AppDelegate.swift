import AppKit
import Carbon.HIToolbox
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var hotKey: HotKey?
    private let ruler = RulerController()
    private var settingsWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(systemSymbolName: "ruler", accessibilityDescription: "ScreenRuler")

        let menu = NSMenu()
        let launch = NSMenuItem(title: "Käynnistä Screen Ruler", action: #selector(toggleRuler), keyEquivalent: "m")
        launch.keyEquivalentModifierMask = [.command, .shift]
        launch.target = self
        menu.addItem(launch)
        menu.addItem(.separator())
        let settings = NSMenuItem(title: "Asetukset…", action: #selector(showSettings), keyEquivalent: ",")
        settings.target = self
        menu.addItem(settings)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Lopeta ScreenRuler", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem.menu = menu

        hotKey = HotKey(keyCode: UInt32(kVK_ANSI_M), modifiers: UInt32(cmdKey | shiftKey)) { [weak self] in
            self?.toggleRuler()
        }

        if !ScreenCapture.hasPermission {
            ScreenCapture.requestPermission()
            showSettings()
        }
    }

    /// Opening the app again (Finder, Spotlight, Dock) launches the ruler.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        ruler.start()
        return false
    }

    @objc private func toggleRuler() {
        ruler.toggle()
    }

    @objc private func showSettings() {
        if settingsWindow == nil {
            let window = NSWindow(contentViewController: NSHostingController(rootView: SettingsView(onStartRuler: { [weak self] in
                self?.settingsWindow?.close()
                self?.ruler.start()
            })))
            window.title = "ScreenRuler – asetukset"
            window.styleMask = [.titled, .closable]
            window.isReleasedWhenClosed = false
            window.center()
            settingsWindow = window
        }
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
    }
}
