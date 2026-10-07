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
                    if let err = info.parseError { banner(err, symbol: "exclamationmark.triangle.fill", tint: .orange) }
                    if !model.depsReady(project) { installBanner(rt, info) }
                    if case .error(let message) = rt.status, model.depsReady(project) || message != "Dependencies not installed" {
                        banner(message, symbol: "xmark.octagon.fill", tint: .red)
                    }
                }

                section("Project") {
                    row("Name", info?.workerName ?? project.name)
                    row("Path", abbreviated(project.path), mono: true, selectable: true)
                    row("Config", "\(project.configFile)  (\(info?.configKind.title ?? "—"))")
                    if let main = info?.mainEntry { row("Entry", main, mono: true) }
                    if let d = info?.compatibilityDate { row("Compatibility date", d) }
                }

                section("Runtime") {
                    row("Status", rt.status.label)
                    row("Run mode", model.effectiveMode(project).title + (project.runModeOverride == nil ? " (auto)" : ""))
                    if let fw = info?.framework { row("Framework", fw) }
                    if let cms = info?.cms { row("CMS", cms) }
                    if info?.pagesOutputDir != nil { row("Cloudflare Pages", "output: \(info?.pagesOutputDir ?? "")") }
                    row("Package manager", info?.packageManager.rawValue ?? "—")
                    row("Wrangler", info?.wranglerVersion ?? (info == nil ? "—" : "not installed"))
                    if let v = info?.vitePluginVersion { row("Vite plugin", v) }
                    row("Port", rt.port.map(String.init) ?? project.port.map { "\($0) (reserved)" } ?? "assigned on start")
                    if let ip = project.inspectorPort { row("Inspector port", String(ip)) }
                    if rt.status.isActive {
                        row("Memory", rt.memoryBytes.map(Format.bytes) ?? "measuring…")
                        if rt.external { row("Started by", "outside \(AppInfo.name) (detected)") }
                    }
                }

                if rt.status == .running, rt.url != nil {
                    section("Quick links") {
                        HStack {
                            ForEach(model.quickLinks(project.id)) { link in
                                Button { model.open(link, for: project.id) } label: { Label(link.title, systemImage: link.symbol) }
                            }
                            Button { model.openExplorer(project.id) } label: { Label("Open Explorer", systemImage: "cylinder.split.1x2") }
                        }
                    }
                }

                if let info {
                    section("Bindings") {
                        if info.bindings.isEmpty && info.varNames.isEmpty {
                            Text("No bindings found in config.").foregroundStyle(.secondary)
                        }
                        ForEach(BindingKind.allCases, id: \.self) { kind in
                            let items = info.bindings.filter { $0.kind == kind }
                            if !items.isEmpty {
                                VStack(alignment: .leading, spacing: 4) {
                                    Label(kind.title, systemImage: kind.symbol).font(.subheadline.weight(.medium))
                                    ForEach(items) { b in
                                        HStack(spacing: 6) {
                                            Text(b.name).font(.callout.monospaced())
                                            if let d = b.detail {
                                                Text("→ \(d)").font(.callout).foregroundStyle(.secondary)
                                            }
                                        }
                                        .padding(.leading, 24)
                                    }
                                }
                            }
                        }
                        if !info.varNames.isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                Label("Variables (names only)", systemImage: "textformat").font(.subheadline.weight(.medium))
                                Text(info.varNames.joined(separator: ", "))
                                    .font(.callout.monospaced())
                                    .padding(.leading, 24)
                            }
                        }
                    }
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        // Memory is only measured while this tab is on screen and the project is up.
        .task(id: rt.status) {
            while !Task.isCancelled {
                await model.updateMemory(project.id)
                try? await Task.sleep(nanoseconds: 3_000_000_000)
            }
        }
    }

    private func installBanner(_ rt: ProjectRuntime, _ info: ProjectInfo) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "shippingbox.and.arrow.backward").foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 2) {
                Text("Dependencies not installed").font(.headline)
                Text("Run `\(info.packageManager.install)` in this project to continue.")
                    .font(.callout).foregroundStyle(.secondary)
            }
            Spacer()
            if rt.installing {
                ProgressView().controlSize(.small)
            } else {
                Button("Install") { Task { await model.installDependencies(project.id) } }
                    .buttonStyle(.borderedProminent).tint(.cfOrange)
            }
        }
        .padding(12)
        .background(.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
    }

    private func banner(_ text: String, symbol: String, tint: Color) -> some View {
        Label(text, systemImage: symbol)
            .foregroundStyle(tint)
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(tint.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.headline)
            VStack(alignment: .leading, spacing: 6) { content() }
        }
    }

    @ViewBuilder
    private func row(_ label: String, _ value: String, mono: Bool = false, selectable: Bool = false) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label).foregroundStyle(.secondary).frame(width: 140, alignment: .leading)
            if selectable {
                Text(value).font(mono ? .body.monospaced() : .body).textSelection(.enabled)
            } else {
                Text(value).font(mono ? .body.monospaced() : .body)
            }
        }
    }
}
