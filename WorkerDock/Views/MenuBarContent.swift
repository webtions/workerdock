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
            // Running projects first, then the rest, each group alphabetical.
            let running = projects.filter { model.runtime($0.id).status.isActive }
            let others = projects.filter { !model.runtime($0.id).status.isActive }
            ForEach(running) { ProjectMenu(project: $0) }
            if !running.isEmpty && !others.isEmpty { Divider() }
            ForEach(others) { ProjectMenu(project: $0) }
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
    @Environment(\.openWindow) private var openWindow
    let project: Project

    var body: some View {
        let rt = model.runtime(project.id)
        let port = rt.port ?? (rt.status.isActive ? project.port : nil)
        let title = "\(rt.status == .running ? "●" : rt.status == .starting ? "◐" : "○")  \(project.name)" + (port.map { "  :\($0)" } ?? "")

        Menu(title) {
            if rt.status.isActive {
                Button("Stop") { model.stop(project.id) }
                Button("Restart") { model.restart(project.id) }
            } else {
                Button("Start") { model.start(project.id) }
            }
            Divider()
            Button("Open in Browser") { model.openInBrowser(project.id) }
                .disabled(rt.status != .running)
            Button("Open Explorer") { model.openExplorer(project.id) }
                .disabled(rt.status != .running)
            ForEach(model.quickLinks(project.id).filter { $0 != .site }) { link in
                Button(link.title) { model.open(link, for: project.id) }
                    .disabled(rt.status != .running)
            }
            Divider()
            Button("Show in WorkerDock") {
                model.selection = project.id
                openWindow(id: "main")
                NSApp.activate(ignoringOtherApps: true)
            }
        }
    }
}
