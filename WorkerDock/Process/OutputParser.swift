import Foundation

enum OutputParser {
    /// The port from "Address already in use (127.0.0.1:8788)", EADDRINUSE or "Port 4321 is in use" messages.
    static func detectPortInUse(in text: String) -> Int? {
        let lower = text.lowercased()
        let patterns: [String]
        if lower.contains("address already in use") || lower.contains("eaddrinuse") {
            patterns = [":(\\d{2,5})(?!.*:\\d{2,5})"]
        } else if lower.contains("is already in use") || lower.contains("is in use") {
            patterns = ["port (\\d{2,5})"]
        } else { return nil }
        for pattern in patterns {
            if let re = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
               let m = re.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
               let r = Range(m.range(at: 1), in: text), let port = Int(text[r]) { return port }
        }
        return nil
    }

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

    private static let alreadyRunning = try! NSRegularExpression(
        pattern: "already running at (https?://[^\\s\\\\]+) \\(pid (\\d+)\\)")

    /// e.g. Astro 7: `Dev server already running at http://localhost:4321 (pid 35873)`.
    static func detectAlreadyRunning(in line: String) -> (URL, Int32)? {
        guard let m = alreadyRunning.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)), m.numberOfRanges == 3,
              let r1 = Range(m.range(at: 1), in: line), let r2 = Range(m.range(at: 2), in: line),
              let url = normalize(String(line[r1])), let pid = Int32(line[r2]) else { return nil }
        return (url, pid)
    }

    enum AttachField: Equatable { case marker, url(URL), pid(Int32) }
    private static let urlField = try! NSRegularExpression(pattern: "^\\s*URL:\\s+(https?://\\S+)")
    private static let pidField = try! NSRegularExpression(pattern: "^\\s*PID:\\s+(\\d+)")

    /// Astro's multi-line refusal: "Another astro dev server is already running." then `URL:` and `PID:` lines.
    static func detectAttachField(in line: String) -> AttachField? {
        if line.contains("is already running") && !line.contains("(pid") { return .marker }
        if let u = firstMatch(urlField, in: line), let url = normalize(u) { return .url(url) }
        if let p = firstMatch(pidField, in: line), let pid = Int32(p) { return .pid(pid) }
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
