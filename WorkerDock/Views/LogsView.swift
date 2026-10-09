import SwiftUI

struct LogsView: View {
    @Environment(AppModel.self) private var model
    let project: Project
    @State private var filter = ""
    @State private var autoScroll = true
    @FocusState private var searchFocused: Bool
    @State private var handle = LogViewHandle()
    @State private var copied = false
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let rt = model.runtime(project.id)
        let all = rt.log.lines
        let lines = filter.isEmpty ? all : all.filter { $0.text.localizedCaseInsensitiveContains(filter) }

        VStack(spacing: Space.m) {
            HStack(spacing: Space.s) {
                HStack(spacing: Space.s) {
                    Icon("search", size: IconSize.sm).foregroundStyle(Brand.faint)
                    TextField("Filter logs", text: $filter)
                        .textFieldStyle(.plain)
                        .focused($searchFocused)
                    if !filter.isEmpty {
                        Button { filter = "" } label: { Icon("x", size: 12) }.buttonStyle(.dockIcon).frame(width: 20, height: 20)
                    }
                    // Hidden button gives ⌘F its shortcut.
                    Button("") { searchFocused = true }
                        .keyboardShortcut("f", modifiers: .command)
                        .opacity(0).frame(width: 0, height: 0)
                }
                .font(.dBody)
                .padding(.horizontal, Space.m).frame(height: 28)
                .overlay(RoundedRectangle(cornerRadius: Radius.control, style: .continuous).strokeBorder(searchFocused ? Brand.accent.opacity(0.6) : Brand.border, lineWidth: 1))
                .animation(.easeOut(duration: 0.15), value: searchFocused)

                Text("\(lines.count) lines").font(.dCaption).monospacedDigit().foregroundStyle(Brand.muted)
                    .contentTransition(.numericText())

                Button { autoScroll.toggle() } label: {
                    Label { Text("Follow") } icon: { Icon("arrow-down-to-line", size: IconSize.sm) }
                }
                .buttonStyle(DockToggleStyle(isOn: autoScroll))
                .help("Auto-scroll to the newest line")

                Button {
                    handle.copy(fallback: lines.map(\.text).joined(separator: "\n"))
                    withAnimation(.easeOut(duration: 0.15)) { copied = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { withAnimation(.easeOut(duration: 0.15)) { copied = false } }
                } label: {
                    Label { Text(copied ? "Copied" : "Copy") } icon: { Icon(copied ? "check" : "copy", size: IconSize.sm) }
                }
                .buttonStyle(.dockSecondary)
                .disabled(lines.isEmpty)
                .help("Copy the selected text, or all visible lines")

                Button { rt.log.clear() } label: { Label { Text("Clear") } icon: { Icon("eraser", size: IconSize.sm) } }
                    .buttonStyle(.dockSecondary)
            }

            ZStack {
                RoundedRectangle(cornerRadius: Radius.panel, style: .continuous).fill(Brand.codeBackground)
                if rt.external && all.isEmpty {
                    placeholder("terminal", "Logs unavailable",
                                "This project was started outside \(AppInfo.name), so its output can't be captured. Stop it and start it from here to see logs.")
                } else if lines.isEmpty {
                    placeholder("scroll-text", all.isEmpty ? "No output yet" : "No matches", all.isEmpty ? "Start the project to see its output here." : "Nothing matches “\(filter)”.")
                } else {
                    LogTextView(lines: lines, follow: autoScroll, scheme: scheme, handle: handle)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: Radius.panel, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Radius.panel, style: .continuous).strokeBorder(Brand.border, lineWidth: 1))
        }
        .padding(Space.xl)
    }

    private func placeholder(_ icon: String, _ title: String, _ detail: String) -> some View {
        VStack(spacing: Space.s) {
            Icon(icon, size: IconSize.xl).foregroundStyle(Brand.faint)
            Text(title).font(.dHeading)
            Text(detail).font(.dCaption).foregroundStyle(Brand.muted).multilineTextAlignment(.center).frame(maxWidth: 360)
        }
        .padding(Space.xl)
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
        ToggleBody(isOn: isOn, configuration: configuration)
    }
}

private struct ToggleBody: View {
    let isOn: Bool
    let configuration: ButtonStyleConfiguration
    @State private var hover = false

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Radius.control, style: .continuous)
        configuration.label
            .font(.dBodyMedium)
            .padding(.horizontal, Space.m).frame(height: 28)
            .foregroundStyle(isOn ? Brand.accent : Brand.muted)
            .background(hover ? Brand.hover : .clear, in: shape)
            .overlay(shape.strokeBorder(isOn ? Brand.accent.opacity(0.5) : Brand.border, lineWidth: 1))
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .contentShape(shape)
            .onHover { hover = $0 }
            .animation(.easeOut(duration: 0.12), value: hover)
            .animation(.easeOut(duration: 0.12), value: isOn)
    }
}
