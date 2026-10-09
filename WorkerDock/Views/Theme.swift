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

// MARK: - Design tokens

/// One spacing scale, one radius scale, one type scale. Everything else derives from these.
enum Space {
    static let xs: CGFloat = 4
    static let s: CGFloat = 8
    static let m: CGFloat = 12
    static let l: CGFloat = 16
    static let xl: CGFloat = 24
}

enum Radius {
    static let control: CGFloat = 7
    static let panel: CGFloat = 10
}

enum IconSize {
    static let sm: CGFloat = 14   // inline with text, buttons
    static let md: CGFloat = 16   // list rows
    static let lg: CGFloat = 20   // headers
    static let xl: CGFloat = 28   // empty states
}

extension Font {
    static let dLargeTitle = Font.system(size: 26, weight: .semibold)
    static let dTitle = Font.system(size: 20, weight: .semibold)
    static let dHeading = Font.system(size: 15, weight: .semibold)
    static let dBody = Font.system(size: 13)
    static let dBodyMedium = Font.system(size: 13, weight: .medium)
    static let dCaption = Font.system(size: 12)
    static let dMono = Font.system(size: 12, design: .monospaced)
    static let dLabel = Font.system(size: 11, weight: .semibold)
}

extension Brand {
    /// Flat interaction fills that adapt to light and dark.
    static let hover = Brand.text.opacity(0.05)
    static let selection = Brand.text.opacity(0.09)
}

// MARK: - Building blocks

/// Flat hairline panel. No shadow, no fill beyond the card colour.
struct Card<Content: View>: View {
    var padding: CGFloat = Space.l
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Brand.card, in: RoundedRectangle(cornerRadius: Radius.panel, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Radius.panel, style: .continuous).strokeBorder(Brand.border, lineWidth: 1))
    }
}

struct SectionTitle: View {
    let title: String
    var count: Int?
    var trailing: String?

    var body: some View {
        HStack(spacing: Space.s) {
            Text(title).font(.dLabel).foregroundStyle(Brand.muted).textCase(.uppercase).tracking(0.6)
            if let count { Text("\(count)").font(.dLabel).foregroundStyle(Brand.faint).monospacedDigit() }
            Spacer()
            if let trailing { Text(trailing).font(.dCaption).foregroundStyle(Brand.faint) }
        }
    }
}

/// Fades and lifts a section in on first appearance. Barely noticeable; makes tab changes feel considered.
struct AppearIn: ViewModifier {
    var delay: Double = 0
    @State private var shown = false

    func body(content: Content) -> some View {
        content
            .opacity(shown ? 1 : 0)
            .offset(y: shown ? 0 : 6)
            .onAppear { withAnimation(.easeOut(duration: 0.28).delay(delay)) { shown = true } }
    }
}

extension View {
    func appearIn(_ delay: Double = 0) -> some View { modifier(AppearIn(delay: delay)) }

    /// Flat hover (and optional selected) fill behind a row.
    func hoverFill(radius: CGFloat = Radius.control, selected: Bool = false, enabled: Bool = true) -> some View {
        modifier(HoverFill(radius: radius, selected: selected, enabled: enabled))
    }
}

struct HoverFill: ViewModifier {
    let radius: CGFloat
    let selected: Bool
    let enabled: Bool
    @State private var hover = false

    func body(content: Content) -> some View {
        content
            .background(RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(selected ? Brand.selection : (hover && enabled ? Brand.hover : .clear)))
            .onHover { hover = $0 }
            .animation(.easeOut(duration: 0.12), value: hover)
            .animation(.easeOut(duration: 0.12), value: selected)
    }
}

/// Buttons: `.primary` is the single accent action, `.secondary` a hairline outline, `.danger` an outlined red.
struct DockButtonStyle: ButtonStyle {
    enum Kind { case primary, secondary, danger }
    var kind: Kind = .secondary
    var compact = false

    func makeBody(configuration: Configuration) -> some View {
        DockButtonBody(kind: kind, compact: compact, configuration: configuration)
    }
}

