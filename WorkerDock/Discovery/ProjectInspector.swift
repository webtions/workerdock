import Foundation

/// Reads project metadata. Strictly read-only.
enum ProjectInspector {
    static let viteConfigNames = ["vite.config.ts", "vite.config.js", "vite.config.mjs", "vite.config.mts", "vite.config.cjs"]

    static func inspect(_ project: Project) -> ProjectInfo {
        var info = ProjectInfo()
        let dir = project.path
        let configURL = URL(fileURLWithPath: dir).appendingPathComponent(project.configFile)
        info.configKind = ConfigParser.kind(forFile: project.configFile)

        do {
            let parsed = try ConfigParser.parse(fileURL: configURL)
            info.workerName = parsed.workerName
            info.mainEntry = parsed.main
            info.compatibilityDate = parsed.compatibilityDate
            info.bindings = parsed.bindings
            info.varNames = parsed.varNames
        } catch {
            info.parseError = "Couldn't parse \(project.configFile): \(error.localizedDescription)"
        }

        info.packageManager = detectPackageManager(from: dir)
        info.wranglerVersion = installedVersion(of: "wrangler", from: dir)
        info.vitePluginVersion = installedVersion(of: "@cloudflare/vite-plugin", from: dir)
        info.depsInstalled = info.wranglerVersion != nil
        info.detectedMode = usesVitePlugin(dir: dir) ? .vite : .wrangler
        info.hasDevScript = hasDevScript(dir: dir)
        return info
    }

    static func detectPackageManager(from dir: String) -> PackageManager {
        for d in ancestors(of: dir) {
            let fm = FileManager.default
            func has(_ n: String) -> Bool { fm.fileExists(atPath: (d as NSString).appendingPathComponent(n)) }
            if has("pnpm-lock.yaml") { return .pnpm }
            if has("yarn.lock") { return .yarn }
            if has("bun.lockb") || has("bun.lock") { return .bun }
            if has("package-lock.json") { return .npm }
        }
        return .npm
    }

    /// Looks in node_modules of the project and (for monorepos / hoisting) a few parents.
    static func installedVersion(of package: String, from dir: String) -> String? {
        for d in ancestors(of: dir) {
            let pkg = (d as NSString).appendingPathComponent("node_modules/\(package)/package.json")
            if let data = FileManager.default.contents(atPath: pkg),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let v = json["version"] as? String { return v }
        }
        return nil
    }

    static func usesVitePlugin(dir: String) -> Bool {
        for name in viteConfigNames {
            let path = (dir as NSString).appendingPathComponent(name)
            if let text = try? String(contentsOfFile: path, encoding: .utf8), text.contains("@cloudflare/vite-plugin") {
                return true
            }
        }
        return false
    }

    static func hasDevScript(dir: String) -> Bool {
        let path = (dir as NSString).appendingPathComponent("package.json")
        guard let data = FileManager.default.contents(atPath: path),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let scripts = json["scripts"] as? [String: Any] else { return false }
        return scripts["dev"] != nil
    }

    private static func ancestors(of dir: String, limit: Int = 5) -> [String] {
        var out: [String] = []
        var cur = (dir as NSString).standardizingPath
        for _ in 0..<limit {
            out.append(cur)
            let parent = (cur as NSString).deletingLastPathComponent
            if parent == cur || parent.isEmpty || parent == "/" { break }
            cur = parent
        }
        return out
    }
}

/// What the Explorer tab can do for a project.
enum ExplorerSupport: Equatable {
    case ok
    case tooOld(package: String, installed: String, required: String, command: String)

    static func evaluate(info: ProjectInfo, mode: RunModeKind) -> ExplorerSupport {
        if mode == .vite, let v = info.vitePluginVersion, let sv = SemVer(v), sv < AppInfo.minExplorerVitePlugin {
            return .tooOld(package: "@cloudflare/vite-plugin", installed: v,
                           required: AppInfo.minExplorerVitePlugin.description,
                           command: info.packageManager.updateCommand(for: "@cloudflare/vite-plugin"))
        }
        if let v = info.wranglerVersion, let sv = SemVer(v), sv < AppInfo.minExplorerWrangler {
            return .tooOld(package: "wrangler", installed: v,
                           required: AppInfo.minExplorerWrangler.description,
                           command: info.packageManager.updateCommand(for: "wrangler"))
        }
        return .ok
    }
}
