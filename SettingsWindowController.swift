import AppKit
import SwiftUI

@MainActor
enum SettingsWindowController {
    private static var window: NSWindow?

    static func show(viewModel: AppViewModel) {
        if let existing = window, existing.isVisible {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let settingsView = SettingsView(viewModel: viewModel)
        let hostingView = NSHostingView(rootView: settingsView)
        hostingView.frame = NSRect(origin: .zero, size: SettingsView.windowSize)

        let newWindow = NSWindow(
            contentRect: hostingView.frame,
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        newWindow.title = "ActionBar Settings"
        newWindow.contentView = hostingView
        newWindow.center()
        newWindow.isReleasedWhenClosed = false
        newWindow.makeKeyAndOrderFront(nil)

        NSApp.activate(ignoringOtherApps: true)

        window = newWindow
    }
}
