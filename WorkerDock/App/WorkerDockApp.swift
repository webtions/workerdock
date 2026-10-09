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
        .defaultSize(width: 1120, height: 740)
        .windowToolbarStyle(.unified(showsTitle: false))
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
            Image(model.runningCount > 0 ? "lucide-cloud-cog" : "lucide-cloud")
                .renderingMode(.template)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 17, height: 17)
        }

        Settings {
            SettingsView().environment(model)
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    /// True when macOS started the app at login, so it should stay in the menu bar without a window.
    private var launchedAtLogin: Bool {
        NSAppleEventManager.shared().currentAppleEvent?
            .paramDescriptor(forKeyword: AEKeyword(keyAEPropData))?.enumCodeValue == OSType(keyAELaunchedAsLogInItem)
    }

    func applicationWillFinishLaunching(_ notification: Notification) {
        if launchedAtLogin {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { NSApp.windows.filter { $0.canBecomeMain }.forEach { $0.close() } }
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // The unit-test runner launches a copy of the app as its host: keep it invisible
        // and away from the user's real registry.
        if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil {
            NSApp.setActivationPolicy(.prohibited)
            NSApp.windows.forEach { $0.close() }
            return
        }
        if let dir = ProcessInfo.processInfo.environment["WORKERDOCK_DEBUG_ICON"] {
            NSApp.setActivationPolicy(.prohibited)
            Task { @MainActor in
                try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
                let renderer = ImageRenderer(content: AppIconArt())
                renderer.scale = 1
                renderer.isOpaque = false
                if let cg = renderer.cgImage {
                    let rep = NSBitmapImageRep(cgImage: cg)
                    try? rep.representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: dir + "/icon-1024.png"))
                } else {
                    try? "render failed".write(toFile: dir + "/error.txt", atomically: true, encoding: .utf8)
                }
                exit(0)
            }
            return
        }
        if ProcessInfo.processInfo.environment["WORKERDOCK_DEBUG_SNAPSHOT"] != nil {
            NSApp.setActivationPolicy(ProcessInfo.processInfo.environment["WORKERDOCK_DEBUG_ACTIVE"] != nil ? .regular : .accessory)
        }
        if ProcessInfo.processInfo.environment["WORKERDOCK_DEBUG_START"] != nil {
            NSApp.setActivationPolicy(.prohibited)   // headless debug run: no window, no second app icon
        }
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
