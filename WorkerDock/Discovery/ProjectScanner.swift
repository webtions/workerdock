import Foundation

struct DiscoveredConfig: Hashable {
    var dir: String
    var file: String
}

enum ProjectScanner {
    static let configNames = ["wrangler.jsonc", "wrangler.json", "wrangler.toml"]   // priority order
    static let skipped: Set<String> = ["node_modules", ".wrangler", ".git", "dist", ".output", ".next", ".localflare"]
    static let maxDepth = 8

    /// Recursively finds wrangler configs under `root`. Read-only.
    static func scan(root: String) -> [DiscoveredConfig] {
        let rootURL = URL(fileURLWithPath: root)
        var found: [DiscoveredConfig] = []
        let keys: [URLResourceKey] = [.isDirectoryKey]
        guard let walker = FileManager.default.enumerator(
            at: rootURL, includingPropertiesForKeys: keys,
            options: [.skipsPackageDescendants]) else { return [] }

        var bestPerDir: [String: String] = [:]
        for case let url as URL in walker {
            let name = url.lastPathComponent
            let isDir = (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
            if isDir {
                if skipped.contains(name) || walker.level > maxDepth { walker.skipDescendants() }
                continue
            }
            guard let rank = configNames.firstIndex(of: name) else { continue }
            let dir = url.deletingLastPathComponent().path
            if let existing = bestPerDir[dir], let er = configNames.firstIndex(of: existing), er <= rank { continue }
            bestPerDir[dir] = name
        }
        for (dir, file) in bestPerDir { found.append(DiscoveredConfig(dir: dir, file: file)) }
        return found.sorted { $0.dir < $1.dir }
    }

    /// Looks for a config directly inside a single project folder.
    static func config(inProjectFolder dir: String) -> DiscoveredConfig? {
        for name in configNames where FileManager.default.fileExists(atPath: (dir as NSString).appendingPathComponent(name)) {
            return DiscoveredConfig(dir: dir, file: name)
        }
        return nil
    }
}
