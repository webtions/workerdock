import SwiftUI

struct OverviewView: View {
    @Environment(AppModel.self) private var model
    let project: Project

    var body: some View {
        let rt = model.runtime(project.id)
        let info = model.info(project.id)

        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                if let info {
                    if let err = info.parseError { banner(err, icon: "triangle-alert", tint: Brand.warning) }
                    if !model.depsReady(project) { installBanner(rt, info) }
                    if case .error(let message) = rt.status, model.depsReady(project) || message != "Dependencies not installed" {
                        banner(message, icon: "circle-x", tint: Brand.accent)
                    }
                }

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 170), spacing: 14)], spacing: 14) {
                    StatTile(icon: "activity", label: "Status", value: statusText(rt), tint: statusColor(rt))
                    StatTile(icon: "globe", label: "Address",
                             value: rt.url.flatMap { $0.port.map { ":\($0)" } } ?? (project.port.map { ":\($0)" } ?? "—"),
                             caption: rt.status == .running ? "localhost" : "reserved")
                    StatTile(icon: "memory-stick", label: "Memory",
                             value: rt.status.isActive ? (rt.memoryBytes.map(Format.bytes) ?? "…") : "—",
                             caption: rt.status.isActive ? "process group" : nil)
                    StatTile(icon: "package", label: "Wrangler",
                             value: info?.wranglerVersion ?? (info == nil ? "—" : "not installed"),
                             caption: info.map { $0.packageManager.rawValue })
                }

                if rt.status == .running, rt.url != nil {
                    quickLinks(rt)
                }

                if let info {
                    VStack(alignment: .leading, spacing: 10) {
                        SectionTitle(title: "Bindings", icon: "workflow",
                                     trailing: "\(info.bindings.count + (info.varNames.isEmpty ? 0 : 1)) connected")
                        Card(padding: 20) {
                            if info.bindings.isEmpty && info.varNames.isEmpty {
                                HStack(spacing: 10) {
                                    Icon("plug", size: 16).foregroundStyle(Brand.faint)
                                    Text("No bindings in this project's config.").foregroundStyle(Brand.muted)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, 8)
                            } else {
                                BindingGraph(workerName: info.workerName ?? project.name, entry: info.mainEntry,
                                             bindings: info.bindings, varNames: info.varNames, status: rt.status)
                            }
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 10) {
                    SectionTitle(title: "Details", icon: "info")
                    Card(padding: 6) {
                        VStack(spacing: 0) {
                            let rows = detailRows(info, rt)
                            ForEach(Array(rows.enumerated()), id: \.offset) { i, row in
                                HStack(alignment: .firstTextBaseline) {
                                    Text(row.0).foregroundStyle(Brand.muted).frame(width: 150, alignment: .leading)
                                    Text(row.1).font(row.2 ? .system(size: 12.5, design: .monospaced) : .system(size: 13)).textSelection(.enabled)
                                    Spacer()
                                }
                                .padding(.horizontal, 14).padding(.vertical, 9)
                                if i < rows.count - 1 { Divider().overlay(Brand.borderSoft) }
                            }
                        }
                    }
                }
            }
            .padding(28)
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

    private func quickLinks(_ rt: ProjectRuntime) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionTitle(title: "Quick links", icon: "arrow-up-right")
            HStack(spacing: 12) {
                ForEach(model.quickLinks(project.id)) { link in
                    LinkTile(icon: link.symbolLucide, title: link.title.replacingOccurrences(of: "Open ", with: ""),
                             subtitle: link.path) { model.open(link, for: project.id) }
                }
                LinkTile(icon: "compass", title: "Local Explorer", subtitle: "/cdn-cgi/explorer") { model.openExplorer(project.id) }
            }
        }
    }

    private func installBanner(_ rt: ProjectRuntime, _ info: ProjectInfo) -> some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Brand.warning.opacity(0.16))
                Icon("package", size: 18).foregroundStyle(Brand.warning)
            }
            .frame(width: 38, height: 38)
            VStack(alignment: .leading, spacing: 2) {
                Text("Dependencies not installed").font(.system(size: 14, weight: .semibold))
                Text("Run `\(info.packageManager.install)` to get this project ready.").font(.system(size: 12.5)).foregroundStyle(Brand.muted)
            }
            Spacer()
            if rt.installing {
                ProgressView().controlSize(.small)
            } else {
                Button { Task { await model.installDependencies(project.id) } } label: { Label { Text("Install") } icon: { Icon("download", size: 13) } }
                    .buttonStyle(.dockPrimary)
            }
        }
        .padding(14)
        .background(Brand.warning.opacity(0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Brand.warning.opacity(0.35), lineWidth: 1))
    }

    private func banner(_ text: String, icon: String, tint: Color) -> some View {
        HStack(spacing: 10) {
            Icon(icon, size: 16)
            Text(text).font(.system(size: 13, weight: .medium))
            Spacer()
        }
        .foregroundStyle(tint)
        .padding(14)
        .background(tint.opacity(0.09), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(tint.opacity(0.3), lineWidth: 1))
    }

    private func statusText(_ rt: ProjectRuntime) -> String {
        switch rt.status {
        case .running: return rt.external ? "Attached" : "Running"
        case .starting: return "Starting"
        case .stopped: return "Stopped"
        case .error: return "Error"
        }
    }

    private func statusColor(_ rt: ProjectRuntime) -> Color {
        switch rt.status {
        case .running: return Brand.success
        case .starting: return Brand.warning
        case .stopped: return Brand.muted
        case .error: return Brand.accent
        }
    }

    private func detailRows(_ info: ProjectInfo?, _ rt: ProjectRuntime) -> [(String, String, Bool)] {
        var rows: [(String, String, Bool)] = [
            ("Name", info?.workerName ?? project.name, false),
            ("Path", abbreviated(project.path), true),
            ("Config", "\(project.configFile) · \(info?.configKind.title ?? "—")", false),
        ]
        if let main = info?.mainEntry { rows.append(("Entry", main, true)) }
        if let d = info?.compatibilityDate { rows.append(("Compatibility date", d, false)) }
        rows.append(("Run mode", model.effectiveMode(project).title + (project.runModeOverride == nil ? " (auto)" : ""), false))
        if let fw = info?.framework { rows.append(("Framework", fw, false)) }
        if let cms = info?.cms { rows.append(("CMS", cms, false)) }
        if let out = info?.pagesOutputDir { rows.append(("Pages output", out, true)) }
        rows.append(("Package manager", info?.packageManager.rawValue ?? "—", false))
        if let v = info?.vitePluginVersion { rows.append(("Vite plugin", v, false)) }
        if let ip = project.inspectorPort { rows.append(("Inspector port", String(ip), false)) }
        if rt.external { rows.append(("Started by", "outside \(AppInfo.name) (attached)", false)) }
        return rows
    }
}

