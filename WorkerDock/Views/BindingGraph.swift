import SwiftUI

/// Cloudflare-style bindings diagram: the Worker on the left, every binding on the right,
/// joined by curves that flow while the project is running.
struct BindingGraph: View {
    let workerName: String
    let entry: String?
    let bindings: [WorkerBinding]
    let varNames: [String]
    let status: ProjectStatus

    fileprivate struct Node: Identifiable {
        let id: String
        let icon: String
        let color: Color
        let title: String
        let subtitle: String?
        let tag: String
    }

    private let rowH: CGFloat = 54
    private let gap: CGFloat = 10
    private let workerH: CGFloat = 96

    private var running: Bool { status == .running }

    private var nodes: [Node] {
        var list = BindingKind.allCases.flatMap { kind in
            bindings.filter { $0.kind == kind }.map {
                Node(id: $0.id, icon: kind.lucide, color: Brand.kind(kind), title: $0.name, subtitle: $0.detail, tag: kind.shortTitle)
            }
        }
        if !varNames.isEmpty {
            list.append(Node(id: "vars", icon: "braces", color: Brand.muted, title: "Variables",
                             subtitle: varNames.prefix(4).joined(separator: ", ") + (varNames.count > 4 ? " +\(varNames.count - 4)" : ""),
                             tag: varNames.count == 1 ? "1 var" : "\(varNames.count) vars"))
        }
        return list
    }

    var body: some View {
        let items = nodes
        let n = items.count
        let contentH = CGFloat(n) * rowH + CGFloat(max(0, n - 1)) * gap
        let totalH = max(workerH, contentH)
        let offsetY = (totalH - contentH) / 2
        let midY = totalH / 2

        GeometryReader { geo in
            let w = geo.size.width
            let workerW = min(240, w * 0.36)
            let nodeW = min(380, w * 0.50)
            let workerRight = workerW
            let nodeLeft = w - nodeW

            ZStack(alignment: .topLeading) {
                TimelineView(.animation(minimumInterval: 1.0 / 24.0, paused: !running)) { ctx in
                    Canvas { gc, _ in
                        let phase = running ? CGFloat((ctx.date.timeIntervalSinceReferenceDate * 24).truncatingRemainder(dividingBy: 1000)) : 0
                        for (i, node) in items.enumerated() {
                            let y = offsetY + CGFloat(i) * (rowH + gap) + rowH / 2
                            let dx = nodeLeft - workerRight
                            var path = Path()
                            path.move(to: CGPoint(x: workerRight, y: midY))
                            path.addCurve(to: CGPoint(x: nodeLeft, y: y),
                                          control1: CGPoint(x: workerRight + dx * 0.55, y: midY),
                                          control2: CGPoint(x: nodeLeft - dx * 0.55, y: y))
                            let shading = GraphicsContext.Shading.linearGradient(
                                Gradient(colors: [Brand.cloudflare.opacity(running ? 0.95 : 0.45), node.color.opacity(running ? 1 : 0.55)]),
                                startPoint: CGPoint(x: workerRight, y: midY), endPoint: CGPoint(x: nodeLeft, y: y))
                            gc.stroke(path, with: shading,
                                      style: StrokeStyle(lineWidth: 1.7, lineCap: .round, dash: running ? [6, 5] : [], dashPhase: -phase))
                            gc.fill(Path(ellipseIn: CGRect(x: workerRight - 3.5, y: midY - 3.5, width: 7, height: 7)), with: .color(Brand.cloudflare))
                            gc.fill(Path(ellipseIn: CGRect(x: nodeLeft - 3.5, y: y - 3.5, width: 7, height: 7)), with: .color(node.color))
                        }
                    }
                }

                workerCard
                    .frame(width: workerW, height: workerH)
                    .offset(x: 0, y: midY - workerH / 2)

                VStack(spacing: gap) {
                    ForEach(items) { node in nodeCard(node) }
                }
                .frame(width: nodeW)
                .offset(x: nodeLeft, y: offsetY)
            }
        }
        .frame(height: totalH)
    }

    private var workerCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: Space.s) {
                Icon("cloud", size: IconSize.lg).foregroundStyle(Brand.cloudflare)
                VStack(alignment: .leading, spacing: 1) {
                    Text(workerName).font(.dBodyMedium).lineLimit(1)
                    Text("Worker").font(.dCaption).foregroundStyle(Brand.muted)
                }
            }
            if let entry {
                Text(entry).font(.dMono).foregroundStyle(Brand.muted).lineLimit(1).truncationMode(.middle)
            }
        }
        .padding(Space.m)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(Brand.cardRaised, in: RoundedRectangle(cornerRadius: Radius.panel, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Radius.panel, style: .continuous).strokeBorder(Brand.cloudflare.opacity(running ? 0.7 : 0.3), lineWidth: 1.2))
        .animation(.easeOut(duration: 0.3), value: running)
    }

    private func nodeCard(_ node: Node) -> some View {
        NodeCard(node: node, height: rowH)
    }
}

private struct NodeCard: View {
    let node: BindingGraph.Node
    let height: CGFloat
    @State private var hover = false

    var body: some View {
        HStack(spacing: Space.m) {
            Icon(node.icon, size: IconSize.md).foregroundStyle(node.color).frame(width: IconSize.md)
            VStack(alignment: .leading, spacing: 1) {
                Text(node.title).font(.system(size: 12, weight: .medium, design: .monospaced)).lineLimit(1)
                if let sub = node.subtitle {
                    Text(sub).font(.dCaption).foregroundStyle(Brand.muted).lineLimit(1)
                }
            }
            Spacer(minLength: Space.s)
            Text(node.tag).font(.dCaption).foregroundStyle(Brand.muted)
        }
        .padding(.horizontal, Space.m)
        .frame(height: height)
        .background(hover ? Brand.hover : Brand.cardRaised, in: RoundedRectangle(cornerRadius: Radius.panel, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Radius.panel, style: .continuous).strokeBorder(hover ? node.color.opacity(0.6) : Brand.border, lineWidth: 1))
        .onHover { hover = $0 }
        .animation(.easeOut(duration: 0.15), value: hover)
    }
}
