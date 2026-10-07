import SwiftUI
import AppKit

@main
struct WorkerDockApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @State private var model = AppModel.shared

    var body: some Scene {
        Window(AppInfo.name, id: "main") {
            MainView()
                .environment(model)
                .frame(minWidth: 820, minHeight: 520)
        }
        .defaultSize(width: 1040, height: 680)
        .commands {
            CommandMenu("Project") {
                Button("Start") { if let id = model.selection { model.start(id) } }
                    .keyboardShortcut(.return, modifiers: .command)
                Button("Restart") { if let id = model.selection { model.restart(id) } }
                    .keyboardShortcut("r", modifiers: .command)
                Button("Stop") { if let id = model.selection { model.stop(id) } }
                    .keyboardShortcut(".", modifiers: .command)
                Divider()
                Button("Rescan Folders") { model.rescan() }
                    .keyboardShortcut("r", modifiers: [.command, .shift])
            }
        }

        MenuBarExtra {
            MenuBarContent().environment(model)
        } label: {
            Image(systemName: model.runningCount > 0 ? "shippingbox.fill" : "shippingbox")
        }

        Settings {
            SettingsView().environment(model)
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        AppModel.shared.bootstrap()
    }

    /// Keep running from the menu bar when the window is closed, like Herd.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        let model = AppModel.shared
        guard model.confirmQuit() else { return .terminateCancel }
        Task { @MainActor in
            await model.stopAll()
            NSApp.reply(toApplicationShouldTerminate: true)
        }
        return .terminateLater
    }
}
