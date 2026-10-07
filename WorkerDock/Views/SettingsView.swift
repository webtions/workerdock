import SwiftUI
import AppKit

struct SettingsView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        Form {
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

            Section("Editor") {
                TextField("Command", text: $model.settings.editorCommand, prompt: Text("code"))
                    .font(.body.monospaced())
                Text("Run as `<command> <project folder>`. Falls back to Visual Studio Code if `code` isn't on your PATH.")
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
