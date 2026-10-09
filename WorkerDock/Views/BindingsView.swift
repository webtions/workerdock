import SwiftUI

/// One row of data shared by the diagram and the list.
struct BindingItem: Identifiable {
    let id: String
    let icon: String
    let color: Color
    let title: String
    let subtitle: String?
    let tag: String
    var copyValues: [(label: String, value: String)] = []
    var explorer = false

    static func items(bindings: [WorkerBinding], varNames: [String]) -> [BindingItem] {
        var list = BindingKind.allCases.flatMap { kind in
            bindings.filter { $0.kind == kind }.map { b -> BindingItem in
                var copy = [("Copy binding name", b.name)]
                if let detail = b.detail { copy.append(("Copy resource name", detail)) }
                return BindingItem(id: b.id, icon: kind.lucide, color: Brand.kind(kind), title: b.name, subtitle: b.detail,
                                   tag: kind.shortTitle, copyValues: copy, explorer: kind.hasExplorer)
            }
        }
        if !varNames.isEmpty {
            list.append(BindingItem(
                id: "vars", icon: "braces", color: Brand.muted, title: "Variables",
                subtitle: varNames.prefix(4).joined(separator: ", ") + (varNames.count > 4 ? " +\(varNames.count - 4)" : ""),
                tag: varNames.count == 1 ? "1 var" : "\(varNames.count) vars",
                copyValues: [("Copy variable names", varNames.joined(separator: ", "))]))
        }
        return list
    }
}

extension BindingKind {
    /// Kinds Wrangler's Local Explorer can browse.
    var hasExplorer: Bool {
        switch self {
        case .d1, .kv, .r2, .durableObject, .workflow: return true
        default: return false
        }
    }
}

/// ⋮ menu on a binding: copy its names, jump to Explorer.
struct BindingMenu: View {
    @Environment(AppModel.self) private var model
    let item: BindingItem

    var body: some View {
        Menu {
            ForEach(Array(item.copyValues.enumerated()), id: \.offset) { _, entry in
                Button(entry.label) { copyToPasteboard(entry.value) }
            }
            if item.explorer {
                Divider()
                Button("Show in Explorer") { model.selectedTab = .explorer }
            }
        } label: {
            Icon("ellipsis-vertical", size: IconSize.sm)
        }
        .menuStyle(.button)
        .buttonStyle(DockIconButtonStyle(size: 24))
        .menuIndicator(.hidden)
        .fixedSize()
        .help("Actions")
    }
}

enum BindingsLayout: String { case diagram, list }

/// Bindings section: title with count, a Diagram/List switch, and the chosen view.
struct BindingsSection: View {
    @Environment(AppModel.self) private var model
    let project: Project
    let info: ProjectInfo
    let status: ProjectStatus
    @AppStorage("bindingsLayout") private var layoutRaw = BindingsLayout.diagram.rawValue

    private var layout: BindingsLayout { BindingsLayout(rawValue: layoutRaw) ?? .diagram }
    private var count: Int { info.bindings.count + (info.varNames.isEmpty ? 0 : 1) }

    var body: some View {
        VStack(alignment: .leading, spacing: Space.s) {
            HStack {
                SectionTitle(title: "Bindings", count: count)
                Spacer()
                if count > 0 { LayoutToggle(selection: Binding(get: { layout }, set: { layoutRaw = $0.rawValue })) }
            }
            if count == 0 {
                Card(padding: Space.l) {
                    HStack(spacing: Space.s) {
                        Icon("plug", size: IconSize.md).foregroundStyle(Brand.faint)
                        Text("No bindings in this project's config.").font(.dBody).foregroundStyle(Brand.muted)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else if layout == .diagram {
                BindingGraph(workerName: info.workerName ?? project.name, entry: info.mainEntry,
                             bindings: info.bindings, varNames: info.varNames, status: status,
                             configFile: project.configFile, onOpenConfig: { model.openInEditor(project.id, file: project.configFile) })
                    .transition(.opacity)
            } else {
                BindingList(items: BindingItem.items(bindings: info.bindings, varNames: info.varNames))
                    .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.18), value: layoutRaw)
    }
}

/// Dense table for projects with many bindings.
struct BindingList: View {
    let items: [BindingItem]

    var body: some View {
        Card(padding: 0) {
            VStack(spacing: 0) {
                ForEach(Array(items.enumerated()), id: \.element.id) { i, item in
                    HStack(spacing: Space.m) {
                        Icon(item.icon, size: IconSize.md).foregroundStyle(item.color).frame(width: IconSize.md)
                        Text(item.title).font(.system(size: 12, weight: .medium, design: .monospaced)).lineLimit(1)
                            .frame(minWidth: 140, alignment: .leading)
                        Text(item.subtitle ?? "").font(.dCaption).foregroundStyle(Brand.muted).lineLimit(1)
                        Spacer(minLength: Space.s)
                        Text(item.tag).font(.dCaption).foregroundStyle(Brand.muted)
                        BindingMenu(item: item)
                    }
                    .padding(.leading, Space.m).padding(.trailing, Space.s).frame(height: 40)
                    if i < items.count - 1 { Divider().overlay(Brand.borderSoft).padding(.horizontal, Space.m) }
                }
            }
        }
    }
}

/// Two-state switch with a sliding selection.
private struct LayoutToggle: View {
    @Binding var selection: BindingsLayout
    @Namespace private var ns

    var body: some View {
        HStack(spacing: 2) {
            option(.diagram, icon: "workflow", label: "Diagram")
            option(.list, icon: "list", label: "List")
        }
        .padding(2)
        .overlay(RoundedRectangle(cornerRadius: Radius.control + 2, style: .continuous).strokeBorder(Brand.border, lineWidth: 1))
    }

    private func option(_ value: BindingsLayout, icon: String, label: String) -> some View {
        let on = selection == value
        return Button {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.85)) { selection = value }
        } label: {
            HStack(spacing: 5) {
                Icon(icon, size: IconSize.sm)
                Text(label).font(.dCaption.weight(.medium))
            }
            .padding(.horizontal, Space.s).frame(height: 22)
            .foregroundStyle(on ? Brand.text : Brand.muted)
            .background {
                if on {
                    RoundedRectangle(cornerRadius: Radius.control, style: .continuous).fill(Brand.selection)
                        .matchedGeometryEffect(id: "sel", in: ns)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
