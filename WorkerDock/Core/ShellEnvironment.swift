import Foundation

/// GUI apps don't inherit the user's shell environment, so node/npx from nvm, volta,
/// mise, fnm, asdf or Homebrew aren't on PATH. We ask the login shell once and cache it.
enum ShellEnvironment {
    private static let marker = "__WORKERDOCK_ENV_BEGIN__"

    static func resolve(timeout: TimeInterval = 8) async -> [String: String] {
        await withCheckedContinuation { cont in
            DispatchQueue.global(qos: .utility).async {
                cont.resume(returning: resolveBlocking(timeout: timeout))
            }
        }
    }

    static func resolveBlocking(timeout: TimeInterval) -> [String: String] {
        let shell = ProcessInfo.processInfo.environment["SHELL"] ?? "/bin/zsh"
        let process = Process()
        process.executableURL = URL(fileURLWithPath: shell)
        process.arguments = ["-lic", "echo \(marker); env"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        process.standardInput = FileHandle.nullDevice

        do { try process.run() } catch { return fallback() }

        let killer = DispatchWorkItem { if process.isRunning { process.terminate() } }
        DispatchQueue.global().asyncAfter(deadline: .now() + timeout, execute: killer)
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        killer.cancel()

        let parsed = parse(String(decoding: data, as: UTF8.self))
        return parsed.isEmpty ? fallback() : parsed
    }

    static func parse(_ output: String) -> [String: String] {
        guard let range = output.range(of: marker) else { return [:] }
        var env: [String: String] = [:]
        let pattern = try! NSRegularExpression(pattern: "^[A-Za-z_][A-Za-z0-9_]*=")
        for line in output[range.upperBound...].split(separator: "\n", omittingEmptySubsequences: true) {
            let s = String(line)
            guard let eq = s.firstIndex(of: "="),
                  pattern.firstMatch(in: s, range: NSRange(s.startIndex..., in: s)) != nil else { continue }
            env[String(s[..<eq])] = String(s[s.index(after: eq)...])
        }
        return env
    }

    /// Used when the login shell can't be queried (timeout, broken rc files).
    static func fallback() -> [String: String] {
        var env = ProcessInfo.processInfo.environment
        let extra = ["/opt/homebrew/bin", "/opt/homebrew/sbin", "/usr/local/bin", "/usr/bin", "/bin", "/usr/sbin", "/sbin"]
        let existing = (env["PATH"] ?? "").split(separator: ":").map(String.init)
        env["PATH"] = (existing + extra.filter { !existing.contains($0) }).joined(separator: ":")
        return env
    }

    /// Cached shell env, plus overrides every spawned process should see.
    static func effective(base: [String: String], nodePath: String) -> [String: String] {
        var env = base
        let trimmed = nodePath.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty {
            var dir = trimmed
            var isDir: ObjCBool = false
            if !(FileManager.default.fileExists(atPath: trimmed, isDirectory: &isDir) && isDir.boolValue) {
                dir = (trimmed as NSString).deletingLastPathComponent
            }
            env["PATH"] = dir + ":" + (env["PATH"] ?? "")
        }
        env["NO_COLOR"] = "1"
        env["FORCE_COLOR"] = "0"
        env["TERM"] = "dumb"
        return env
    }
}
