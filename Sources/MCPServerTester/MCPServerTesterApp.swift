import MCP
import SwiftUI

@main
struct MCPServerTesterApp: App {
    @StateObject private var viewModel = ServerViewModel()
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(viewModel)
                .onAppear {
                    NSApp.activate(ignoringOtherApps: true)
                    NSApp.mainWindow?.makeKeyAndOrderFront(nil)
                }
        }
        .windowStyle(.titleBar)
        .defaultSize(width: 900, height: 700)
        .windowToolbarStyle(.unified)
        .commands {
            CommandGroup(replacing: .newItem) {}
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_: Notification) {
        NSApplication.shared.setActivationPolicy(.regular)
    }
}