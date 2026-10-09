import SwiftUI

/// Memory (with a live line of the last few minutes) and uptime, for a running project.
struct LiveStats: View {
    let rt: ProjectRuntime

    var body: some View {
        Card(padding: Space.l) {
            HStack(alignment: .center, spacing: Space.xl) {
                stat("Memory") {
                    HStack(alignment: .center, spacing: Space.l) {
                        Text(rt.memoryBytes.map(Format.bytes) ?? "…")
                            .font(.system(size: 22, weight: .semibold)).monospacedDigit()
                            .contentTransition(.numericText())
                        if rt.memoryHistory.count > 1 {
                            Sparkline(values: rt.memoryHistory).frame(width: 140, height: 28)
                        }
                    }
                }
                Rectangle().fill(Brand.border).frame(width: 1, height: 36)
                stat("Uptime") {
                    TimelineView(.periodic(from: .now, by: 1)) { ctx in
                        Text(rt.startedAt.map { Self.format(ctx.date.timeIntervalSince($0)) } ?? "…")
                            .font(.system(size: 22, weight: .semibold)).monospacedDigit()
                    }
                }
                Spacer(minLength: 0)
            }
        }
        .help("Measured for the whole project, including workerd")
    }

    private func stat<Content: View>(_ label: String, @ViewBuilder _ value: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            Text(label).font(.dCaption).foregroundStyle(Brand.muted)
            value()
        }
    }

    static func format(_ seconds: TimeInterval) -> String {
        let s = max(0, Int(seconds))
        if s < 60 { return "\(s)s" }
        if s < 3600 { return "\(s / 60)m \(s % 60)s" }
        if s < 86400 { return "\(s / 3600)h \((s % 3600) / 60)m" }
        return "\(s / 86400)d \((s % 86400) / 3600)h"
    }
}

/// Thin line of recent values with a dot on the latest one.
private struct Sparkline: View {
    let values: [Double]

    var body: some View {
        Canvas { gc, size in
            guard let lo = values.min(), let hi = values.max() else { return }
            let range = max(hi - lo, hi * 0.02, 0.5)
            let pad: CGFloat = 3
            func point(_ i: Int) -> CGPoint {
                CGPoint(x: pad + (size.width - 2 * pad) * CGFloat(i) / CGFloat(max(1, values.count - 1)),
                        y: size.height - pad - (size.height - 2 * pad) * CGFloat((values[i] - lo) / range))
            }
            var path = Path()
            path.move(to: point(0))
            for i in 1..<values.count { path.addLine(to: point(i)) }
            gc.stroke(path, with: .color(Brand.muted), style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
            let last = point(values.count - 1)
            gc.fill(Path(ellipseIn: CGRect(x: last.x - 2.5, y: last.y - 2.5, width: 5, height: 5)), with: .color(Brand.success))
        }
        .animation(.easeOut(duration: 0.3), value: values.count)
    }
}
