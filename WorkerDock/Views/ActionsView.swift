import SwiftUI

struct ActionsView: View {
    @Environment(AppModel.self) private var model
    let project: Project
    @State private var customCommand = ""
    @State private var portText = ""

    var body: some View {
        let rt = model.runtime(project.id)
        let mode = model.effectiveMode(project)

        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 10) {
                    SectionTitle(title: "Open", icon: "arrow-up-right")
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 230), spacing: 12)], spacing: 12) {
                        ActionTile(icon: "globe", title: "Open in Browser", subtitle: rt.url?.absoluteString ?? "Available while running",
                                   enabled: rt.status == .running) { model.openInBrowser(project.id) }
                        ActionTile(icon: "compass", title: "Open Explorer", subtitle: "Local D1, KV, R2 and more",
                                   enabled: rt.status == .running) { model.openExplorer(project.id) }
                        ForEach(model.quickLinks(project.id).filter { $0 != .site }) { link in
                            ActionTile(icon: link.symbolLucide, title: link.title, subtitle: link.path,
                                       enabled: rt.status == .running) { model.open(link, for: project.id) }
                        }
                        ActionTile(icon: "folder-open", title: "Reveal in Finder", subtitle: abbreviated(project.path)) { model.reveal(project.id) }
                        ActionTile(icon: "code-xml", title: "Open in Editor", subtitle: model.settings.editorCommand.isEmpty ? "code" : model.settings.editorCommand) { model.openInEditor(project.id) }
                        ActionTile(icon: "terminal", title: "Open Terminal Here", subtitle: "Terminal.app") { model.openTerminal(project.id) }
                    }
                }

                VStack(alignment: .leading, spacing: 10) {
                    SectionTitle(title: "Run settings", icon: "sliders-horizontal")
                    Card(padding: 20) {
                        VStack(alignment: .leading, spacing: 18) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Run mode").font(.system(size: 13, weight: .semibold))
                                Picker("Run mode", selection: Binding(
                                    get: { project.runModeOverride },
                                    set: { model.setRunMode(project.id, $0) })) {
                                    Text("Auto-detect (\(model.info(project.id)?.detectedMode.title ?? "…"))").tag(RunModeKind?.none)
                                    ForEach(RunModeKind.allCases) { Text($0.title).tag(RunModeKind?.some($0)) }
                                }
                                .labelsHidden()
                                .frame(maxWidth: 360, alignment: .leading)
                                Text("How \(AppInfo.name) starts this project. Auto-detect is right for most.")
                                    .font(.system(size: 12)).foregroundStyle(Brand.muted)
                            }

                            if mode == .custom {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("Custom command").font(.system(size: 13, weight: .semibold))
                                    TextField("e.g. pnpm run dev", text: $customCommand)
                                        .textFieldStyle(.roundedBorder)
                                        .font(.system(size: 13, design: .monospaced))
                                        .onSubmit { model.setCustomCommand(project.id, customCommand) }
                                        .onChange(of: customCommand) { _, v in model.setCustomCommand(project.id, v) }
                                    Text("Runs in the project folder. The address is read from its output.")
                                        .font(.system(size: 12)).foregroundStyle(Brand.muted)
                                }
                            }

                            if mode == .wrangler || mode == .pages {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("Port").font(.system(size: 13, weight: .semibold))
                                    TextField("auto", text: $portText)
                                        .textFieldStyle(.roundedBorder)
                                        .frame(width: 110)
                                        .onSubmit { commitPort() }
                                    Text("Allocated from 8787 upward when empty or busy.")
                                        .font(.system(size: 12)).foregroundStyle(Brand.muted)
                                }
                            }
                        }
                    }
                }
            }
            .padding(28)
            .frame(maxWidth: 1100, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .onAppear {
            customCommand = project.customCommand ?? ""
            portText = project.port.map(String.init) ?? ""
        }
        .onDisappear { commitPort() }
    }

    private func commitPort() {
        let trimmed = portText.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty { model.setPort(project.id, nil) }
        else if let p = Int(trimmed), (1024...65535).contains(p) { model.setPort(project.id, p) }
        else { portText = project.port.map(String.init) ?? "" }
    }
}

struct ActionTile: View {
    let icon: String
    let title: String
    let subtitle: String
    var enabled = true
    let action: () -> Void
    @State private var hover = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Brand.accent.opacity(enabled ? 0.12 : 0.06))
                    Icon(icon, size: 17).foregroundStyle(enabled ? Brand.accent : Brand.faint)
                }
                .frame(width: 38, height: 38)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.system(size: 13.5, weight: .semibold))
                    Text(subtitle).font(.system(size: 11.5)).foregroundStyle(Brand.muted).lineLimit(1).truncationMode(.middle)
                }
                Spacer(minLength: 4)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Brand.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(hover && enabled ? Brand.accent.opacity(0.5) : Brand.border, lineWidth: 1))
            .shadow(color: .black.opacity(hover && enabled ? 0.08 : 0.03), radius: hover ? 9 : 4, y: 2)
            .opacity(enabled ? 1 : 0.55)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .onHover { hover = $0 }
        .animation(.easeOut(duration: 0.15), value: hover)
    }
}
