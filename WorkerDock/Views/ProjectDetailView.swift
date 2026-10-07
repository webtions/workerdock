import SwiftUI

enum DetailTab: String, CaseIterable, Identifiable {
    case overview = "Overview", logs = "Logs", explorer = "Explorer", actions = "Actions"
    var id: String { rawValue }
    var icon: String {
        switch self {
        case .overview: return "layout-dashboard"
        case .logs: return "scroll-text"
        case .explorer: return "compass"
        case .actions: return "sliders-horizontal"
        }
    }
}

struct ProjectDetailView: View {
    @Environment(AppModel.self) private var model
    let projectID: String

    var body: some View {
        if let project = model.project(projectID) {
            let rt = model.runtime(projectID)
            let info = model.info(projectID)
            VStack(spacing: 0) {
                header(project, rt, info)
                Group {
                    switch model.selectedTab {
                    case .overview: OverviewView(project: project)
                    case .logs: LogsView(project: project)
                    case .explorer: ExplorerView(project: project)
                    case .actions: ActionsView(project: project)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .navigationTitle(project.name)
            .task { await model.refreshInfo(projectID) }
        }
    }

    private func header(_ project: Project, _ rt: ProjectRuntime, _ info: ProjectInfo?) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center, spacing: 14) {
                ProjectTile(icon: ProjectGlyph.icon(info), status: rt.status, size: 52)
                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 10) {
                        Text(model.displayName(project))
                            .font(.system(size: 26, weight: .bold, design: .rounded))
                            .lineLimit(1)
                        statusPill(rt)
                    }
                    HStack(spacing: 6) {
                        Icon("folder-open", size: 12).foregroundStyle(Brand.faint)
                        Text(abbreviated(project.path)).font(.system(size: 12, design: .monospaced)).foregroundStyle(Brand.muted)
                            .lineLimit(1).truncationMode(.middle)
                    }
                    HStack(spacing: 6) {
                        if let fw = info?.framework { Pill(text: fw, icon: "rocket", tint: Brand.accent) }
                        if let cms = info?.cms { Pill(text: cms, icon: "file-text", tint: Color(hex: "#8B5CF6")) }
                        if info?.pagesOutputDir != nil { Pill(text: "Pages", icon: "globe", tint: Color(hex: "#0EA5E9")) }
                        Pill(text: model.effectiveMode(project).title, icon: "terminal", tint: Brand.muted)
                    }
                }
                Spacer(minLength: 12)
                controls(project, rt)
            }

            HStack {
                TabBar(selection: Bindable(model).selectedTab)
                Spacer()
                if rt.status == .running, rt.url != nil {
                    HStack(spacing: 8) {
                        if let admin = model.quickLinks(project.id).first(where: { $0 != .site }) {
                            Button { model.open(admin, for: project.id) } label: {
                                Label { Text("Admin Login") } icon: { Icon("user-round-key", size: 13) }
                            }
                            .buttonStyle(.dockSecondary)
                        }
                        if let url = rt.url {
                            Button { model.openInBrowser(project.id) } label: {
                                Label { Text(url.host.map { "\($0):\(url.port ?? 80)" } ?? url.absoluteString).font(.system(size: 12.5, weight: .semibold, design: .monospaced)) }
                                    icon: { Icon("arrow-up-right", size: 13) }
                            }
                            .buttonStyle(.dockSecondary)
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 28)
        .padding(.top, 14)
        .padding(.bottom, 14)
        .background(Brand.background)
        .overlay(alignment: .bottom) { Rectangle().fill(Brand.border).frame(height: 1) }
    }

    private func statusPill(_ rt: ProjectRuntime) -> some View {
        let (text, color): (String, Color) = {
            switch rt.status {
            case .running: return (rt.external ? "Running · attached" : "Running", Brand.success)
            case .starting: return ("Starting", Brand.warning)
            case .stopped: return ("Stopped", Brand.muted)
            case .error: return ("Error", Brand.accent)
            }
        }()
        return HStack(spacing: 6) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text(text).font(.system(size: 11.5, weight: .semibold))
        }
        .padding(.horizontal, 9).padding(.vertical, 4)
        .foregroundStyle(color)
        .background(color.opacity(0.13), in: Capsule())
    }

    @ViewBuilder
    private func controls(_ project: Project, _ rt: ProjectRuntime) -> some View {
        HStack(spacing: 8) {
            if rt.status.isActive {
                Button { model.restart(project.id) } label: { Label { Text("Restart") } icon: { Icon("rotate-cw", size: 13) } }
                    .buttonStyle(.dockSecondary)
                    .disabled(!rt.managed)
                    .keyboardShortcut("r", modifiers: .command)
                    .help("Restart (⌘R)")
                Button { model.stop(project.id) } label: { Label { Text("Stop") } icon: { Icon("square", size: 12) } }
                    .buttonStyle(.dockDanger)
                    .keyboardShortcut(".", modifiers: .command)
                    .help("Stop (⌘.)")
            } else {
                Button { model.start(project.id) } label: { Label { Text("Start") } icon: { Icon("play", size: 13) } }
                    .buttonStyle(.dockPrimary)
                    .disabled(rt.installing)
                    .keyboardShortcut(.return, modifiers: .command)
                    .help("Start (⌘↩)")
            }
        }
    }
}

/// Apple-style segmented control with a raised selected chip.
struct TabBar: View {
    @Binding var selection: DetailTab
    @Namespace private var ns

    var body: some View {
        HStack(spacing: 2) {
            ForEach(DetailTab.allCases) { tab in
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) { selection = tab }
                } label: {
                    HStack(spacing: 6) {
                        Icon(tab.icon, size: 13)
                        Text(tab.rawValue).font(.system(size: 12.5, weight: .semibold))
                    }
                    .padding(.horizontal, 12).padding(.vertical, 6)
                    .foregroundStyle(selection == tab ? Brand.text : Brand.muted)
                    .background {
                        if selection == tab {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(Brand.card)
                                .shadow(color: .black.opacity(0.10), radius: 3, y: 1)
                                .matchedGeometryEffect(id: "tab", in: ns)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(Brand.border.opacity(0.55), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
    }
}

func abbreviated(_ path: String) -> String {
    (path as NSString).abbreviatingWithTildeInPath
}
