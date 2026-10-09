import SwiftUI

struct MainView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        NavigationSplitView {
            SidebarView()
                .navigationSplitViewColumnWidth(min: 230, ideal: 270, max: 340)
        } detail: {
            Group {
                if let id = model.selection, model.project(id) != nil {
                    ProjectDetailView(projectID: id)
                        .id(id)
                } else {
                    EmptyStateView()
                }
            }
            .background(Brand.background)
        }
        .tint(Brand.accent)
        .focusEffectDisabled()
        .toolbarBackground(.hidden, for: .windowToolbar)
        .onAppear { model.windowVisibilityChanged(true) }
        .onDisappear { model.windowVisibilityChanged(false) }
    }
}

struct EmptyStateView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(spacing: Space.l) {
            Icon("cloud", size: IconSize.xl).foregroundStyle(Brand.accent)
            VStack(spacing: Space.xs) {
                Text("Add your Workers").font(.dTitle)
                Text("Choose a folder that contains your Wrangler projects, for example ~/Sites.\n\(AppInfo.name) finds them all and keeps them in one place.")
                    .font(.dBody).multilineTextAlignment(.center).foregroundStyle(Brand.muted)
            }
            HStack(spacing: Space.s) {
                Button { addRoot(model) } label: { Label { Text("Add Root Folder") } icon: { Icon("folder-plus", size: IconSize.sm) } }
                    .buttonStyle(.dockPrimary)
                Button { addProject(model) } label: { Label { Text("Add Single Project") } icon: { Icon("plus", size: IconSize.sm) } }
                    .buttonStyle(.dockSecondary)
            }
            VStack(alignment: .leading, spacing: Space.s) {
                trustRow("eye", "Reads your project folders to find wrangler configs.")
                trustRow("shield-check", "Never changes your files, and never installs anything.")
                trustRow("cloud", "Everything stays on your Mac.")
                trustRow("folder-open", "macOS may ask to allow access to folders like Documents. Choose Allow.")
            }
            .padding(.top, Space.s)
        }
        .appearIn()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private func trustRow(_ icon: String, _ text: String) -> some View {
    HStack(spacing: Space.s) {
        Icon(icon, size: IconSize.sm).foregroundStyle(Brand.muted).frame(width: IconSize.sm)
        Text(text).font(.dCaption).foregroundStyle(Brand.muted)
    }
}

@MainActor func addRoot(_ model: AppModel) {
    if let path = chooseFolder(prompt: "Add Folder", message: "Choose a folder to scan for Wrangler projects") {
        model.addRoot(path)
    }
}

@MainActor func addProject(_ model: AppModel) {
    if let path = chooseFolder(prompt: "Add Project", message: "Choose a project folder containing a wrangler config"),
       let error = model.addProjectFolder(path) {
        showError(error)
    }
}

// MARK: - Sidebar

struct SidebarView: View {
    @Environment(AppModel.self) private var model
    @State private var query = ""
    @FocusState private var searchFocused: Bool

