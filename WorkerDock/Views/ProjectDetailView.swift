import SwiftUI

enum DetailTab: String, CaseIterable, Identifiable {
    case overview = "Overview", logs = "Logs", explorer = "Explorer", settings = "Settings"
    var id: String { rawValue }
    var icon: String {
        switch self {
        case .overview: return "layout-dashboard"
        case .logs: return "scroll-text"
        case .explorer: return "compass"
        case .settings: return "sliders-horizontal"
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
                    case .settings: ProjectSettingsView(project: project)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .id(model.selectedTab)
                .transition(.opacity)
            }
            .animation(.easeOut(duration: 0.18), value: model.selectedTab)
            .navigationTitle(project.name)
            .task { await model.refreshInfo(projectID) }
            // Memory is measured every few seconds while this project is on screen and running.
            .task(id: rt.status) {
                while !Task.isCancelled {
                    await model.updateMemory(projectID)
                    try? await Task.sleep(nanoseconds: 3_000_000_000)
                }
            }
        }
    }

    private func header(_ project: Project, _ rt: ProjectRuntime, _ info: ProjectInfo?) -> some View {
        let primary = ProjectKind.primary(info)
        let extras = ProjectKind.badges(info).filter { $0 != primary }
        return VStack(alignment: .leading, spacing: Space.m) {
            HStack(alignment: .center, spacing: Space.l) {
                KindIcon(badge: primary, size: IconSize.xl).foregroundStyle(Brand.text)
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: Space.s) {
                        Text(model.displayName(project)).font(.dLargeTitle).lineLimit(1)
                        statusLabel(rt)
                    }
                    HStack(spacing: Space.m) {
                        Text(abbreviated(project.path)).font(.dMono).foregroundStyle(Brand.muted)
                            .lineLimit(1).truncationMode(.middle)
                        if rt.status == .running, let url = rt.url {
                            if let admin = model.quickLinks(project.id).first(where: { $0 != .site }) {
                                Button { model.open(admin, for: project.id) } label: {
                                    Label { Text("Admin Login") } icon: { Icon("user-round-key", size: 12) }
                                }
                                .buttonStyle(.dockSecondaryCompact)
                                .help("Open \(admin.path)")
                            }
                            Button { model.openInBrowser(project.id) } label: {
                                Label { Text(url.host.map { "\($0):\(url.port ?? 80)" } ?? url.absoluteString).font(.dMono) }
                                    icon: { Icon("arrow-up-right", size: 12) }
                            }
                            .buttonStyle(.dockSecondaryCompact)
                            .help("Open the site in your browser")
                        }
                        ForEach(extras) { badge in
                            HStack(spacing: 5) {
                                KindIcon(badge: badge, size: 12)
                                Text(badge.name)
                            }
                            .font(.dCaption).foregroundStyle(Brand.muted)
                        }
                    }
                }
                Spacer(minLength: Space.m)
                controls(project, rt)
            }

            HStack(alignment: .center) {
                TabBar(selection: Bindable(model).selectedTab)
                if rt.status.isActive, let bytes = rt.memoryBytes { MemoryBadge(bytes: bytes) }
            }
        }
        .padding(.horizontal, Space.xl)
        .padding(.top, Space.m)
        .background(Brand.background)
        .overlay(alignment: .bottom) { Rectangle().fill(Brand.border).frame(height: 1) }
    }

    /// State pill: icon and word on a soft tint of the state colour.
    private func statusLabel(_ rt: ProjectRuntime) -> some View {
        let (text, icon, color): (String, String, Color) = {
            switch rt.status {
            case .running: return ("Running", "zap", Brand.success)
            case .starting: return ("Starting", "clock", Brand.warning)
            case .stopped: return ("Stopped", "power", Brand.muted)
            case .error: return ("Error", "triangle-alert", Brand.danger)
            }
        }()
        return HStack(spacing: 5) {
            Icon(icon, size: 12)
            Text(text).font(.dCaption.weight(.medium))
        }
        .foregroundStyle(color)
        .padding(.horizontal, Space.s).frame(height: 22)
        .background(color.opacity(0.12), in: Capsule())
        .animation(.easeOut(duration: 0.2), value: text)
    }

    @ViewBuilder
    private func controls(_ project: Project, _ rt: ProjectRuntime) -> some View {
        HStack(spacing: Space.s) {
            if rt.status.isActive {
                Button { model.restart(project.id) } label: { Label { Text("Restart") } icon: { Icon("rotate-cw", size: IconSize.sm) } }
                    .buttonStyle(.dockSecondary)
                    .keyboardShortcut("r", modifiers: .command)
                    .help(rt.managed ? "Restart (⌘R)" : "Restart from \(AppInfo.name) so its logs are available (⌘R)")
                Button { model.stop(project.id) } label: { Label { Text("Stop") } icon: { Icon("square", size: 12) } }
                    .buttonStyle(.dockDanger)
                    .keyboardShortcut(".", modifiers: .command)
                    .help("Stop (⌘.)")
            } else {
                Button { model.start(project.id) } label: { Label { Text("Start") } icon: { Icon("play", size: IconSize.sm) } }
                    .buttonStyle(.dockPrimary)
                    .disabled(model.info(project.id) != nil && !model.depsReady(project))
                    .keyboardShortcut(.return, modifiers: .command)
                    .help(model.info(project.id) != nil && !model.depsReady(project) ? "Install dependencies first" : "Start (⌘↩)")
            }
            Menu {
                if rt.status == .running {
                    Button("Open Explorer in browser") { model.openExplorer(project.id) }
                    Divider()
                }
                Button("Reveal in Finder") { model.reveal(project.id) }
                Button("Open in \(model.settings.editorCommand.isEmpty ? (model.editorApp?.name ?? "Editor") : "Editor")") { model.openInEditor(project.id) }
                Button("Open in \(model.terminalApp?.name ?? "Terminal")") { model.openTerminal(project.id) }
            } label: {
                Icon("ellipsis-vertical", size: IconSize.sm)
            }
            .menuStyle(.button)
            .buttonStyle(DockIconButtonStyle(size: 28))
            .menuIndicator(.hidden)
            .fixedSize()
            .help("More")
        }
        .animation(.easeOut(duration: 0.2), value: rt.status)
    }
}

