import SwiftUI

/// Node canvas: the Worker on the left, every binding on the right, joined by curves.
/// While the project runs, small pulses travel from the Worker out to each binding.
/// Hovering a binding lights up its connection and dims the rest.
struct BindingGraph: View {
    let workerName: String
    let entry: String?
    let bindings: [WorkerBinding]
    let varNames: [String]
    let status: ProjectStatus
    let configFile: String
    let onOpenConfig: () -> Void

    @State private var hovered: String?

    private let rowH: CGFloat = 52
    private let gap: CGFloat = 10
    private let workerH: CGFloat = 132
    private let inset: CGFloat = Space.xl

    private var running: Bool { status == .running }

    var body: some View {
        let items = BindingItem.items(bindings: bindings, varNames: varNames)
        let n = items.count
        let contentH = CGFloat(n) * rowH + CGFloat(max(0, n - 1)) * gap
        let totalH = max(workerH, contentH)
        let offsetY = (totalH - contentH) / 2
        let midY = totalH / 2
        let panelShape = RoundedRectangle(cornerRadius: Radius.panel, style: .continuous)

        GeometryReader { geo in
            let w = geo.size.width
            let workerW = min(230, w * 0.34)
            let nodeW = min(340, w * 0.48)
            let workerRight = workerW
            let nodeLeft = w - nodeW

            ZStack(alignment: .topLeading) {
                TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: !running)) { ctx in
                    let time = ctx.date.timeIntervalSinceReferenceDate
                    Canvas { gc, _ in
                        for (i, node) in items.enumerated() {
                            let y = offsetY + CGFloat(i) * (rowH + gap) + rowH / 2
                            let p0 = CGPoint(x: workerRight, y: midY)
                            let p3 = CGPoint(x: nodeLeft, y: y)
                            let dx = p3.x - p0.x
                            let p1 = CGPoint(x: p0.x + dx * 0.55, y: p0.y)
                            let p2 = CGPoint(x: p3.x - dx * 0.55, y: p3.y)
                            let isHot = hovered == node.id
                            let dim = hovered != nil && !isHot
                            let alpha = dim ? 0.15 : (isHot ? 1 : (running ? 0.8 : 0.6))

                            var path = Path()
                            path.move(to: p0)
                            path.addCurve(to: p3, control1: p1, control2: p2)
                            gc.stroke(path, with: .color(node.color.opacity(alpha)),
                                      style: StrokeStyle(lineWidth: isHot ? 2.2 : 1.6, lineCap: .round))

                            if running && !dim {
                                for k in 0..<2 {
                                    let base = (time * 0.32 + Double(i) * 0.13 + Double(k) * 0.5).truncatingRemainder(dividingBy: 1)
                                    for trail in 0..<5 {
                                        let t = base - Double(trail) * 0.012
                                        guard t > 0 else { continue }
                                        let pt = Self.bezier(p0, p1, p2, p3, CGFloat(t))
                                        let r = 2.6 - CGFloat(trail) * 0.4
                                        gc.fill(Path(ellipseIn: CGRect(x: pt.x - r, y: pt.y - r, width: r * 2, height: r * 2)),
                                                with: .color(node.color.opacity(1 - Double(trail) * 0.2)))
                                    }
                                }
                            }

                            // Port on the binding side: hollow at rest, filled when hovered.
                            let port = CGRect(x: p3.x - 4, y: p3.y - 4, width: 8, height: 8)
                            gc.fill(Path(ellipseIn: port), with: .color(Brand.card))
                            gc.stroke(Path(ellipseIn: port), with: .color(node.color.opacity(dim ? 0.3 : 1)), lineWidth: 1.5)
                            if isHot { gc.fill(Path(ellipseIn: port.insetBy(dx: 2, dy: 2)), with: .color(node.color)) }
                        }
                        let hub = CGRect(x: workerRight - 4, y: midY - 4, width: 8, height: 8)
                        gc.fill(Path(ellipseIn: hub), with: .color(Brand.cloudflare))
                    }
                }
                .animation(.easeOut(duration: 0.15), value: hovered)

                workerCard
                    .frame(width: workerW, height: workerH)
                    .offset(x: 0, y: midY - workerH / 2)

                VStack(spacing: gap) {
                    ForEach(Array(items.enumerated()), id: \.element.id) { i, node in
                        NodeCard(node: node, height: rowH, hovered: $hovered)
                            .appearIn(Double(i) * 0.04)
                    }
                }
                .frame(width: nodeW)
                .offset(x: nodeLeft, y: offsetY)
            }
        }
        .frame(maxWidth: 760)
        .frame(height: totalH)
        .frame(maxWidth: .infinity)
        .padding(inset)
        .background {
            ZStack {
                Brand.card
                DotGrid()
            }
            .clipShape(panelShape)
        }
        .overlay(panelShape.strokeBorder(Brand.border, lineWidth: 1))
    }

    private var workerCard: some View {
        VStack(alignment: .leading, spacing: Space.s) {
            HStack(spacing: Space.s) {
                Icon("cloud", size: IconSize.lg).foregroundStyle(Brand.cloudflare)
                VStack(alignment: .leading, spacing: 1) {
                    Text(workerName).font(.dBodyMedium).lineLimit(1)
                    Text("Worker").font(.dCaption).foregroundStyle(Brand.muted)
                }
            }
            if let entry {
                Text(entry).font(.dMono).foregroundStyle(Brand.muted).lineLimit(1).truncationMode(.head)
            }
            Spacer(minLength: 0)
            Divider().overlay(Brand.borderSoft)
            ConfigRow(file: configFile, action: onOpenConfig)
        }
        .padding(Space.m)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(Brand.cardRaised, in: RoundedRectangle(cornerRadius: Radius.panel, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Radius.panel, style: .continuous)
            .strokeBorder(Brand.cloudflare.opacity(running ? 0.8 : 0.35), lineWidth: 1))
        .animation(.easeOut(duration: 0.3), value: running)
    }

    private static func bezier(_ a: CGPoint, _ b: CGPoint, _ c: CGPoint, _ d: CGPoint, _ t: CGFloat) -> CGPoint {
        let u = 1 - t
        let x = u * u * u * a.x + 3 * u * u * t * b.x + 3 * u * t * t * c.x + t * t * t * d.x
        let y = u * u * u * a.y + 3 * u * u * t * b.y + 3 * u * t * t * c.y + t * t * t * d.y
        return CGPoint(x: x, y: y)
    }
}

