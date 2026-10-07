import SwiftUI

enum DetailTab: String, CaseIterable, Identifiable {
    case overview = "Overview", logs = "Logs", explorer = "Explorer", actions = "Actions"
    var id: String { rawValue }
}

struct ProjectDetailView: View {
    @Environment(AppModel.self) private var model
    let projectID: String
    @State private var tab: DetailTab = .overview

    var body: some View {
        if let project = model.project(projectID) {
            let rt = model.runtime(projectID)
            VStack(spacing: 0) {
                header(project, rt)
                Divider()
                Group {
                    switch tab {
                    case .overview: OverviewView(project: project)
                    case .logs: LogsView(project: project)
                    case .explorer: ExplorerView(project: project)
                    case .actions: ActionsView(project: project)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .navigationTitle(project.name)
            .navigationSubtitle(rt.status.label)
            .task { await model.refreshInfo(projectID) }
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Picker("Tab", selection: $tab) {
                        ForEach(DetailTab.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 330)
                }
                ToolbarItemGroup {
                    controls(project, rt)
                }
            }
        }
    }

    private func header(_ project: Project, _ rt: ProjectRuntime) -> some View {
        HStack(spacing: 10) {
            StatusDot(status: rt.status)
            VStack(alignment: .leading, spacing: 2) {
                Text(project.name).font(.title3.weight(.semibold))
                Text(abbreviated(project.path))
                    .font(.caption).foregroundStyle(.secondary)
                    .lineLimit(1).truncationMode(.middle)
            }
            Spacer()
            if rt.status == .running, rt.url != nil, let admin = model.quickLinks(project.id).first(where: { $0 != .site }) {
                Button { model.open(admin, for: project.id) } label: { Label(admin.title, systemImage: admin.symbol) }
                    .buttonStyle(.bordered)
            }
            if let url = rt.url, rt.status == .running {
                Button {
                    model.openInBrowser(project.id)
                } label: {
                    Label(url.absoluteString, systemImage: "arrow.up.right.square")
                        .font(.callout.monospaced())
                }
                .buttonStyle(.link)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }

    @ViewBuilder
    private func controls(_ project: Project, _ rt: ProjectRuntime) -> some View {
        if rt.status.isActive {
            Button { model.restart(project.id) } label: { Label("Restart", systemImage: "arrow.clockwise") }
                .disabled(!rt.managed)
                .help("Restart (⌘R)")
            Button { model.stop(project.id) } label: { Label("Stop", systemImage: "stop.fill") }
                .help("Stop (⌘.)")
        } else {
            Button { model.start(project.id) } label: { Label("Start", systemImage: "play.fill") }
                .disabled(rt.installing)
                .help("Start (⌘↩)")
        }
    }
}

func abbreviated(_ path: String) -> String {
    (path as NSString).abbreviatingWithTildeInPath
}
