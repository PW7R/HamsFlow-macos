import AppKit
import SwiftUI

/// Dedicated window manager for HamsFlow Settings.
/// Bypasses fragile responder-chain actions by directly managing an NSWindow,
/// guaranteeing that "Settings…" opens every single time from any thread or context.
@MainActor
final class SettingsWindowManager: NSObject, NSWindowDelegate {
    static let shared = SettingsWindowManager()

    private var window: NSWindow?

    func show(controller: DictationController) {
        if let existing = window {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let contentView = ModernSettingsView(controller: controller)
        let hostingView = NSHostingView(rootView: contentView)

        let win = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 580, height: 640),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        win.title = "HamsFlow Settings"
        win.center()
        win.isReleasedWhenClosed = false
        win.delegate = self
        win.contentView = hostingView
        win.backgroundColor = NSColor(red: 0.035, green: 0.035, blue: 0.043, alpha: 1.0)
        win.titlebarAppearsTransparent = true

        self.window = win
        win.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func windowWillClose(_ notification: Notification) {
        window = nil
    }
}
