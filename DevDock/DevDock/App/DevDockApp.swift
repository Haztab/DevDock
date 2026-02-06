import SwiftUI

@main
struct DevDockApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .defaultPosition(.trailing)
        .commands {
            // Custom menu commands
            CommandGroup(replacing: .newItem) { }

            CommandMenu("Actions") {
                Button("Run") {
                    NotificationCenter.default.post(name: .runAction, object: nil)
                }
                .keyboardShortcut("r", modifiers: .command)

                Button("Stop") {
                    NotificationCenter.default.post(name: .stopAction, object: nil)
                }
                .keyboardShortcut(".", modifiers: .command)

                Divider()

                Button("Hot Reload") {
                    NotificationCenter.default.post(name: .hotReloadAction, object: nil)
                }
                .keyboardShortcut("r", modifiers: [.command, .shift])

                Button("Hot Restart") {
                    NotificationCenter.default.post(name: .hotRestartAction, object: nil)
                }
                .keyboardShortcut("R", modifiers: [.command, .shift, .option])

                Divider()

                Button("Refresh Devices") {
                    NotificationCenter.default.post(name: .refreshDevicesAction, object: nil)
                }
                .keyboardShortcut("d", modifiers: [.command, .shift])
            }

            CommandMenu("Logs") {
                Button("Clear Logs") {
                    NotificationCenter.default.post(name: .clearLogsAction, object: nil)
                }
                .keyboardShortcut("k", modifiers: .command)

                Button("Export Logs...") {
                    NotificationCenter.default.post(name: .exportLogsAction, object: nil)
                }
                .keyboardShortcut("e", modifiers: [.command, .shift])

                Divider()

                Button("Toggle Auto-Scroll") {
                    NotificationCenter.default.post(name: .toggleAutoScrollAction, object: nil)
                }
                .keyboardShortcut("s", modifiers: [.command, .option])
            }
        }

        Settings {
            SettingsView()
        }
    }
}

// MARK: - App Delegate

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Configure main window
        if let window = NSApplication.shared.windows.first {
            configureWindow(window)
        }

        // Setup menu bar item (optional)
        setupStatusBarItem()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }

    private func configureWindow(_ window: NSWindow) {
        // Floating panel behavior
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        // Visual appearance
        window.isOpaque = false
        window.backgroundColor = .clear
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden

        // Remove standard window buttons
        window.standardWindowButton(.closeButton)?.isHidden = false
        window.standardWindowButton(.miniaturizeButton)?.isHidden = true
        window.standardWindowButton(.zoomButton)?.isHidden = true

        // Position on right side of screen
        positionWindowOnRight(window)
    }

    private func positionWindowOnRight(_ window: NSWindow) {
        guard let screen = NSScreen.main else { return }

        let screenFrame = screen.visibleFrame
        let windowFrame = window.frame

        let newOriginX = screenFrame.maxX - windowFrame.width - 20
        let newOriginY = screenFrame.midY - (windowFrame.height / 2)

        window.setFrameOrigin(NSPoint(x: newOriginX, y: newOriginY))
    }

    private func setupStatusBarItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "iphone.and.arrow.forward", accessibilityDescription: "DevDock")
            button.action = #selector(toggleWindow)
            button.target = self
        }
    }

    @objc private func toggleWindow() {
        if let window = NSApplication.shared.windows.first {
            if window.isVisible {
                window.orderOut(nil)
            } else {
                window.makeKeyAndOrderFront(nil)
                NSApplication.shared.activate(ignoringOtherApps: true)
            }
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let runAction = Notification.Name("runAction")
    static let stopAction = Notification.Name("stopAction")
    static let hotReloadAction = Notification.Name("hotReloadAction")
    static let hotRestartAction = Notification.Name("hotRestartAction")
    static let refreshDevicesAction = Notification.Name("refreshDevicesAction")
    static let clearLogsAction = Notification.Name("clearLogsAction")
    static let exportLogsAction = Notification.Name("exportLogsAction")
    static let toggleAutoScrollAction = Notification.Name("toggleAutoScrollAction")
}