private struct DockButtonBody: View {
    let kind: DockButtonStyle.Kind
    let compact: Bool
    let configuration: ButtonStyleConfiguration
    @Environment(\.isEnabled) private var enabled
    @State private var hover = false

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Radius.control, style: .continuous)
        configuration.label
            .font(compact ? .dCaption.weight(.medium) : .dBodyMedium)
            .padding(.horizontal, compact ? Space.s : Space.m).frame(height: compact ? 24 : 28)
            .foregroundStyle(foreground)
            .background(fill, in: shape)
            .overlay(shape.strokeBorder(stroke, lineWidth: 1))
            .opacity(enabled ? 1 : 0.4)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .contentShape(shape)
            .onHover { hover = $0 }
            .animation(.easeOut(duration: 0.12), value: hover)
            .animation(.easeOut(duration: 0.08), value: configuration.isPressed)
    }

    private var foreground: Color {
        switch kind {
        case .primary: return .white
        case .secondary: return Brand.text
        case .danger: return Brand.danger
        }
    }

    private var fill: Color {
        let on = hover && enabled
        switch kind {
        case .primary: return Brand.accent.opacity(on ? 0.88 : 1)
        case .secondary: return on ? Brand.hover : .clear
        case .danger: return Brand.danger.opacity(on ? 0.10 : 0)
        }
    }

    private var stroke: Color {
        switch kind {
        case .primary: return .clear
        case .secondary: return Brand.border
        case .danger: return Brand.danger.opacity(0.35)
        }
    }
}

extension ButtonStyle where Self == DockButtonStyle {
    static var dockPrimary: DockButtonStyle { DockButtonStyle(kind: .primary) }
    static var dockSecondary: DockButtonStyle { DockButtonStyle(kind: .secondary) }
    static var dockDanger: DockButtonStyle { DockButtonStyle(kind: .danger) }
    static var dockSecondaryCompact: DockButtonStyle { DockButtonStyle(kind: .secondary, compact: true) }
}

/// Square icon-only button with a hover fill.
struct DockIconButtonStyle: ButtonStyle {
    var size: CGFloat = 24
    /// Hairline outline, to sit beside outlined text buttons.
    var bordered = false

    func makeBody(configuration: Configuration) -> some View {
        IconButtonBody(size: size, bordered: bordered, configuration: configuration)
    }
}

private struct IconButtonBody: View {
    let size: CGFloat
    let bordered: Bool
    let configuration: ButtonStyleConfiguration
    @State private var hover = false

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Radius.control, style: .continuous)
        configuration.label
            .foregroundStyle(hover || bordered ? Brand.text : Brand.muted)
            .frame(width: size, height: size)
            .background(hover ? (bordered ? Brand.hover : Brand.selection) : .clear, in: shape)
            .overlay(shape.strokeBorder(bordered ? Brand.border : .clear, lineWidth: 1))
            .scaleEffect(configuration.isPressed ? 0.92 : 1)
            .contentShape(Rectangle())
            .onHover { hover = $0 }
            .animation(.easeOut(duration: 0.12), value: hover)
            .animation(.easeOut(duration: 0.08), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == DockIconButtonStyle {
    static var dockIcon: DockIconButtonStyle { DockIconButtonStyle() }
    static var dockIconBordered: DockIconButtonStyle { DockIconButtonStyle(size: 28, bordered: true) }
}

/// Look-alike of a secondary button for use as a `Menu` label.
struct MenuChip: View {
    let title: String
    let icon: String
    @State private var hover = false

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Radius.control, style: .continuous)
        HStack(spacing: 6) {
            Icon(icon, size: IconSize.sm)
            Text(title).font(.dBodyMedium)
            Icon("chevron-down", size: 12).foregroundStyle(Brand.muted)
        }
        .padding(.horizontal, Space.m).frame(height: 28)
        .foregroundStyle(Brand.text)
        .background(hover ? Brand.hover : .clear, in: shape)
        .overlay(shape.strokeBorder(Brand.border, lineWidth: 1))
        .contentShape(shape)
        .onHover { hover = $0 }
        .animation(.easeOut(duration: 0.12), value: hover)
    }
}

/// Status dot with a soft pulse while running.
struct StatusDot: View {
    let status: ProjectStatus
    var size: CGFloat = 8
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
        .animation(.easeOut(duration: 0.25), value: status)
        .onAppear { pulse = true }
        .accessibilityLabel(status.label)
    }

    private var color: Color {
        switch status {
        case .running: return Brand.success
        case .starting: return Brand.warning
        case .stopped: return Brand.faint.opacity(0.6)
        case .error: return Brand.danger
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

/// Shared look for the small status chips in the header: same height, same text size, soft tint of one colour.
struct PillShape: ViewModifier {
    let tint: Color

    func body(content: Content) -> some View {
        content
            .foregroundStyle(tint)
            .padding(.horizontal, Space.s).frame(height: 22)
            .background(tint.opacity(0.12), in: Capsule())
            .fixedSize()
    }
}

/// Neutral outlined chip for labels like the project type: card colour with a hairline, like the app's other outlined controls.
struct Pill: View {
    let text: String

    var body: some View {
        Text(text).font(.dCaption.weight(.medium))
            .foregroundStyle(Brand.muted)
            .padding(.horizontal, Space.s).frame(height: 22)
            .background(Brand.card, in: Capsule())
            .overlay(Capsule().strokeBorder(Brand.border, lineWidth: 1))
            .fixedSize()
    }
}
