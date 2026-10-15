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
            CommandGroup(replacing: .appInfo) {
                AboutMenuButton()
                if AppUpdater.shared.isEnabled {
                    Button("Check for Updates…") { AppUpdater.shared.checkForUpdates() }
                }
            }
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

        Window("About \(AppInfo.name)", id: "about") {
            AboutView()
        }
        .windowResizability(.contentSize)
        .windowStyle(.hiddenTitleBar)

        MenuBarExtra {
            MenuBarContent().environment(model)
        } label: {
            Image(nsImage: StatusBarIcon.image)
        }

        Settings {
            SettingsView().environment(model)
        }
    }
}

/// The menu bar mark, the same shape as the app icon, at the size the menu bar expects. MenuBarExtra ignores SwiftUI
/// frames on its label and uses the image's own size, so the size is set on the NSImage itself.
enum StatusBarIcon {
    static let image: NSImage = {
        guard let base = NSImage(named: "brand-workerdock-idle"), let img = base.copy() as? NSImage else { return NSImage() }
        img.size = NSSize(width: 19, height: 11.3)
        img.isTemplate = true
        return img
    }()
}

struct AboutMenuButton: View {
    @Environment(\.openWindow) private var openWindow
    var body: some View {
        Button("About \(AppInfo.name)") {
            openWindow(id: "about")
            NSApp.activate(ignoringOtherApps: true)
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
        // Overlay scrollbars for this app only (shown while scrolling), so a scrollbar never takes width from the page
        // and the header above it shares the page's left and right edges even when a mouse is attached.
        UserDefaults.standard.set("WhenScrolling", forKey: "AppleShowScrollBars")
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
        if ProcessInfo.processInfo.environment["WORKERDOCK_DEBUG_SNAPSHOT"] != nil {
            NSApp.setActivationPolicy(ProcessInfo.processInfo.environment["WORKERDOCK_DEBUG_ACTIVE"] != nil ? .regular : .accessory)
        }
        if ProcessInfo.processInfo.environment["WORKERDOCK_DEBUG_START"] != nil {
            NSApp.setActivationPolicy(.prohibited)   // headless debug run: no window, no second app icon
        }
        // WORKERDOCK_WIDTH resizes the window shortly after launch, so screenshots can check narrow layouts.
        if let w = Double(ProcessInfo.processInfo.environment["WORKERDOCK_WIDTH"] ?? "") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                NSApp.windows.first(where: { $0.canBecomeMain })?.setContentSize(NSSize(width: w, height: 760))
            }
        }
        AppUpdater.shared.start()
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
