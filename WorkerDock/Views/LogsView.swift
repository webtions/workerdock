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

        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("Filter logs", text: $filter)
                    .textFieldStyle(.plain)
                    .focused($searchFocused)
                // Hidden button gives ⌘F its shortcut.
                Button("") { searchFocused = true }
                    .keyboardShortcut("f", modifiers: .command)
                    .opacity(0).frame(width: 0, height: 0)
                Text("\(lines.count) lines").font(.caption).foregroundStyle(.secondary)
                Toggle("Auto-scroll", isOn: $autoScroll).toggleStyle(.checkbox)
                Button("Clear") { rt.log.clear() }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            Divider()

            if rt.external && all.isEmpty {
                ContentUnavailableView("Logs unavailable",
                                       systemImage: "terminal",
                                       description: Text("This project was started outside \(AppInfo.name), so its output can't be captured. Stop it and start it from here to see logs."))
            } else if lines.isEmpty {
                ContentUnavailableView(all.isEmpty ? "No output yet" : "No matches",
                                       systemImage: "text.alignleft")
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 1) {
                            ForEach(lines) { line in
                                Text(line.text)
                                    .font(.system(size: 12, design: .monospaced))
                                    .foregroundStyle(line.isError ? Color.red : Color.primary)
                                    .textSelection(.enabled)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .id(line.id)
                            }
                        }
                        .padding(12)
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
    }
}
