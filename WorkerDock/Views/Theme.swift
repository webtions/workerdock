import SwiftUI
import AppKit

// MARK: - Brand palette (from the Webtions / SVG Ready design tokens)

extension Color {
    /// Resolves differently in light and dark appearance, following the system.
    init(light: String, dark: String) {
        self.init(nsColor: NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            return NSColor(hex: isDark ? dark : light)
        })
    }

    init(hex: String) { self.init(nsColor: NSColor(hex: hex)) }
}

extension NSColor {
    convenience init(hex: String) {
        var s = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        if s.count == 3 { s = s.map { "\($0)\($0)" }.joined() }
        var v: UInt64 = 0
        Scanner(string: s).scanHexInt64(&v)
        self.init(srgbRed: CGFloat((v >> 16) & 0xFF) / 255, green: CGFloat((v >> 8) & 0xFF) / 255,
                  blue: CGFloat(v & 0xFF) / 255, alpha: 1)
    }
}

enum Brand {
    static let background = Color(light: "#FFFDF9", dark: "#0A0A0A")
    static let card = Color(light: "#FFFFFF", dark: "#1A1A1A")
    static let cardRaised = Color(light: "#FFFFFF", dark: "#202020")
    static let border = Color(light: "#EFE6D2", dark: "#2A2A2A")
    static let borderSoft = Color(light: "#F6EEDC", dark: "#222222")
    static let text = Color(light: "#111827", dark: "#F9FAFB")
    static let muted = Color(light: "#6B7280", dark: "#9CA3AF")
    static let faint = Color(light: "#9CA3AF", dark: "#6B7280")
    static let accent = Color(hex: "#FF3253")
    static let accentSoft = Color(light: "#FFE8EC", dark: "#2A1216")
    static let highlight = Color(light: "#0000EE", dark: "#FFB500")   // links
    static let success = Color(hex: "#10B981")
    static let warning = Color(hex: "#F59E0B")
    static let danger = Color(light: "#B00020", dark: "#FF6B6B")
    static let cloudflare = Color(hex: "#F6821F")
    static let codeBackground = Color(light: "#FBF7EE", dark: "#101010")
    static let sidebar = Color(light: "#F8F3E8", dark: "#0F0F0F")

    static func kind(_ k: BindingKind) -> Color {
        switch k {
        case .d1: return Color(hex: "#3B82F6")
        case .kv: return Color(hex: "#8B5CF6")
        case .r2: return Color(hex: "#F59E0B")
        case .queue: return Color(hex: "#10B981")
        case .durableObject: return Color(hex: "#EC4899")
        case .workflow: return Color(hex: "#06B6D4")
        case .service: return Color(hex: "#6366F1")
        case .ai: return Color(hex: "#FF3253")
        case .vectorize: return Color(hex: "#14B8A6")
        case .hyperdrive: return Color(hex: "#EAB308")
        case .analytics: return Color(hex: "#84CC16")
        case .browser: return Color(hex: "#0EA5E9")
        case .assets: return Color(hex: "#A855F7")
        case .other: return Color(hex: "#9CA3AF")
        }
    }
}

// MARK: - Lucide icons

/// Lucide icon from the bundled asset catalog (template-rendered, takes the foreground colour).
struct Icon: View {
    let name: String
    var size: CGFloat = 16

    init(_ name: String, size: CGFloat = 16) {
        self.name = name
        self.size = size
    }

    var body: some View {
        Image("lucide-\(name)")
            .renderingMode(.template)
            .resizable()
            .interpolation(.high)
            .aspectRatio(contentMode: .fit)
            .frame(width: size, height: size)
    }
}

extension BindingKind {
    var lucide: String {
        switch self {
        case .d1: return "database"
        case .kv: return "key-round"
        case .r2: return "hard-drive"
        case .queue: return "layers"
        case .durableObject: return "box"
        case .workflow: return "workflow"
        case .service: return "link-2"
        case .ai: return "sparkles"
        case .vectorize: return "waypoints"
        case .hyperdrive: return "zap"
        case .analytics: return "chart-column"
        case .browser: return "app-window"
        case .assets: return "image"
        case .other: return "package"
        }
    }

