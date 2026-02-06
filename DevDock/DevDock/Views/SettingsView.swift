import SwiftUI

/// Settings window view
struct SettingsView: View {
    @AppStorage("alwaysOnTop") private var alwaysOnTop = true
    @AppStorage("showInDock") private var showInDock = true
    @AppStorage("maxLogEntries") private var maxLogEntries = 5000
    @AppStorage("autoRefreshDevices") private var autoRefreshDevices = true

    var body: some View {
        TabView {
            GeneralSettingsView(
                alwaysOnTop: $alwaysOnTop,
                showInDock: $showInDock
            )
            .tabItem {
                Label("General", systemImage: "gear")
            }

            LogSettingsView(maxLogEntries: $maxLogEntries)
                .tabItem {
                    Label("Logs", systemImage: "text.alignleft")
                }

            ToolsSettingsView(autoRefreshDevices: $autoRefreshDevices)
                .tabItem {
                    Label("Tools", systemImage: "wrench.and.screwdriver")
                }
        }
        .frame(width: 400, height: 250)
        .padding()
    }
}

// MARK: - General Settings

struct GeneralSettingsView: View {
    @Binding var alwaysOnTop: Bool
    @Binding var showInDock: Bool

    var body: some View {
        Form {
            Section {
                Toggle("Always on top", isOn: $alwaysOnTop)
                    .help("Keep DevDock window above other windows")

                Toggle("Show in Dock", isOn: $showInDock)
                    .help("Show DevDock icon in the Dock")
            }

            Section("Window Position") {
                HStack {
                    Button("Stick to Left") {
                        positionWindow(.left)
                    }
                    Button("Stick to Right") {
                        positionWindow(.right)
                    }
                    Button("Center") {
                        positionWindow(.center)
                    }
                }
            }
        }
        .formStyle(.grouped)
    }

    private func positionWindow(_ position: WindowPosition) {
        guard let window = NSApplication.shared.windows.first,
              let screen = NSScreen.main else { return }

        let screenFrame = screen.visibleFrame
        let windowFrame = window.frame

        let newOrigin: NSPoint
        switch position {
        case .left:
            newOrigin = NSPoint(
                x: screenFrame.minX + 20,
                y: screenFrame.midY - windowFrame.height / 2
            )
        case .right:
            newOrigin = NSPoint(
                x: screenFrame.maxX - windowFrame.width - 20,
                y: screenFrame.midY - windowFrame.height / 2
            )
        case .center:
            newOrigin = NSPoint(
                x: screenFrame.midX - windowFrame.width / 2,
                y: screenFrame.midY - windowFrame.height / 2
            )
        }

        window.setFrameOrigin(newOrigin)
    }

    enum WindowPosition {
        case left, right, center
    }
}

// MARK: - Log Settings

struct LogSettingsView: View {
    @Binding var maxLogEntries: Int

    var body: some View {
        Form {
            Section {
                Picker("Maximum log entries", selection: $maxLogEntries) {
                    Text("1,000").tag(1000)
                    Text("5,000").tag(5000)
                    Text("10,000").tag(10000)
                    Text("Unlimited").tag(Int.max)
                }
                .help("Older logs will be removed when limit is reached")
            }

            Section("Log Colors") {
                HStack {
                    Circle().fill(.red).frame(width: 12, height: 12)
                    Text("Error")
                    Spacer()
                }
                HStack {
                    Circle().fill(.orange).frame(width: 12, height: 12)
                    Text("Warning")
                    Spacer()
                }
                HStack {
                    Circle().fill(.primary).frame(width: 12, height: 12)
                    Text("Info")
                    Spacer()
                }
                HStack {
                    Circle().fill(.secondary).frame(width: 12, height: 12)
                    Text("Debug")
                    Spacer()
                }
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Tools Settings

struct ToolsSettingsView: View {
    @Binding var autoRefreshDevices: Bool
    @State private var flutterPath: String = ""
    @State private var adbPath: String = ""

    var body: some View {
        Form {
            Section("Device Detection") {
                Toggle("Auto-refresh devices on launch", isOn: $autoRefreshDevices)
            }

            Section("Tool Paths (Optional)") {
                HStack {
                    Text("Flutter:")
                    TextField("Auto-detect", text: $flutterPath)
                        .textFieldStyle(.roundedBorder)
                    Button("Browse...") {
                        selectPath(for: .flutter)
                    }
                }

                HStack {
                    Text("ADB:")
                    TextField("Auto-detect", text: $adbPath)
                        .textFieldStyle(.roundedBorder)
                    Button("Browse...") {
                        selectPath(for: .adb)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .onAppear {
            loadPaths()
        }
    }

    private func loadPaths() {
        flutterPath = UserDefaults.standard.string(forKey: "flutterPath") ?? ""
        adbPath = UserDefaults.standard.string(forKey: "adbPath") ?? ""
    }

    private func selectPath(for tool: Tool) {
        let panel = NSOpenPanel()
        panel.title = "Select \(tool.rawValue) executable"
        panel.canChooseFiles = true
        panel.canChooseDirectories = false

        if panel.runModal() == .OK, let url = panel.url {
            switch tool {
            case .flutter:
                flutterPath = url.path
                UserDefaults.standard.set(flutterPath, forKey: "flutterPath")
            case .adb:
                adbPath = url.path
                UserDefaults.standard.set(adbPath, forKey: "adbPath")
            }
        }
    }

    enum Tool: String {
        case flutter = "Flutter"
        case adb = "ADB"
    }
}

#Preview {
    SettingsView()
}