/// Flat tabs with a sliding underline.
struct TabBar: View {
    @Binding var selection: DetailTab
    @Namespace private var ns

    var body: some View {
        HStack(spacing: Space.xl) {
            ForEach(DetailTab.allCases) { tab in TabItem(tab: tab, selected: selection == tab, ns: ns) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) { selection = tab }
            } }
            Spacer()
        }
    }
}

private struct TabItem: View {
    let tab: DetailTab
    let selected: Bool
    let ns: Namespace.ID
    let action: () -> Void
    @State private var hover = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Icon(tab.icon, size: IconSize.sm)
                Text(tab.rawValue).font(.dBodyMedium)
            }
            .foregroundStyle(selected || hover ? Brand.text : Brand.muted)
            .padding(.vertical, Space.s)
            .overlay(alignment: .bottom) {
                if selected {
                    Rectangle().fill(Brand.accent).frame(height: 2)
                        .matchedGeometryEffect(id: "underline", in: ns)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hover = $0 }
        .animation(.easeOut(duration: 0.12), value: hover)
    }
}

func abbreviated(_ path: String) -> String {
    (path as NSString).abbreviatingWithTildeInPath
}

/// Memory used by the project, coloured by how heavy it is. Sits at the end of the tab row so it stays visible on every tab.
struct MemoryBadge: View {
    let bytes: UInt64

    private var mb: Double { Double(bytes) / 1_048_576 }
    private var color: Color {
        if mb < 400 { return Brand.success }
        if mb < 800 { return Brand.warning }
        return Brand.danger
    }

    var body: some View {
        HStack(spacing: 5) {
            Icon("memory-stick", size: IconSize.sm)
            Text(Format.bytes(bytes)).font(.dBodyMedium).monospacedDigit().contentTransition(.numericText())
        }
        .foregroundStyle(color)
        .padding(.horizontal, Space.s).frame(height: 24)
        .background(color.opacity(0.12), in: Capsule())
        .animation(.easeOut(duration: 0.3), value: color)
        .help("Memory used by this project, including workerd")
    }
}