    var shortTitle: String {
        switch self {
        case .d1: return "D1"
        case .kv: return "KV"
        case .r2: return "R2"
        case .queue: return "Queue"
        case .durableObject: return "Durable Object"
        case .workflow: return "Workflow"
        case .service: return "Service"
        case .ai: return "Workers AI"
        case .vectorize: return "Vectorize"
        case .hyperdrive: return "Hyperdrive"
        case .analytics: return "Analytics"
        case .browser: return "Browser"
        case .assets: return "Assets"
        case .other: return "Binding"
        }
    }
}

// MARK: - Building blocks

struct Card<Content: View>: View {
    var padding: CGFloat = 18
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Brand.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Brand.border, lineWidth: 1))
            .shadow(color: .black.opacity(0.04), radius: 8, y: 2)
    }
}

struct SectionTitle: View {
    let title: String
    var icon: String?
    var trailing: String?

    var body: some View {
        HStack(spacing: 8) {
            if let icon { Icon(icon, size: 15).foregroundStyle(Brand.muted) }
            Text(title).font(.system(size: 13, weight: .semibold)).foregroundStyle(Brand.muted).textCase(.uppercase).tracking(0.6)
            Spacer()
            if let trailing { Text(trailing).font(.system(size: 12)).foregroundStyle(Brand.faint) }
        }
    }
}

struct Pill: View {
    let text: String
    var icon: String?
    var tint: Color = Brand.muted

    var body: some View {
        HStack(spacing: 5) {
            if let icon { Icon(icon, size: 11) }
            Text(text).font(.system(size: 11.5, weight: .medium))
        }
        .padding(.horizontal, 9).padding(.vertical, 4)
        .foregroundStyle(tint)
        .background(tint.opacity(0.12), in: Capsule())
    }
}

/// Rounded, brand-coloured button. `.primary` uses the accent; `.secondary` is a quiet bordered capsule.
struct DockButtonStyle: ButtonStyle {
    enum Kind { case primary, secondary, danger }
    var kind: Kind = .secondary
    @Environment(\.isEnabled) private var enabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold))
            .padding(.horizontal, 14).padding(.vertical, 8)
            .foregroundStyle(foreground)
            .background(background(configuration.isPressed), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(kind == .secondary ? Brand.border : .clear, lineWidth: 1))
            .opacity(enabled ? 1 : 0.45)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }

    private var foreground: Color {
        switch kind {
        case .primary: return .white
        case .secondary: return Brand.text
        case .danger: return Brand.danger
        }
    }

    private func background(_ pressed: Bool) -> Color {
        switch kind {
        case .primary: return Brand.accent.opacity(pressed ? 0.85 : 1)
        case .secondary: return Brand.cardRaised.opacity(pressed ? 0.7 : 1)
        case .danger: return Brand.danger.opacity(pressed ? 0.18 : 0.10)
        }
    }
}

extension ButtonStyle where Self == DockButtonStyle {
    static var dockPrimary: DockButtonStyle { DockButtonStyle(kind: .primary) }
    static var dockSecondary: DockButtonStyle { DockButtonStyle(kind: .secondary) }
    static var dockDanger: DockButtonStyle { DockButtonStyle(kind: .danger) }
}

/// Status dot with a soft pulse while running.
struct StatusDot: View {
    let status: ProjectStatus
    var size: CGFloat = 9
    @State private var pulse = false

    var body: some View {
        ZStack {
            if status == .running {
                Circle().fill(color.opacity(0.35)).frame(width: size, height: size)
                    .scaleEffect(pulse ? 2.1 : 1).opacity(pulse ? 0 : 0.8)
                    .animation(.easeOut(duration: 1.6).repeatForever(autoreverses: false), value: pulse)
            }
            Circle().fill(color).frame(width: size, height: size)
        }
        .frame(width: size * 2, height: size * 2)
        .onAppear { pulse = true }
        .accessibilityLabel(status.label)
    }

    private var color: Color {
        switch status {
        case .running: return Brand.success
        case .starting: return Brand.warning
        case .stopped: return Brand.faint.opacity(0.6)
        case .error: return Brand.accent
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
