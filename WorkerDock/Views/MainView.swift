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
        .toolbarBackground(.hidden, for: .windowToolbar)
        .onAppear { model.windowVisibilityChanged(true) }
        .onDisappear { model.windowVisibilityChanged(false) }
    }
}

struct EmptyStateView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(spacing: 18) {
            ZStack {
                RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Brand.accentSoft)
                Icon("cloud", size: 34).foregroundStyle(Brand.accent)
            }
            .frame(width: 76, height: 76)
            VStack(spacing: 6) {
                Text("Add your Workers").font(.system(size: 22, weight: .bold, design: .rounded))
                Text("Choose a folder that contains your Wrangler projects, for example ~/Sites.\n\(AppInfo.name) finds them all and keeps them in one place.")
                    .multilineTextAlignment(.center).foregroundStyle(Brand.muted)
            }
            HStack {
                Button { addRoot(model) } label: { Label { Text("Add Root Folder") } icon: { Icon("folder-plus", size: 14) } }
                    .buttonStyle(.dockPrimary)
                Button { addProject(model) } label: { Label { Text("Add Single Project") } icon: { Icon("plus", size: 14) } }
                    .buttonStyle(.dockSecondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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

    var body: some View {
        @Bindable var model = model
        ScrollView {
            LazyVStack(spacing: 2) {
                ForEach(model.visibleProjects) { project in
                    SidebarRow(project: project, selected: model.selection == project.id)
                        .contextMenu { SidebarContextMenu(project: project) }
                }
            }
            .padding(.horizontal, 10)
            .padding(.bottom, 12)
        }
        .scrollContentBackground(.hidden)
        .background(Brand.sidebar)
        .focusable()
        .focusEffectDisabled()
        .onMoveCommand { direction in
            let ids = model.visibleProjects.map(\.id)
            guard !ids.isEmpty else { return }
            let current = model.selection.flatMap { ids.firstIndex(of: $0) } ?? -1
            switch direction {
            case .down: model.selection = ids[min(ids.count - 1, current + 1)]
            case .up: model.selection = ids[max(0, current - 1)]
            default: break
            }
        }
        .overlay {
            if model.visibleProjects.isEmpty {
                VStack(spacing: 8) {
                    Icon("folder-search", size: 24).foregroundStyle(Brand.faint)
                    Text("No projects").foregroundStyle(Brand.muted)
                }
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            HStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 7, style: .continuous).fill(Brand.accent.gradient)
                    Icon("cloud", size: 13).foregroundStyle(.white)
                }
                .frame(width: 24, height: 24)
                Text(AppInfo.name).font(.system(size: 14, weight: .bold, design: .rounded))
                Spacer()
                Text("\(model.visibleProjects.count)").font(.system(size: 11, weight: .semibold)).foregroundStyle(Brand.muted)
                    .padding(.horizontal, 7).padding(.vertical, 2).background(Brand.border.opacity(0.7), in: Capsule())
            }
            .padding(.horizontal, 16).padding(.top, 2).padding(.bottom, 8)
        }
        .safeAreaInset(edge: .bottom) {
            if model.isScanning {
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text("Scanning folders…").font(.caption).foregroundStyle(Brand.muted)
                }
                .padding(10)
            }
        }
        .toolbar {
            ToolbarItem {
                Menu {
                    Button { addRoot(model) } label: { Label("Add Root Folder…", systemImage: "folder.badge.plus") }
                    Button { addProject(model) } label: { Label("Add Single Project…", systemImage: "plus") }
                    Divider()
                    Button { model.rescan() } label: { Label("Rescan Folders", systemImage: "arrow.clockwise") }
                    if model.hasHiddenProjects {
                        Toggle("Show Hidden Projects", isOn: $model.showHidden)
                    }
                } label: {
                    Icon("plus", size: 15)
                }
            }
        }
    }
}

/// Icon that best represents a project's kind.
enum ProjectGlyph {
    static func icon(_ info: ProjectInfo?) -> String {
        guard let info else { return "cloud" }
        if info.cms == "EmDash" { return "file-text" }
        if info.framework == "Astro" { return "rocket" }
        if info.framework != nil { return "layout-dashboard" }
        if info.pagesOutputDir != nil { return "globe" }
        return "cloud"
    }
}

struct ProjectTile: View {
    let icon: String
    let status: ProjectStatus
    var size: CGFloat = 32

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
                .fill(status == .running ? Brand.accent.opacity(0.14) : Brand.border.opacity(0.55))
            Icon(icon, size: size * 0.5).foregroundStyle(status == .running ? Brand.accent : Brand.muted)
        }
        .frame(width: size, height: size)
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
        HStack(spacing: 10) {
            ProjectTile(icon: ProjectGlyph.icon(info), status: rt.status)
            VStack(alignment: .leading, spacing: 1) {
                Text(model.displayName(project))
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .foregroundStyle(project.hidden ? Brand.muted : Brand.text)
                Text(subtitle(rt, info))
                    .font(.system(size: 11)).foregroundStyle(Brand.muted).lineLimit(1)
            }
            Spacer(minLength: 4)
            StatusDot(status: rt.status, size: 7)
        }
        .padding(.horizontal, 10).padding(.vertical, 7)
        .background {
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(selected ? Brand.card : (hover ? Brand.border.opacity(0.45) : .clear))
                .shadow(color: .black.opacity(selected ? 0.07 : 0), radius: 4, y: 1)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .strokeBorder(selected ? Brand.border : .clear, lineWidth: 1)
        }
        .overlay(alignment: .leading) {
            if selected {
                Capsule().fill(Brand.accent).frame(width: 3, height: 18).offset(x: -1)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { model.selection = project.id }
        .onHover { hover = $0 }
        .animation(.easeOut(duration: 0.12), value: selected)
    }

    private func subtitle(_ rt: ProjectRuntime, _ info: ProjectInfo?) -> String {
        if let port = rt.port, rt.status == .running { return "localhost:\(port)" }
        switch rt.status {
        case .starting: return "Starting…"
        case .error: return "Failed to start"
        default: return info?.framework ?? (info?.pagesOutputDir != nil ? "Pages" : "Worker")
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
