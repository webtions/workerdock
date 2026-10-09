import SwiftUI

/// How this project is started. Everything here is persisted per project.
struct ProjectSettingsView: View {
    @Environment(AppModel.self) private var model
    let project: Project
    @State private var customCommand = ""
    @State private var portText = ""

    var body: some View {
        let mode = model.effectiveMode(project)

        ScrollView {
            VStack(alignment: .leading, spacing: Space.s) {
                SectionTitle(title: "Run")
                Card(padding: 0) {
                    VStack(spacing: 0) {
                        SettingRow(title: "Run mode", help: "How \(AppInfo.name) starts this project. Auto-detect is right for most.") {
                            Picker("Run mode", selection: Binding(
                                get: { project.runModeOverride },
                                set: { model.setRunMode(project.id, $0) })) {
                                Text("Auto-detect (\(model.info(project.id)?.detectedMode.title ?? "…"))").tag(RunModeKind?.none)
                                ForEach(RunModeKind.allCases) { Text($0.title).tag(RunModeKind?.some($0)) }
                            }
                            .labelsHidden()
                            .tint(Brand.text)
                            .frame(width: 260)
                        }

                        if mode == .custom {
                            Divider().overlay(Brand.borderSoft).padding(.horizontal, Space.m)
                            SettingRow(title: "Command", help: "Runs in the project folder. The address is read from its output.") {
                                TextField("e.g. pnpm run dev", text: $customCommand)
                                    .textFieldStyle(.roundedBorder)
                                    .font(.dMono)
                                    .frame(width: 260)
                                    .onSubmit { model.setCustomCommand(project.id, customCommand) }
                                    .onChange(of: customCommand) { _, v in model.setCustomCommand(project.id, v) }
                            }
                        }

                        if mode == .wrangler || mode == .pages {
                            Divider().overlay(Brand.borderSoft).padding(.horizontal, Space.m)
                            SettingRow(title: "Port", help: "Allocated from 8787 upward when empty or busy.") {
                                TextField("auto", text: $portText)
                                    .textFieldStyle(.roundedBorder)
                                    .frame(width: 110)
                                    .onSubmit { commitPort() }
                            }
                        }
                    }
                }
            }
            .padding(Space.xl)
            .frame(maxWidth: .infinity, alignment: .leading)
            .appearIn()
        }
        .onAppear {
            customCommand = project.customCommand ?? ""
            portText = project.port.map(String.init) ?? ""
        }
        .onDisappear { commitPort() }
    }

    private func commitPort() {
        let trimmed = portText.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty { model.setPort(project.id, nil) }
        else if let p = Int(trimmed), (1024...65535).contains(p) { model.setPort(project.id, p) }
        else { portText = project.port.map(String.init) ?? "" }
    }
}

/// Title and help on the left, control on the right.
struct SettingRow<Control: View>: View {
    let title: String
    let help: String
    @ViewBuilder var control: () -> Control

    var body: some View {
        HStack(alignment: .center, spacing: Space.l) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.dBodyMedium)
                Text(help).font(.dCaption).foregroundStyle(Brand.muted)
            }
            Spacer(minLength: Space.l)
            control()
        }
        .padding(.horizontal, Space.m).padding(.vertical, Space.m)
    }
}
