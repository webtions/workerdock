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
                    Text("Actions").font(.headline)
                    HStack {
                        if rt.status.isActive {
                            Button { model.stop(project.id) } label: { Label("Stop", systemImage: "stop.fill") }
                            Button { model.restart(project.id) } label: { Label("Restart", systemImage: "arrow.clockwise") }
                                .disabled(!rt.managed)
                        } else {
                            Button { model.start(project.id) } label: { Label("Start", systemImage: "play.fill") }
                                .buttonStyle(.borderedProminent).tint(.cfOrange)
                        }
                    }
                    HStack {
                        Button { model.openInBrowser(project.id) } label: { Label("Open in Browser", systemImage: "safari") }
                            .disabled(rt.status != .running)
                        Button { model.openExplorer(project.id) } label: { Label("Open Explorer", systemImage: "cylinder.split.1x2") }
                            .disabled(rt.status != .running)
                    }
                    let extra = model.quickLinks(project.id).filter { $0 != .site }
                    if !extra.isEmpty {
                        HStack {
                            ForEach(extra) { link in
                                Button { model.open(link, for: project.id) } label: { Label(link.title, systemImage: link.symbol) }
                                    .disabled(rt.status != .running)
                            }
                        }
                    }
                    HStack {
                        Button { model.reveal(project.id) } label: { Label("Reveal in Finder", systemImage: "folder") }
                        Button { model.openInEditor(project.id) } label: { Label("Open in Editor", systemImage: "chevron.left.forwardslash.chevron.right") }
                        Button { model.openTerminal(project.id) } label: { Label("Open Terminal Here", systemImage: "terminal") }
                    }
                }

                Divider()

                VStack(alignment: .leading, spacing: 12) {
                    Text("Run settings").font(.headline)

                    Picker("Run mode", selection: Binding(
                        get: { project.runModeOverride },
                        set: { model.setRunMode(project.id, $0) })) {
                        Text("Auto-detect (\(model.info(project.id)?.detectedMode.title ?? "…"))").tag(RunModeKind?.none)
                        ForEach(RunModeKind.allCases) { Text($0.title).tag(RunModeKind?.some($0)) }
                    }
                    .frame(maxWidth: 420)

                    if mode == .custom {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Custom command (runs in the project folder; the URL is read from its output)")
                                .font(.callout).foregroundStyle(.secondary)
                            TextField("e.g. pnpm run dev", text: $customCommand)
                                .textFieldStyle(.roundedBorder)
                                .font(.body.monospaced())
                                .onSubmit { model.setCustomCommand(project.id, customCommand) }
                                .onChange(of: customCommand) { _, v in model.setCustomCommand(project.id, v) }
                        }
                        .frame(maxWidth: 520)
                    }

                    if mode == .wrangler || mode == .pages {
                        HStack {
                            Text("Port")
                            TextField("auto", text: $portText)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 90)
                                .onSubmit { commitPort() }
                            Text("Allocated from 8787 upward when empty or busy.")
                                .font(.callout).foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
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
