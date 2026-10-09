import AppKit

/// An application the user can hand a project folder to (a terminal or a code editor).
struct ExternalApp: Identifiable, Hashable {
    let id: String      // bundle identifier, or an absolute path for apps chosen with "Other…"
    let name: String
    let url: URL

    var icon: NSImage {
        let image = NSWorkspace.shared.icon(forFile: url.path)
        image.size = NSSize(width: 16, height: 16)
        return image
    }
}

/// Known terminals and editors, detected by bundle identifier. Order is the "Automatic" preference.
enum AppCatalog {
    static let terminals: [(bundle: String, name: String)] = [
        ("com.apple.Terminal", "Terminal"),
        ("com.googlecode.iterm2", "iTerm"),
        ("com.mitchellh.ghostty", "Ghostty"),
        ("dev.warp.Warp-Stable", "Warp"),
        ("com.github.wez.wezterm", "WezTerm"),
        ("net.kovidgoyal.kitty", "kitty"),
        ("org.alacritty", "Alacritty"),
    ]

    static let editors: [(bundle: String, name: String)] = [
        ("com.microsoft.VSCode", "Visual Studio Code"),
        ("com.todesktop.230313mzl4w4u92", "Cursor"),
        ("com.exafunction.windsurf", "Windsurf"),
        ("dev.zed.Zed", "Zed"),
        ("com.sublimetext.4", "Sublime Text"),
        ("com.jetbrains.WebStorm", "WebStorm"),
        ("com.apple.dt.Xcode", "Xcode"),
    ]

    static func installed(_ list: [(bundle: String, name: String)]) -> [ExternalApp] {
        list.compactMap { entry in
            NSWorkspace.shared.urlForApplication(withBundleIdentifier: entry.bundle)
                .map { ExternalApp(id: entry.bundle, name: entry.name, url: $0) }
        }
    }

    /// An app picked by hand ("Other…"), stored by path.
    static func app(atPath path: String) -> ExternalApp? {
        guard path.hasPrefix("/"), FileManager.default.fileExists(atPath: path) else { return nil }
        let url = URL(fileURLWithPath: path)
        return ExternalApp(id: path, name: url.deletingPathExtension().lastPathComponent, url: url)
    }

    /// The saved choice if it still exists, otherwise the first installed app ("Automatic").
    static func resolve(_ setting: String, among installed: [ExternalApp]) -> ExternalApp? {
        if !setting.isEmpty {
            if let match = installed.first(where: { $0.id == setting }) { return match }
            if let custom = app(atPath: setting) { return custom }
        }
        return installed.first
    }

    /// Lets the user choose any .app. Returns its path.
    @MainActor static func chooseApp() -> String? {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.application]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Choose"
        return panel.runModal() == .OK ? panel.url?.path : nil
    }
}
