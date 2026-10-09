import SwiftUI

struct ActionsView: View {
    @Environment(AppModel.self) private var model
    let project: Project
    @State private var customCommand = ""
    @State private var portText = ""

    var body: some View {
        let mode = model.effectiveMode(project)

        ScrollView {
            VStack(alignment: .leading, spacing: Space.xl) {
                VStack(alignment: .leading, spacing: Space.s) {
                    SectionTitle(title: "Project")
                    Card(padding: Space.xs) {
                        VStack(spacing: 0) {
                            ActionRow(icon: "folder-open", title: "Reveal in Finder", subtitle: "Finder") { model.reveal(project.id) }
                            Divider().overlay(Brand.borderSoft).padding(.horizontal, Space.m)
                            ActionRow(icon: "code-xml", title: "Open in Editor", subtitle: model.settings.editorCommand.isEmpty ? "code" : model.settings.editorCommand) { model.openInEditor(project.id) }
                            Divider().overlay(Brand.borderSoft).padding(.horizontal, Space.m)
                            ActionRow(icon: "terminal", title: "Open Terminal Here", subtitle: "Terminal.app") { model.openTerminal(project.id) }
                        }
                    }
                }
                .appearIn()

                VStack(alignment: .leading, spacing: Space.s) {
                    SectionTitle(title: "Run settings")
                    Card(padding: Space.l) {
                        VStack(alignment: .leading, spacing: Space.l) {
                            VStack(alignment: .leading, spacing: Space.xs) {
                                Text("Run mode").font(.dBodyMedium)
                                Picker("Run mode", selection: Binding(
                                    get: { project.runModeOverride },
                                    set: { model.setRunMode(project.id, $0) })) {
                                    Text("Auto-detect (\(model.info(project.id)?.detectedMode.title ?? "…"))").tag(RunModeKind?.none)
                                    ForEach(RunModeKind.allCases) { Text($0.title).tag(RunModeKind?.some($0)) }
                                }
                                .labelsHidden()
                                .frame(maxWidth: 360, alignment: .leading)
                                Text("How \(AppInfo.name) starts this project. Auto-detect is right for most.")
                                    .font(.dCaption).foregroundStyle(Brand.muted)
                            }

                            if mode == .custom {
                                VStack(alignment: .leading, spacing: Space.xs) {
                                    Text("Custom command").font(.dBodyMedium)
                                    TextField("e.g. pnpm run dev", text: $customCommand)
                                        .textFieldStyle(.roundedBorder)
                                        .font(.dMono)
                                        .onSubmit { model.setCustomCommand(project.id, customCommand) }
                                        .onChange(of: customCommand) { _, v in model.setCustomCommand(project.id, v) }
                                    Text("Runs in the project folder. The address is read from its output.")
                                        .font(.dCaption).foregroundStyle(Brand.muted)
                                }
                            }

                            if mode == .wrangler || mode == .pages {
                                VStack(alignment: .leading, spacing: Space.xs) {
                                    Text("Port").font(.dBodyMedium)
                                    TextField("auto", text: $portText)
                                        .textFieldStyle(.roundedBorder)
                                        .frame(width: 110)
                                        .onSubmit { commitPort() }
                                    Text("Allocated from 8787 upward when empty or busy.")
                                        .font(.dCaption).foregroundStyle(Brand.muted)
                                }
                            }
                        }
                    }
                }
                .appearIn(0.06)
            }
            .padding(Space.xl)
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

struct ActionRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let action: () -> Void
    @State private var hover = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: Space.m) {
                Icon(icon, size: IconSize.md).foregroundStyle(Brand.muted).frame(width: IconSize.md)
                Text(title).font(.dBodyMedium)
                Text(subtitle).font(.dCaption).foregroundStyle(Brand.muted).lineLimit(1).truncationMode(.middle)
                Spacer(minLength: Space.s)
                Icon("arrow-up-right", size: IconSize.sm)
                    .foregroundStyle(hover ? Brand.text : Brand.faint)
                    .offset(x: hover ? 1 : 0, y: hover ? -1 : 0)
            }
            .padding(.horizontal, Space.m).frame(minHeight: 36)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .hoverFill(radius: Radius.control)
        .onHover { hover = $0 }
        .animation(.easeOut(duration: 0.15), value: hover)
    }
}
