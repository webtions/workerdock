import SwiftUI

struct LogsView: View {
    @Environment(AppModel.self) private var model
    let project: Project
    @State private var filter = ""
    @State private var autoScroll = true
    @FocusState private var searchFocused: Bool

    var body: some View {
        let rt = model.runtime(project.id)
        let all = rt.log.lines
        let lines = filter.isEmpty ? all : all.filter { $0.text.localizedCaseInsensitiveContains(filter) }

        VStack(spacing: 14) {
            HStack(spacing: 10) {
                HStack(spacing: 8) {
                    Icon("search", size: 14).foregroundStyle(Brand.faint)
                    TextField("Filter logs", text: $filter)
                        .textFieldStyle(.plain)
                        .focused($searchFocused)
                    if !filter.isEmpty {
                        Button { filter = "" } label: { Icon("x", size: 12).foregroundStyle(Brand.faint) }.buttonStyle(.plain)
                    }
                    // Hidden button gives ⌘F its shortcut.
                    Button("") { searchFocused = true }
                        .keyboardShortcut("f", modifiers: .command)
                        .opacity(0).frame(width: 0, height: 0)
                }
                .padding(.horizontal, 12).padding(.vertical, 8)
                .background(Brand.card, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(searchFocused ? Brand.accent.opacity(0.6) : Brand.border, lineWidth: 1))

                Text("\(lines.count) lines").font(.system(size: 12)).foregroundStyle(Brand.muted)

                Button { autoScroll.toggle() } label: {
                    Label { Text("Follow") } icon: { Icon("arrow-down-to-line", size: 13) }
                }
                .buttonStyle(DockToggleStyle(isOn: autoScroll))
                .help("Auto-scroll to the newest line")

                Button { rt.log.clear() } label: { Label { Text("Clear") } icon: { Icon("eraser", size: 13) } }
                    .buttonStyle(.dockSecondary)
            }

            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Brand.codeBackground)
                if rt.external && all.isEmpty {
                    placeholder("terminal", "Logs unavailable",
                                "This project was started outside \(AppInfo.name), so its output can't be captured. Stop it and start it from here to see logs.")
                } else if lines.isEmpty {
                    placeholder("scroll-text", all.isEmpty ? "No output yet" : "No matches", all.isEmpty ? "Start the project to see its output here." : "Nothing matches “\(filter)”.")
                } else {
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: 2) {
                                ForEach(lines) { line in
                                    LogRow(line: line).id(line.id)
                                }
                            }
                            .padding(14)
                        }
                        .onChange(of: lines.last?.id) { _, last in
                            if autoScroll, let last { proxy.scrollTo(last, anchor: .bottom) }
                        }
                        .onAppear {
                            if let last = lines.last?.id { proxy.scrollTo(last, anchor: .bottom) }
                        }
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Brand.border, lineWidth: 1))
        }
        .padding(24)
    }

    private func placeholder(_ icon: String, _ title: String, _ detail: String) -> some View {
        VStack(spacing: 10) {
            Icon(icon, size: 26).foregroundStyle(Brand.faint)
            Text(title).font(.system(size: 15, weight: .semibold))
            Text(detail).font(.system(size: 12.5)).foregroundStyle(Brand.muted).multilineTextAlignment(.center).frame(maxWidth: 360)
        }
        .padding(30)
    }
}

struct LogRow: View {
    let line: LogLine

    var body: some View {
        let (color, weight) = style
        Text(line.text)
            .font(.system(size: 12, weight: weight, design: .monospaced))
            .foregroundStyle(color)
            .textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var style: (Color, Font.Weight) {
        let t = line.text.lowercased()
        if line.text.trimmingCharacters(in: .whitespaces).hasPrefix("at ") { return (Brand.muted, .regular) }   // stack frames
        if line.text.hasPrefix("▶") { return (Brand.accent, .semibold) }
        if line.text.hasPrefix("■") || line.text.hasPrefix("↪") { return (Brand.muted, .medium) }
        if t.contains("error") || t.contains("✖") || t.contains("failed") || t.contains("exception") { return (Brand.danger, .regular) }
        if t.contains("warn") { return (Brand.warning, .regular) }
        if t.contains("ready on") || t.contains("listening") || t.contains("local ") { return (Brand.success, .medium) }
        // Many tools write ordinary output to stderr, so only real error text is red.
        return (Brand.text.opacity(0.88), .regular)
    }
}

struct DockToggleStyle: ButtonStyle {
    let isOn: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold))
            .padding(.horizontal, 12).padding(.vertical, 8)
            .foregroundStyle(isOn ? Brand.accent : Brand.muted)
            .background(isOn ? Brand.accent.opacity(0.12) : Brand.card, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(isOn ? Brand.accent.opacity(0.4) : Brand.border, lineWidth: 1))
            .opacity(configuration.isPressed ? 0.8 : 1)
    }
}
