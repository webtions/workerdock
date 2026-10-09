import SwiftUI

/// Memory and how long the project has been running. Same layout as a stat row: icon, label, big value, caption.
struct LiveStats: View {
    let rt: ProjectRuntime

    var body: some View {
        Card(padding: Space.l) {
            HStack(alignment: .center, spacing: 0) {
                stat(icon: "memory-stick", label: "Memory",
                     value: rt.memoryBytes.map(Format.bytes) ?? "…",
                     caption: rt.memoryHistory.max().map { "Peak \(Format.bytes(UInt64($0 * 1_048_576)))" } ?? "Measuring…") {
                    if rt.memoryHistory.count > 1 { Sparkline(values: rt.memoryHistory).frame(width: 120, height: 32) }
                }
                Rectangle().fill(Brand.border).frame(width: 1, height: 52).padding(.horizontal, Space.xl)
                TimelineView(.periodic(from: .now, by: 1)) { ctx in
                    stat(icon: "clock", label: "Running for",
                         value: rt.startedAt.map { Self.format(ctx.date.timeIntervalSince($0)) } ?? "…",
                         caption: rt.startedAt.map(Self.since) ?? "") { EmptyView() }
                }
                Spacer(minLength: 0)
            }
        }
        .help("Measured for the whole project, including workerd")
    }

    private func stat<Accessory: View>(icon: String, label: String, value: String, caption: String,
                                       @ViewBuilder accessory: () -> Accessory) -> some View {
        HStack(alignment: .center, spacing: Space.m) {
            Icon(icon, size: IconSize.md).foregroundStyle(Brand.muted)
            VStack(alignment: .leading, spacing: 2) {
                Text(label).font(.dCaption).foregroundStyle(Brand.muted)
                Text(value).font(.system(size: 22, weight: .semibold)).monospacedDigit().contentTransition(.numericText())
                Text(caption).font(.dCaption).foregroundStyle(Brand.faint)
            }
            accessory().padding(.leading, Space.s)
        }
    }

    static func format(_ seconds: TimeInterval) -> String {
        let s = max(0, Int(seconds))
        if s < 60 { return "\(s)s" }
        if s < 3600 { return "\(s / 60)m \(s % 60)s" }
        if s < 86400 { return "\(s / 3600)h \((s % 3600) / 60)m" }
        return "\(s / 86400)d \((s % 86400) / 3600)h"
    }

    static func since(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = Calendar.current.isDateInToday(date) ? "HH:mm" : "MMM d, HH:mm"
        return "Since \(f.string(from: date))"
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
