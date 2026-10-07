import SwiftUI
import AppKit

struct MenuBarContent: View {
    @Environment(AppModel.self) private var model
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        let projects = model.visibleProjects
        if projects.isEmpty {
            Text("No projects yet")
        } else {
            ForEach(projects) { project in
                ProjectMenu(project: project)
            }
        }

        Divider()
        Button("Show Main Window") {
            openWindow(id: "main")
            NSApp.activate(ignoringOtherApps: true)
        }
        Button("Stop All") {
            Task {
                for p in model.projects where model.runtime(p.id).status.isActive { await model.stopAsync(p.id) }
            }
        }
        .disabled(model.runningCount == 0)
        Button("Rescan Folders") { model.rescan() }
        Divider()
        Button("Quit \(AppInfo.name)") { NSApp.terminate(nil) }
            .keyboardShortcut("q")
    }
}

struct ProjectMenu: View {
    @Environment(AppModel.self) private var model
    let project: Project

    var body: some View {
        let rt = model.runtime(project.id)
        let port = rt.port ?? (rt.status.isActive ? project.port : nil)
        let title = "\(rt.status == .running ? "●" : rt.status == .starting ? "◐" : "○")  \(project.name)" + (port.map { "  :\($0)" } ?? "")

        Menu(title) {
            Toggle("Running", isOn: Binding(
                get: { rt.status.isActive },
                set: { on in on ? model.start(project.id) : model.stop(project.id) }))
            Divider()
            Button("Open in Browser") { model.openInBrowser(project.id) }
                .disabled(rt.status != .running)
            Button("Open Explorer") { model.openExplorer(project.id) }
                .disabled(rt.status != .running)
        }
    }
}
