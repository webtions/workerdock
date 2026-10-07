import SwiftUI

struct MainView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        NavigationSplitView {
            SidebarView()
                .navigationSplitViewColumnWidth(min: 210, ideal: 250, max: 340)
        } detail: {
            if let id = model.selection, model.project(id) != nil {
                ProjectDetailView(projectID: id)
                    .id(id)
            } else {
                EmptyStateView()
            }
        }
        .onAppear { model.windowVisibilityChanged(true) }
        .onDisappear { model.windowVisibilityChanged(false) }
    }
}

struct EmptyStateView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        ContentUnavailableView {
            Label("No projects yet", systemImage: "shippingbox")
        } description: {
            Text("Add a folder that contains your Wrangler projects (for example ~/Sites) and \(AppInfo.name) will find them.")
        } actions: {
            Button("Add Root Folder…") { addRoot(model) }
                .buttonStyle(.borderedProminent)
                .tint(.cfOrange)
            Button("Add Single Project…") { addProject(model) }
        }
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
        List(selection: $model.selection) {
            ForEach(model.visibleProjects) { project in
                SidebarRow(project: project)
                    .tag(project.id)
                    .contextMenu { SidebarContextMenu(project: project) }
            }
        }
        .listStyle(.sidebar)
        .overlay {
            if model.visibleProjects.isEmpty {
                Text("No projects").foregroundStyle(.secondary)
            }
        }
        .safeAreaInset(edge: .bottom) {
            if model.isScanning {
                HStack(spacing: 6) {
                    ProgressView().controlSize(.small)
                    Text("Scanning…").font(.caption).foregroundStyle(.secondary)
                }
                .padding(8)
            }
        }
        .toolbar {
            ToolbarItem {
                Menu {
                    Button("Add Root Folder…") { addRoot(model) }
                    Button("Add Single Project…") { addProject(model) }
                    Divider()
                    Button("Rescan Folders") { model.rescan() }
                    if model.hasHiddenProjects {
                        Toggle("Show Hidden Projects", isOn: $model.showHidden)
                    }
                } label: {
                    Label("Add", systemImage: "plus")
                }
            }
        }
    }
}

struct SidebarRow: View {
    @Environment(AppModel.self) private var model
    let project: Project

    var body: some View {
        let rt = model.runtime(project.id)
        HStack(spacing: 8) {
            StatusDot(status: rt.status)
            Text(project.name)
                .lineLimit(1)
                .foregroundStyle(project.hidden ? .secondary : .primary)
            Spacer(minLength: 4)
            if let port = rt.port ?? (rt.status.isActive ? project.port : nil) {
                Text(verbatim: ":\(port)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
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
