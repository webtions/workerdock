import SwiftUI

struct OverviewView: View {
    @Environment(AppModel.self) private var model
    let project: Project

    var body: some View {
        let rt = model.runtime(project.id)
        let info = model.info(project.id)

        ScrollView {
            VStack(alignment: .leading, spacing: Space.xl) {
                if let info {
                    if let err = info.parseError { banner(err, icon: "triangle-alert", tint: Brand.warning) }
                    if !model.depsReady(project) { installBanner(rt, info) }
                    if case .error(let message) = rt.status, model.depsReady(project) || message != "Dependencies not installed" {
                        banner(message, icon: "circle-x", tint: Brand.danger)
                    }
                }

                if let info {
                    BindingsSection(project: project, info: info, status: rt.status)
                        .appearIn(0.04)
                }

                VStack(alignment: .leading, spacing: Space.s) {
                    SectionTitle(title: "Details")
                    Card(padding: 0) {
                        VStack(spacing: 0) {
                            let rows = detailRows(info, rt)
                            ForEach(Array(rows.enumerated()), id: \.offset) { i, row in
                                DetailRow(label: row.0, value: row.1, mono: row.2)
                                if i < rows.count - 1 { Divider().overlay(Brand.borderSoft).padding(.horizontal, Space.m) }
                            }
                        }
                    }
                }
                .appearIn(0.1)
            }
            .padding(Space.xl)
            .frame(maxWidth: 1100, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        // Memory is only measured while this tab is on screen and the project is up.
        .task(id: rt.status) {
            while !Task.isCancelled {
                await model.updateMemory(project.id)
                try? await Task.sleep(nanoseconds: 3_000_000_000)
            }
        }
    }

    // MARK: Pieces

    /// WorkerDock never installs anything: it shows the command and leaves running it to the user (or their agent).
    private func installBanner(_ rt: ProjectRuntime, _ info: ProjectInfo) -> some View {
        let command = info.packageManager.install
        let dir = info.packageRoot.map(abbreviated) ?? abbreviated(project.path)
        return HStack(spacing: Space.m) {
            Icon("package", size: IconSize.lg).foregroundStyle(Brand.warning)
            VStack(alignment: .leading, spacing: 2) {
                Text("Dependencies not installed").font(.dBodyMedium)
                HStack(spacing: Space.xs) {
                    Text("Run").font(.dCaption).foregroundStyle(Brand.muted)
                    Text(command).font(.dMono)
                    Text("in \(dir), then start the project.").font(.dCaption).foregroundStyle(Brand.muted)
                }
                .lineLimit(1)
            }
            Spacer()
            Button { copyToPasteboard(command) } label: { Label { Text("Copy command") } icon: { Icon("copy", size: IconSize.sm) } }
                .buttonStyle(.dockSecondary)
            Button { model.openTerminal(project.id) } label: { Label { Text("Open in \(model.terminalApp?.name ?? "Terminal")") } icon: { Icon("terminal", size: IconSize.sm) } }
                .buttonStyle(.dockSecondary)
        }
        .padding(Space.m)
        .overlay(RoundedRectangle(cornerRadius: Radius.panel, style: .continuous).strokeBorder(Brand.warning.opacity(0.5), lineWidth: 1))
    }

    private func banner(_ text: String, icon: String, tint: Color) -> some View {
        HStack(spacing: Space.s) {
            Icon(icon, size: IconSize.md)
            Text(text).font(.dBodyMedium)
            Spacer()
        }
        .foregroundStyle(tint)
        .padding(Space.m)
        .overlay(RoundedRectangle(cornerRadius: Radius.panel, style: .continuous).strokeBorder(tint.opacity(0.5), lineWidth: 1))
    }

    /// Only what the header and sidebar don't already say.
    private func detailRows(_ info: ProjectInfo?, _ rt: ProjectRuntime) -> [(String, String, Bool)] {
        var rows: [(String, String, Bool)] = [
            ("Path", abbreviated(project.path), true),
            ("Config", "\(project.configFile) · \(info?.configKind.title ?? "—")", false),
        ]
        if let main = info?.mainEntry { rows.append(("Entry", main, true)) }
        if let d = info?.compatibilityDate { rows.append(("Compatibility date", d, false)) }
        if let out = info?.pagesOutputDir { rows.append(("Pages output", out, true)) }
        rows.append(("Wrangler", info?.wranglerVersion ?? (info == nil ? "—" : "not installed"), false))
        if let v = info?.vitePluginVersion { rows.append(("Vite plugin", v, false)) }
        rows.append(("Package manager", info?.packageManager.rawValue ?? "—", false))
        if let ip = project.inspectorPort { rows.append(("Inspector port", String(ip), false)) }
        if rt.status.isActive { rows.append(("Memory", rt.memoryBytes.map(Format.bytes) ?? "…", false)) }
        if rt.external { rows.append(("Started by", "outside \(AppInfo.name) (attached)", false)) }
        return rows
    }
}

/// One label/value line. Every value has a visible copy button; no hover fill.
struct DetailRow: View {
    let label: String
    let value: String
    let mono: Bool
    @State private var copied = false

    var body: some View {
        HStack(spacing: Space.m) {
            Text(label).font(.dBody).foregroundStyle(Brand.muted).frame(width: 140, alignment: .leading)
            Text(value).font(mono ? .dMono : .dBody).textSelection(.enabled).lineLimit(1).truncationMode(.middle)
            Spacer(minLength: Space.s)
            Button {
                copyToPasteboard(value)
                withAnimation(.easeOut(duration: 0.15)) { copied = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { withAnimation(.easeOut(duration: 0.15)) { copied = false } }
            } label: {
                Icon(copied ? "check" : "copy", size: IconSize.sm)
                    .foregroundStyle(copied ? Brand.success : Brand.faint)
                    .contentTransition(.symbolEffect(.replace))
            }
            .buttonStyle(DockIconButtonStyle(size: 24))
            .help("Copy \(label.lowercased())")
        }
        .padding(.horizontal, Space.m).frame(height: 36)
    }
}

extension ProjectLink {
    var symbolLucide: String { path == "/" ? "globe" : "user-round-key" }
}