    private var filtered: [Project] {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return model.visibleProjects }
        return model.visibleProjects.filter { model.displayName($0).localizedCaseInsensitiveContains(q) }
    }

    var body: some View {
        @Bindable var model = model
        let projects = filtered
        let running = projects.filter { model.runtime($0.id).status.isActive }
        let others = projects.filter { !model.runtime($0.id).status.isActive }

        ScrollView {
            LazyVStack(alignment: .leading, spacing: 2) {
                if !running.isEmpty {
                    sectionHeader("Running", count: running.count)
                    ForEach(running) { row($0) }
                }
                if !others.isEmpty {
                    sectionHeader(running.isEmpty ? "Projects" : "Stopped", count: others.count)
                    ForEach(others) { row($0) }
                }
            }
            .padding(.horizontal, Space.s)
            .padding(.bottom, Space.m)
            .animation(.easeOut(duration: 0.2), value: running.map(\.id))
        }
        .scrollContentBackground(.hidden)
        .background(Brand.sidebar)
        .focusable()
        .focusEffectDisabled()
        .onMoveCommand { direction in
            let ids = (running + others).map(\.id)
            guard !ids.isEmpty else { return }
            let current = model.selection.flatMap { ids.firstIndex(of: $0) } ?? -1
            switch direction {
            case .down: model.selection = ids[min(ids.count - 1, current + 1)]
            case .up: model.selection = ids[max(0, current - 1)]
            default: break
            }
        }
        .overlay {
            if projects.isEmpty {
                VStack(spacing: Space.s) {
                    Icon("folder-search", size: IconSize.lg).foregroundStyle(Brand.faint)
                    Text(query.isEmpty ? "No projects" : "No matches").font(.dBody).foregroundStyle(Brand.muted)
                }
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) { searchField }
        .safeAreaInset(edge: .bottom, spacing: 0) { footer }
    }

    /// Add and Settings live together at the bottom of the sidebar, like Xcode and Finder.
    private var footer: some View {
        @Bindable var model = model
        return HStack(spacing: Space.xs) {
            Menu {
                Button { addRoot(model) } label: { Label("Add Root Folder…", systemImage: "folder.badge.plus") }
                Button { addProject(model) } label: { Label("Add Single Project…", systemImage: "plus") }
                Divider()
                Button { model.rescan() } label: { Label("Rescan Folders", systemImage: "arrow.clockwise") }
                if model.hasHiddenProjects {
                    Toggle("Show Hidden Projects", isOn: $model.showHidden)
                }
            } label: {
                Icon("plus", size: IconSize.md)
            }
            .menuStyle(.button)
            .buttonStyle(DockIconButtonStyle(size: 28))
            .menuIndicator(.hidden)
            .fixedSize()
            .help("Add project or folder")

            if model.isScanning {
                ProgressView().controlSize(.small).padding(.leading, Space.xs)
                Text("Scanning…").font(.dCaption).foregroundStyle(Brand.muted)
            }
            Spacer()
            SettingsLink { Icon("settings", size: IconSize.md) }
                .buttonStyle(DockIconButtonStyle(size: 28))
                .help("Settings (⌘,)")
        }
        .padding(.horizontal, Space.s).padding(.vertical, Space.xs)
        .background(Brand.sidebar)
        .overlay(alignment: .top) { Rectangle().fill(Brand.border).frame(height: 1) }
    }

    private var searchField: some View {
        HStack(spacing: Space.s) {
            Icon("search", size: IconSize.sm).foregroundStyle(Brand.faint)
            TextField("Search", text: $query).textFieldStyle(.plain).font(.dBody).focused($searchFocused)
            if !query.isEmpty {
                Button { query = "" } label: { Icon("x", size: 12) }.buttonStyle(.plain).foregroundStyle(Brand.faint)
            }
        }
        .padding(.horizontal, Space.m).frame(height: 30)
        .overlay(RoundedRectangle(cornerRadius: Radius.control, style: .continuous)
            .strokeBorder(searchFocused ? Brand.accent.opacity(0.6) : Brand.border, lineWidth: 1))
        .animation(.easeOut(duration: 0.15), value: searchFocused)
        .padding(.horizontal, Space.m).padding(.bottom, Space.s)
    }

    private func sectionHeader(_ title: String, count: Int) -> some View {
        HStack {
            Text(title).font(.dLabel).textCase(.uppercase).tracking(0.6)
            Spacer()
            Text("\(count)").font(.dLabel).monospacedDigit().contentTransition(.numericText())
        }
        .foregroundStyle(Brand.faint)
        .padding(.horizontal, Space.m).padding(.top, Space.m).padding(.bottom, Space.xs)
    }

    private func row(_ project: Project) -> some View {
        SidebarRow(project: project, selected: model.selection == project.id)
            .contextMenu { SidebarContextMenu(project: project) }
            .transition(.opacity)
    }
}

struct SidebarRow: View {
    @Environment(AppModel.self) private var model
    let project: Project
    let selected: Bool
    @State private var hover = false

    var body: some View {
        let rt = model.runtime(project.id)
        let info = model.info(project.id)
        let active = rt.status.isActive
        HStack(spacing: Space.m) {
            KindIcon(badge: ProjectKind.primary(info), size: IconSize.md)
                .foregroundStyle(project.hidden ? Brand.faint : (active ? Brand.text : Brand.muted))
                .frame(width: IconSize.md)
            VStack(alignment: .leading, spacing: 1) {
                Text(model.displayName(project))
                    .font(.dBodyMedium)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .foregroundStyle(project.hidden ? Brand.muted : Brand.text)
                Text(subtitle(rt, info))
                    .font(.dCaption).foregroundStyle(Brand.muted).lineLimit(1)
            }
            Spacer(minLength: Space.xs)
            ZStack {
                if hover && rt.status != .starting {
                    Button { active ? model.stop(project.id) : model.start(project.id) } label: {
                        Icon(active ? "square" : "play", size: 12)
                    }
                    .buttonStyle(DockIconButtonStyle(size: 22))
                    .help(active ? "Stop" : "Start")
                    .transition(.opacity)
                } else {
                    StatusDot(status: rt.status, size: 7).transition(.opacity)
                }
            }
            .frame(width: 22, height: 22)
        }
        .padding(.horizontal, Space.m).padding(.vertical, 6)
        .hoverFill(radius: Radius.control, selected: selected)
        .contentShape(Rectangle())
        .onTapGesture { model.selection = project.id }
        .onHover { hover = $0 }
        .animation(.easeOut(duration: 0.12), value: hover)
    }

    private func subtitle(_ rt: ProjectRuntime, _ info: ProjectInfo?) -> String {
        if let port = rt.port, rt.status == .running { return "localhost:\(port)" }
        switch rt.status {
        case .starting: return "Starting…"
        case .error: return "Failed to start"
        default: return ProjectKind.primary(info).name
        }
    }
}

struct SidebarContextMenu: View {
    @Environment(AppModel.self) private var model
    let project: Project

    var body: some View {
        let active = model.runtime(project.id).status.isActive
        Button(active ? "Stop" : "Start") { active ? model.stop(project.id) : model.start(project.id) }
        Button("Reveal in Finder") { model.reveal(project.id) }
        Divider()
        Button(project.hidden ? "Show Project" : "Hide Project") { model.setHidden(project.id, !project.hidden) }
        if project.rootPath == nil {
            Button("Remove Project", role: .destructive) { model.removeManual(project.id) }
        }
    }
}
