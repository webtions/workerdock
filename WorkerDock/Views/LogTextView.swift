import SwiftUI
import AppKit

/// Lets the Copy button reach the text view: copies the selection if there is one, otherwise everything shown.
@MainActor
final class LogViewHandle {
    weak var textView: NSTextView?

    func copy(fallback: String) {
        if let tv = textView, tv.selectedRange().length > 0 {
            let selected = (tv.string as NSString).substring(with: tv.selectedRange())
            copyToPasteboard(selected)
        } else {
            copyToPasteboard(fallback)
        }
    }
}

/// Log output in a real text view, so lines can be selected across rows, copied with ⌘C and searched like any Mac text.
struct LogTextView: NSViewRepresentable {
    let lines: [LogLine]
    let follow: Bool
    let scheme: ColorScheme
    let handle: LogViewHandle

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> NSScrollView {
        let scroll = NSScrollView()
        scroll.drawsBackground = false
        scroll.hasVerticalScroller = true
        scroll.autohidesScrollers = true
        scroll.borderType = .noBorder

        let tv = NSTextView()
        tv.isEditable = false
        tv.isSelectable = true
        tv.isRichText = false
        tv.drawsBackground = false
        tv.usesFindBar = true
        tv.isIncrementalSearchingEnabled = true
        tv.textContainerInset = NSSize(width: 14, height: 14)
        tv.isAutomaticSpellingCorrectionEnabled = false
        tv.isVerticallyResizable = true
        tv.isHorizontallyResizable = false
        tv.autoresizingMask = [.width]
        tv.textContainer?.widthTracksTextView = true
        tv.selectedTextAttributes = [.backgroundColor: NSColor(Brand.accent).withAlphaComponent(0.25)]
        scroll.documentView = tv
        handle.textView = tv
        context.coordinator.textView = tv
        return scroll
    }

    func updateNSView(_ scroll: NSScrollView, context: Context) {
        let c = context.coordinator
        guard let tv = c.textView, let storage = tv.textStorage else { return }
        handle.textView = tv

        let atBottom = tv.visibleRect.maxY >= tv.bounds.maxY - 40
        var changed = false

        if lines.isEmpty {
            if !c.lengths.isEmpty { storage.setAttributedString(NSAttributedString()); c.lengths = []; c.lastID = nil; changed = true }
        } else if c.scheme != scheme || c.lastID == nil || !lines.contains(where: { $0.id == c.lastID }) {
            let text = NSMutableAttributedString()
            c.lengths = []
            for line in lines { let a = Self.attributed(line); text.append(a); c.lengths.append(a.length) }
            storage.setAttributedString(text)
            c.scheme = scheme
            c.lastID = lines.last?.id
            changed = true
        } else if let idx = lines.lastIndex(where: { $0.id == c.lastID }), idx < lines.count - 1 {
            // Only new lines at the end: append them instead of rebuilding.
            storage.beginEditing()
            for line in lines[(idx + 1)...] {
                let a = Self.attributed(line)
                storage.append(a)
                c.lengths.append(a.length)
            }
            // Drop lines that fell off the front of the buffer.
            while c.lengths.count > lines.count {
                storage.deleteCharacters(in: NSRange(location: 0, length: c.lengths.removeFirst()))
            }
            storage.endEditing()
            c.lastID = lines.last?.id
            changed = true
        }

        if changed && follow && (atBottom || c.justRebuilt(changed)) { tv.scrollToEndOfDocument(nil) }
    }

    final class Coordinator {
        weak var textView: NSTextView?
        var lengths: [Int] = []
        var lastID: Int?
        var scheme: ColorScheme?
        func justRebuilt(_ changed: Bool) -> Bool { lengths.count < 2 || changed }
    }

    // MARK: Styling (same rules as before: real errors red, warnings amber, ready lines green)

    private static let font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
    private static let medium = NSFont.monospacedSystemFont(ofSize: 12, weight: .medium)
    private static let semibold = NSFont.monospacedSystemFont(ofSize: 12, weight: .semibold)

    private static func attributed(_ line: LogLine) -> NSAttributedString {
        let (color, f) = style(line)
        let para = NSMutableParagraphStyle()
        para.lineSpacing = 2
        return NSAttributedString(string: line.text + "\n", attributes: [
            .font: f, .foregroundColor: NSColor(color), .paragraphStyle: para,
        ])
    }

    private static func style(_ line: LogLine) -> (Color, NSFont) {
        let t = line.text.lowercased()
        if line.text.trimmingCharacters(in: .whitespaces).hasPrefix("at ") { return (Brand.muted, font) }
        if line.text.hasPrefix("▶") { return (Brand.accent, semibold) }
        if line.text.hasPrefix("■") || line.text.hasPrefix("↪") { return (Brand.muted, medium) }
        if t.contains("error") || t.contains("✖") || t.contains("failed") || t.contains("exception") { return (Brand.danger, font) }
        if t.contains("warn") { return (Brand.warning, font) }
        if t.contains("ready on") || t.contains("listening") || t.contains("local ") { return (Brand.success, medium) }
        return (Brand.text.opacity(0.88), font)
    }
}
