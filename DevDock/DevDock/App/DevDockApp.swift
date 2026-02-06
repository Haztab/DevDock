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
        .defaultPosition(.leading)
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

            CommandMenu("Window") {
                Button("Toggle Log Viewer") {
                    NotificationCenter.default.post(name: .toggleLogViewerAction, object: nil)
                }
                .keyboardShortcut("l", modifiers: .command)

                Button("Toggle Make Commands") {
                    NotificationCenter.default.post(name: .toggleMakeCommandsAction, object: nil)
                }
                .keyboardShortcut("m", modifiers: .command)

                Divider()

                Button("Always on Top") {
                    NotificationCenter.default.post(name: .toggleFloatingAction, object: nil)
                }
                .keyboardShortcut("t", modifiers: [.command, .option])
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

    /// Key for storing floating preference
    private let floatingPreferenceKey = "DevDock.alwaysOnTop"

    /// Whether window should float on top
    var isFloating: Bool {
        get { UserDefaults.standard.bool(forKey: floatingPreferenceKey) }
        set { UserDefaults.standard.set(newValue, forKey: floatingPreferenceKey) }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Set default value for floating (true by default)
        if UserDefaults.standard.object(forKey: floatingPreferenceKey) == nil {
            UserDefaults.standard.set(true, forKey: floatingPreferenceKey)
        }

        // Configure main window
        if let window = NSApplication.shared.windows.first {
            configureWindow(window)
        }

        // Setup menu bar item (optional)
        setupStatusBarItem()

        // Listen for toggle floating action
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(toggleFloating),
            name: .toggleFloatingAction,
            object: nil
        )
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }

    private func configureWindow(_ window: NSWindow) {
        // Set floating based on preference
        updateWindowLevel(window)
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        // Visual appearance
        window.isOpaque = false
        window.backgroundColor = .clear
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden

        // Show standard window buttons (including minimize)
        window.standardWindowButton(.closeButton)?.isHidden = false
        window.standardWindowButton(.miniaturizeButton)?.isHidden = false
        window.standardWindowButton(.zoomButton)?.isHidden = true

        // Position on left side of screen
        positionWindowOnLeft(window)
    }

    private func updateWindowLevel(_ window: NSWindow) {
        window.level = isFloating ? .floating : .normal
    }

    @objc private func toggleFloating() {
        isFloating.toggle()

        // Update all windows
        for window in NSApplication.shared.windows {
            updateWindowLevel(window)
        }
    }

    private func positionWindowOnLeft(_ window: NSWindow) {
        guard let screen = NSScreen.main else { return }

        let screenFrame = screen.visibleFrame
        let windowFrame = window.frame

        let newOriginX = screenFrame.minX + 20
        let newOriginY = screenFrame.midY - (windowFrame.height / 2)

        window.setFrameOrigin(NSPoint(x: newOriginX, y: newOriginY))
    }

    private func setupStatusBarItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "iphone.and.arrow.forward", accessibilityDescription: "DevDock")
            button.action = #selector(statusBarClicked)
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
    }

    @objc private func statusBarClicked(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else { return }

        if event.type == .rightMouseUp {
            // Show context menu on right click
            let menu = NSMenu()
            menu.addItem(NSMenuItem(title: isFloating ? "Disable Always on Top" : "Enable Always on Top",
                                    action: #selector(toggleFloating), keyEquivalent: ""))
            menu.addItem(NSMenuItem.separator())
            menu.addItem(NSMenuItem(title: "Quit DevDock", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))

            statusItem?.menu = menu
            statusItem?.button?.performClick(nil)
            statusItem?.menu = nil
        } else {
            // Toggle window on left click
            toggleWindow()
        }
    }

    @objc private func toggleWindow() {
        if let window = NSApplication.shared.windows.first(where: { $0.title != "DevDock Logs" }) {
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
    static let toggleLogViewerAction = Notification.Name("toggleLogViewerAction")
    static let toggleMakeCommandsAction = Notification.Name("toggleMakeCommandsAction")
    static let toggleFloatingAction = Notification.Name("toggleFloatingAction")
}
