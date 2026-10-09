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

        Group {
            if rt.status != .running || rt.explorerURL == nil {
                centered {
                    Icon("compass", size: IconSize.xl).foregroundStyle(Brand.accent)
                    Text("Explorer is available while running").font(.dTitle)
                    Text("Start the project to browse its local D1, KV, R2, Durable Object and Workflow data.")
                        .font(.dBody).foregroundStyle(Brand.muted).multilineTextAlignment(.center).frame(maxWidth: 380)
                    if !rt.status.isActive {
                        Button { model.start(project.id) } label: { Label { Text("Start Project") } icon: { Icon("play", size: IconSize.sm) } }
                            .buttonStyle(.dockPrimary)
                    }
                }
            } else if case .tooOld(let package, let installed, let required, let command) = support {
                centered {
                    Icon("triangle-alert", size: IconSize.xl).foregroundStyle(Brand.warning)
                    Text("Local Explorer needs a newer \(package)").font(.dTitle)
                    Text("This project has \(package) \(installed). Local Explorer requires \(required) or newer.")
                        .font(.dBody).foregroundStyle(Brand.muted)
                    HStack(spacing: Space.m) {
                        Text(command).font(.dMono).textSelection(.enabled)
                        Button { copyToPasteboard(command) } label: { Label { Text("Copy") } icon: { Icon("copy", size: IconSize.sm) } }
                            .buttonStyle(.dockSecondary)
                    }
                    .padding(Space.m)
                    .background(Brand.codeBackground, in: RoundedRectangle(cornerRadius: Radius.panel, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: Radius.panel, style: .continuous).strokeBorder(Brand.border, lineWidth: 1))
                    Text("Run it in \(abbreviated(project.path)), then restart the project.")
                        .font(.dCaption).foregroundStyle(Brand.muted)
                }
            } else if let url = rt.explorerURL {
                VStack(spacing: Space.m) {
                    HStack(spacing: Space.s) {
                        HStack(spacing: Space.s) {
                            Icon("globe", size: IconSize.sm).foregroundStyle(Brand.faint)
                            Text(url.absoluteString).font(.dMono).foregroundStyle(Brand.muted).lineLimit(1)
                        }
                        .padding(.horizontal, Space.m).frame(height: 28)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .overlay(RoundedRectangle(cornerRadius: Radius.control, style: .continuous).strokeBorder(Brand.border, lineWidth: 1))
                        Button { reloadToken += 1 } label: { Label { Text("Reload") } icon: { Icon("refresh-cw", size: IconSize.sm) } }
                            .buttonStyle(.dockSecondary)
                        Button { model.openExplorer(project.id) } label: { Label { Text("Open in Browser") } icon: { Icon("arrow-up-right", size: IconSize.sm) } }
                            .buttonStyle(.dockSecondary)
                    }
                    // The web view only exists while this tab is on screen and the project is running.
                    ExplorerWebView(url: url).id("\(url.absoluteString)#\(reloadToken)")
                        .clipShape(RoundedRectangle(cornerRadius: Radius.panel, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: Radius.panel, style: .continuous).strokeBorder(Brand.border, lineWidth: 1))
                }
                .padding(Space.xl)
            }
        }
    }

    private func centered<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(spacing: Space.m) { content() }
            .padding(Space.xl)
            .appearIn()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
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
