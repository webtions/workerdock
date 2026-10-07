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
                    iconTile("compass", Brand.accent)
                    Text("Explorer is available while running").font(.system(size: 18, weight: .bold, design: .rounded))
                    Text("Start the project to browse its local D1, KV, R2, Durable Object and Workflow data.")
                        .foregroundStyle(Brand.muted).multilineTextAlignment(.center).frame(maxWidth: 380)
                    if !rt.status.isActive {
                        Button { model.start(project.id) } label: { Label { Text("Start Project") } icon: { Icon("play", size: 13) } }
                            .buttonStyle(.dockPrimary)
                    }
                }
            } else if case .tooOld(let package, let installed, let required, let command) = support {
                centered {
                    iconTile("circle-check", Brand.warning)
                    Text("Local Explorer needs a newer \(package)").font(.system(size: 18, weight: .bold, design: .rounded))
                    Text("This project has \(package) \(installed). Local Explorer requires \(required) or newer.")
                        .foregroundStyle(Brand.muted)
                    HStack(spacing: 12) {
                        Text(command).font(.system(size: 13, design: .monospaced)).textSelection(.enabled)
                        Button { copyToPasteboard(command) } label: { Label { Text("Copy") } icon: { Icon("copy", size: 12) } }
                            .buttonStyle(.dockSecondary)
                    }
                    .padding(12)
                    .background(Brand.codeBackground, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Brand.border, lineWidth: 1))
                    Text("Run it in \(abbreviated(project.path)), then restart the project.")
                        .font(.callout).foregroundStyle(Brand.muted)
                }
            } else if let url = rt.explorerURL {
                VStack(spacing: 12) {
                    HStack(spacing: 10) {
                        HStack(spacing: 8) {
                            Icon("globe", size: 13).foregroundStyle(Brand.faint)
                            Text(url.absoluteString).font(.system(size: 12, design: .monospaced)).foregroundStyle(Brand.muted).lineLimit(1)
                        }
                        .padding(.horizontal, 12).padding(.vertical, 8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Brand.card, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(Brand.border, lineWidth: 1))
                        Button { reloadToken += 1 } label: { Label { Text("Reload") } icon: { Icon("refresh-cw", size: 13) } }
                            .buttonStyle(.dockSecondary)
                        Button { model.openExplorer(project.id) } label: { Label { Text("Open in Browser") } icon: { Icon("arrow-up-right", size: 13) } }
                            .buttonStyle(.dockSecondary)
                    }
                    // The web view only exists while this tab is on screen and the project is running.
                    ExplorerWebView(url: url).id("\(url.absoluteString)#\(reloadToken)")
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Brand.border, lineWidth: 1))
                }
                .padding(24)
            }
        }
    }

    private func centered<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(spacing: 14) { content() }
            .padding(30)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func iconTile(_ icon: String, _ color: Color) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18, style: .continuous).fill(color.opacity(0.14))
            Icon(icon, size: 28).foregroundStyle(color)
        }
        .frame(width: 64, height: 64)
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
