import SwiftUI

/// Extension to handle keyboard shortcuts from menu commands
extension View {
    func handleMenuActions(appState: AppState) -> some View {
        self
            .onReceive(NotificationCenter.default.publisher(for: .runAction)) { _ in
                Task { await appState.run() }
            }
            .onReceive(NotificationCenter.default.publisher(for: .stopAction)) { _ in
                Task { await appState.stop() }
            }
            .onReceive(NotificationCenter.default.publisher(for: .hotReloadAction)) { _ in
                Task { await appState.hotReload() }
            }
            .onReceive(NotificationCenter.default.publisher(for: .hotRestartAction)) { _ in
                Task { await appState.hotRestart() }
            }
            .onReceive(NotificationCenter.default.publisher(for: .refreshDevicesAction)) { _ in
                Task { await appState.refreshDevices() }
            }
            .onReceive(NotificationCenter.default.publisher(for: .clearLogsAction)) { _ in
                appState.clearLogs()
            }
            .onReceive(NotificationCenter.default.publisher(for: .exportLogsAction)) { _ in
                appState.exportLogs()
            }
            .onReceive(NotificationCenter.default.publisher(for: .toggleAutoScrollAction)) { _ in
                appState.logProcessor.autoScroll.toggle()
            }
    }
}
