import SwiftUI
import AppKit

extension Color {
    /// Cloudflare orange, used sparingly as an accent.
    static let cfOrange = Color(red: 0.965, green: 0.510, blue: 0.122)
}

struct StatusDot: View {
    let status: ProjectStatus

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 9, height: 9)
            .accessibilityLabel(status.label)
    }

    private var color: Color {
        switch status {
        case .running: return .green
        case .starting: return .yellow
        case .stopped: return Color.secondary.opacity(0.45)
        case .error: return .red
        }
    }
}

enum Format {
    static func bytes(_ b: UInt64) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(b), countStyle: .memory)
    }
}

func copyToPasteboard(_ s: String) {
    NSPasteboard.general.clearContents()
    NSPasteboard.general.setString(s, forType: .string)
}

func chooseFolder(prompt: String, message: String) -> String? {
    let panel = NSOpenPanel()
    panel.canChooseDirectories = true
    panel.canChooseFiles = false
    panel.allowsMultipleSelection = false
    panel.prompt = prompt
    panel.message = message
    return panel.runModal() == .OK ? panel.url?.path : nil
}

func showError(_ message: String) {
    let alert = NSAlert()
    alert.alertStyle = .warning
    alert.messageText = message
    alert.runModal()
}
