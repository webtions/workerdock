import Foundation

enum OutputParser {
    private static let ansi = try! NSRegularExpression(
        pattern: "\u{1B}\\[[0-9;?]*[ -/]*[@-~]|\u{1B}\\][^\u{07}\u{1B}]*(?:\u{07}|\u{1B}\\\\)|\u{1B}[()][A-Za-z0-9]|\u{1B}[=>]")
    private static let ready = try! NSRegularExpression(pattern: "Ready on (https?://[^\\s]+)")
    private static let local = try! NSRegularExpression(
        pattern: "(https?://(?:localhost|127\\.0\\.0\\.1|\\[::1\\]|0\\.0\\.0\\.0):\\d+[^\\s]*)")

    static func stripANSI(_ s: String) -> String {
        ansi.stringByReplacingMatches(in: s, range: NSRange(s.startIndex..., in: s), withTemplate: "")
    }

    /// The "Ready on http://…" line is the source of truth for wrangler. Other run modes
    /// (vite, custom) fall back to the first localhost URL printed.
    static func detectURL(in line: String, mode: RunModeKind) -> URL? {
        if let u = firstMatch(ready, in: line) { return normalize(u) }
        guard mode != .wrangler, mode != .pages else { return nil }
        if let u = firstMatch(local, in: line) { return normalize(u) }
        return nil
    }

    private static func firstMatch(_ re: NSRegularExpression, in s: String) -> String? {
        guard let m = re.firstMatch(in: s, range: NSRange(s.startIndex..., in: s)),
              m.numberOfRanges > 1, let r = Range(m.range(at: 1), in: s) else { return nil }
        return String(s[r])
    }

    private static func normalize(_ raw: String) -> URL? {
        var s = raw.trimmingCharacters(in: CharacterSet(charactersIn: ".,;)"))
        s = s.replacingOccurrences(of: "0.0.0.0", with: "localhost")
        guard let u = URL(string: s), u.port != nil else { return nil }
        return u
    }
}

/// Splits raw pipe chunks into lines, handling partial lines and carriage-return progress.
final class LineSplitter: @unchecked Sendable {
    private var pending = Data()

    func feed(_ data: Data) -> [String] {
        pending.append(data)
        var lines: [String] = []
        while let idx = pending.firstIndex(of: 0x0A) {
            let chunk = pending[pending.startIndex..<idx]
            pending.removeSubrange(pending.startIndex...idx)
            lines.append(Self.clean(chunk))
        }
        return lines
    }

    func flush() -> String? {
        guard !pending.isEmpty else { return nil }
        defer { pending.removeAll() }
        return Self.clean(pending)
    }

    private static func clean(_ data: Data) -> String {
        let text = String(decoding: data, as: UTF8.self)
        let afterCR = text.split(separator: "\r", omittingEmptySubsequences: true).last.map(String.init) ?? ""
        return OutputParser.stripANSI(afterCR)
    }
}
