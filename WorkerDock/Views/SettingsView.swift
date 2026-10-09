import SwiftUI
import AppKit
import ServiceManagement

struct SettingsView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        Form {
            Section("General") {
                Picker("Theme", selection: $model.settings.appearance) {
                    ForEach(AppearanceMode.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                LoginItemToggle()
                Toggle("Show icon in the Dock", isOn: $model.settings.showDockIcon)
                Text("Turn off to keep \(AppInfo.name) in the menu bar only.")
                    .font(.caption).foregroundStyle(.secondary)
                if let support = AppInfo.supportURL {
                    Link("Support \(AppInfo.name)", destination: support)
                }
            }

            Section("Project folders") {
                if model.roots.isEmpty {
                    Text("No folders added yet.").foregroundStyle(.secondary)
                }
                ForEach(model.roots, id: \.self) { root in
                    HStack {
                        Text(abbreviated(root)).font(.body.monospaced())
                        Spacer()
                        Button(role: .destructive) { model.removeRoot(root) } label: { Image(systemName: "minus.circle") }
                            .buttonStyle(.borderless)
                    }
                }
                HStack {
                    Button("Add Folder…") { addRoot(model) }
                    Button("Rescan Now") { model.rescan() }.disabled(model.roots.isEmpty || model.isScanning)
                }
                Toggle("Watch folders for new projects (FSEvents)", isOn: $model.settings.watchRoots)
            }

            Section("Access") {
                FolderAccessRows()
            }

            Section("Terminal") {
                AppPicker(title: "Open Terminal with", selection: $model.settings.terminalApp,
                          installed: model.installedTerminals, automatic: model.installedTerminals.first?.name)
            }

            Section("Editor") {
                AppPicker(title: "Open projects with", selection: $model.settings.editorApp,
                          installed: model.installedEditors, automatic: model.installedEditors.first?.name)
                TextField("Custom command", text: $model.settings.editorCommand, prompt: Text("Optional, e.g. code or cursor"))
                    .font(.body.monospaced())
                Text("When set, runs as `<command> <project folder>` and is used instead of the app above.")
                    .font(.caption).foregroundStyle(.secondary)
            }

            Section("Node") {
                HStack {
                    TextField("Node path override", text: $model.settings.nodePath, prompt: Text("Automatic (from your login shell)"))
                        .font(.body.monospaced())
                    Button("Choose…") {
                        let panel = NSOpenPanel()
                        panel.canChooseFiles = true
                        panel.canChooseDirectories = true
                        panel.message = "Choose the node binary or its bin folder"
                        if panel.runModal() == .OK, let p = panel.url?.path { model.settings.nodePath = p }
                    }
                }
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(model.shellEnvLoaded ? "Shell environment loaded" : "Loading shell environment…")
                            .font(.caption.weight(.medium))
                        Text(pathPreview).font(.caption.monospaced()).foregroundStyle(.secondary)
                            .lineLimit(3).textSelection(.enabled)
                    }
                    Spacer()
                    Button("Reload") { model.reloadShellEnvironment() }
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 560, height: 520)
    }

    private var pathPreview: String {
        let path = model.environment["PATH"] ?? ""
        return "PATH: " + path.split(separator: ":").prefix(4).joined(separator: ":") + "…"
    }
}

/// Dropdown of installed apps with an Automatic entry and an "Other…" file chooser.
struct AppPicker: View {
    let title: String
    @Binding var selection: String
    let installed: [ExternalApp]
    let automatic: String?
    private static let other = "__other__"

    private var custom: ExternalApp? {
        guard !selection.isEmpty, !installed.contains(where: { $0.id == selection }) else { return nil }
        return AppCatalog.app(atPath: selection)
    }

    var body: some View {
        Picker(title, selection: Binding(get: { selection }, set: { choose($0) })) {
            Text("Automatic" + (automatic.map { " (\($0))" } ?? "")).tag("")
            Divider()
            ForEach(installed) { app in
                Label { Text(app.name) } icon: { Image(nsImage: app.icon) }.tag(app.id)
            }
            if let custom {
                Label { Text(custom.name) } icon: { Image(nsImage: custom.icon) }.tag(custom.id)
            }
            Divider()
            Text("Other…").tag(Self.other)
        }
    }

    private func choose(_ value: String) {
        if value == Self.other {
            if let path = AppCatalog.chooseApp() { selection = path }
        } else {
            selection = value
        }
    }
}

/// "Open at login" switch backed by macOS's own login-item list, so System Settings always agrees with it.
struct LoginItemToggle: View {
    @State private var status = SMAppService.mainApp.status
    @State private var error: String?

    private var isOn: Bool { status == .enabled || status == .requiresApproval }

    var body: some View {
        Toggle("Open \(AppInfo.name) at login", isOn: Binding(get: { isOn }, set: set))
        if status == .requiresApproval {
            HStack(spacing: 6) {
                Text("macOS needs your approval.").font(.caption).foregroundStyle(.secondary)
                Button("Open Login Items") { SMAppService.openSystemSettingsLoginItems() }
                    .buttonStyle(.link).font(.caption)
            }
        } else if let error {
            Text(error).font(.caption).foregroundStyle(.red)
        } else {
            Text("Starts quietly in the menu bar, without opening a window.").font(.caption).foregroundStyle(.secondary)
        }
    }

    private func set(_ on: Bool) {
        error = nil
        do {
            if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
        } catch {
            self.error = "Couldn't change this: \(error.localizedDescription). Move \(AppInfo.name) to the Applications folder and try again."
        }
        status = SMAppService.mainApp.status
    }
}

/// Shows whether macOS lets the app read each project folder. Needed because some places (Documents, Desktop,
/// Downloads, external drives) ask for permission the first time.
struct FolderAccessRows: View {
    @Environment(AppModel.self) private var model
    @State private var blocked: Set<String> = []

    var body: some View {
        Group {
            if model.roots.isEmpty {
                Text("Add a project folder above and its access status shows here.").font(.caption).foregroundStyle(.secondary)
            }
            ForEach(model.roots, id: \.self) { root in
                HStack {
                    Text(abbreviated(root)).font(.body.monospaced()).lineLimit(1).truncationMode(.middle)
                    Spacer()
                    if blocked.contains(root) {
                        Label("No access", systemImage: "exclamationmark.triangle.fill").foregroundStyle(.orange).font(.caption)
                    } else {
                        Label("Allowed", systemImage: "checkmark.circle.fill").foregroundStyle(.green).font(.caption)
                    }
                }
            }
            if !blocked.isEmpty {
                Text("macOS is blocking \(AppInfo.name) from reading some folders. Allow it under Privacy & Security → Files and Folders (or Full Disk Access), then press Check again.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            HStack {
                Button("Check again") { check() }
                Button("Open Privacy Settings") {
                    NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_FilesAndFolders")!)
                }
            }
        }
        .onAppear { check() }
    }

    private func check() {
        blocked = Set(model.roots.filter { (try? FileManager.default.contentsOfDirectory(atPath: $0)) == nil })
    }
}