/// Faint dot grid behind the canvas.
private struct DotGrid: View {
    var body: some View {
        Canvas { gc, size in
            let step: CGFloat = 18
            var y: CGFloat = step / 2
            while y < size.height {
                var x: CGFloat = step / 2
                while x < size.width {
                    gc.fill(Path(ellipseIn: CGRect(x: x - 0.9, y: y - 0.9, width: 1.8, height: 1.8)), with: .color(Brand.text.opacity(0.16)))
                    x += step
                }
                y += step
            }
        }
        .allowsHitTesting(false)
    }
}

private struct NodeCard: View {
    let node: BindingItem
    let height: CGFloat
    @Binding var hovered: String?

    private var hot: Bool { hovered == node.id }

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
            Text(node.tag).font(.dCaption).foregroundStyle(hot ? node.color : Brand.muted)
            BindingMenu(item: node)
        }
        .padding(.leading, Space.m).padding(.trailing, Space.s)
        .frame(height: height)
        .background(Brand.cardRaised, in: RoundedRectangle(cornerRadius: Radius.panel, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Radius.panel, style: .continuous)
            .strokeBorder(hot ? node.color.opacity(0.8) : Brand.border, lineWidth: 1))
        .offset(x: hot ? -2 : 0)
        .contentShape(Rectangle())
        .onHover { inside in hovered = inside ? node.id : (hovered == node.id ? nil : hovered) }
        .animation(.easeOut(duration: 0.15), value: hot)
    }
}

/// Opens the project's wrangler config in the chosen editor.
private struct ConfigRow: View {
    let file: String
    let action: () -> Void
    @State private var hover = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: Space.s) {
                Icon("file-text", size: IconSize.sm).foregroundStyle(Brand.muted)
                Text(file).font(.dMono).lineLimit(1)
                Spacer(minLength: Space.xs)
                Icon("chevron-right", size: IconSize.sm).foregroundStyle(hover ? Brand.text : Brand.faint)
                    .offset(x: hover ? 2 : 0)
            }
            .padding(.horizontal, Space.xs).frame(height: 26)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .hoverFill(radius: Radius.control)
        .onHover { hover = $0 }
        .animation(.easeOut(duration: 0.15), value: hover)
        .help("Open \(file) in your editor")
    }
}
