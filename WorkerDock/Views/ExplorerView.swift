import SwiftUI
import WebKit

struct ExplorerView: View {
    @Environment(AppModel.self) private var model
    let project: Project
    @State private var reloadToken = 0

    var body: some View {
        let rt = model.runtime(project.id)
        let mode = model.effectiveMode(project)
        let support = model.info(project.id).map { ExplorerSupport.evaluate(info: $0, mode: mode) } ?? .ok

        if rt.status != .running || rt.explorerURL == nil {
            ContentUnavailableView {
                Label("Explorer is available while running", systemImage: "cylinder.split.1x2")
            } description: {
                Text("Start the project to browse its local D1, KV, R2, Durable Object and Workflow data.")
            } actions: {
                if !rt.status.isActive {
                    Button("Start") { model.start(project.id) }
                        .buttonStyle(.borderedProminent).tint(.cfOrange)
                }
            }
        } else if case .tooOld(let package, let installed, let required, let command) = support {
            VStack(spacing: 14) {
                Image(systemName: "arrow.up.circle").font(.system(size: 38)).foregroundStyle(.secondary)
                Text("Local Explorer needs a newer \(package)").font(.title3.weight(.semibold))
                Text("This project has \(package) \(installed). Local Explorer requires \(required) or newer.")
                    .foregroundStyle(.secondary)
                HStack {
                    Text(command).font(.body.monospaced()).textSelection(.enabled)
                    Button("Copy") { copyToPasteboard(command) }
                }
                .padding(10)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
                Text("Run it in \(abbreviated(project.path)), then restart the project.")
                    .font(.callout).foregroundStyle(.secondary)
            }
            .padding(30)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let url = rt.explorerURL {
            VStack(spacing: 0) {
                HStack {
                    Text(url.absoluteString).font(.caption.monospaced()).foregroundStyle(.secondary)
                    Spacer()
                    Button { reloadToken += 1 } label: { Label("Reload", systemImage: "arrow.clockwise") }
                        .buttonStyle(.borderless)
                    Button { model.openExplorer(project.id) } label: { Label("Open in Browser", systemImage: "arrow.up.right.square") }
                        .buttonStyle(.borderless)
                }
                .padding(.horizontal, 14).padding(.vertical, 6)
                Divider()
                // The web view only exists while this tab is on screen and the project is running.
                ExplorerWebView(url: url).id("\(url.absoluteString)#\(reloadToken)")
            }
        }
    }
}

struct ExplorerWebView: NSViewRepresentable {
    let url: URL

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .nonPersistent()
        let view = WKWebView(frame: .zero, configuration: config)
        view.setValue(false, forKey: "drawsBackground")
        view.load(URLRequest(url: url))
        return view
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {}

    static func dismantleNSView(_ nsView: WKWebView, coordinator: ()) {
        nsView.stopLoading()
    }
}