extension ProjectLink {
    var symbolLucide: String { path == "/" ? "globe" : "user-round-key" }
}

struct StatTile: View {
    let icon: String
    let label: String
    let value: String
    var tint: Color = Brand.text
    var caption: String?

    var body: some View {
        Card(padding: 16) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 7) {
                    Icon(icon, size: 14).foregroundStyle(Brand.muted)
                    Text(label).font(.system(size: 12, weight: .medium)).foregroundStyle(Brand.muted)
                }
                Text(value)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(tint)
                    .lineLimit(1).minimumScaleFactor(0.6)
                Text(caption ?? " ").font(.system(size: 11.5)).foregroundStyle(Brand.faint)
            }
        }
    }
}

struct LinkTile: View {
    let icon: String
    let title: String
    let subtitle: String
    let action: () -> Void
    @State private var hover = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 9, style: .continuous).fill(Brand.accent.opacity(0.12))
                    Icon(icon, size: 16).foregroundStyle(Brand.accent)
                }
                .frame(width: 34, height: 34)
                VStack(alignment: .leading, spacing: 1) {
                    Text(title).font(.system(size: 13, weight: .semibold))
                    Text(subtitle).font(.system(size: 11, design: .monospaced)).foregroundStyle(Brand.muted)
                }
                Spacer(minLength: 8)
                Icon("arrow-up-right", size: 13).foregroundStyle(hover ? Brand.accent : Brand.faint)
            }
            .padding(.horizontal, 14).padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .background(Brand.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(hover ? Brand.accent.opacity(0.5) : Brand.border, lineWidth: 1))
            .shadow(color: .black.opacity(hover ? 0.08 : 0.03), radius: hover ? 10 : 5, y: 2)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hover = $0 }
        .animation(.easeOut(duration: 0.15), value: hover)
    }
}
