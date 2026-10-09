import Foundation
import Observation

enum AppInfo {
    /// Single place to rename the app (also rename in project.yml).
    static let name = "WorkerDock"
    static let supportDirName = "WorkerDock"
    static let minExplorerWrangler = SemVer("4.82.1")!
    static let minExplorerVitePlugin = SemVer("1.32.0")!
    static let explorerPath = "/cdn-cgi/explorer"
    static let website = URL(string: "https://workerdock.app")!
    /// Optional "support the project" page. Leave nil until the checkout link exists; the UI hides the button.
    static let supportURL: URL? = nil

    static var version: String {
        let v = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.0.0"
        let b = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0"
        return "\(v) (\(b))"
    }
}

// MARK: - Versions

struct SemVer: Comparable, CustomStringConvertible {
    let parts: [Int]

    init?(_ string: String) {
        var s = string.trimmingCharacters(in: .whitespaces)
        if s.hasPrefix("v") { s.removeFirst() }
        let core = s.split(whereSeparator: { $0 == "-" || $0 == "+" }).first.map(String.init) ?? s
        let nums = core.split(separator: ".").compactMap { Int($0) }
        guard !nums.isEmpty else { return nil }
        parts = nums + Array(repeating: 0, count: max(0, 3 - nums.count))
    }

    static func < (a: SemVer, b: SemVer) -> Bool {
        for i in 0..<max(a.parts.count, b.parts.count) {
            let x = i < a.parts.count ? a.parts[i] : 0
            let y = i < b.parts.count ? b.parts[i] : 0
            if x != y { return x < y }
        }
        return false
    }

    var description: String { parts.map(String.init).joined(separator: ".") }
}

// MARK: - Project model

enum RunModeKind: String, Codable, CaseIterable, Identifiable {
    case wrangler, vite, custom, pages, devScript
    var id: String { rawValue }
    var title: String {
        switch self {
        case .wrangler: return "Plain Wrangler"
        case .pages: return "Wrangler Pages"
        case .devScript: return "Project dev script"
        case .vite: return "Vite plugin"
        case .custom: return "Custom command"
        }
    }
}

enum ConfigKind: String, Codable {
    case toml, json, jsonc
    var title: String {
        switch self {
        case .toml: return "TOML"
        case .json: return "JSON"
        case .jsonc: return "JSONC"
        }
    }
}

enum PackageManager: String, Codable, CaseIterable {
    case npm, pnpm, yarn, bun

    var execWrangler: String {
        switch self {
        case .npm: return "npx wrangler"
        case .pnpm: return "pnpm exec wrangler"
        case .yarn: return "yarn wrangler"
        case .bun: return "bunx wrangler"
        }
    }
    var runDev: String { runDev(port: nil) }

    /// The dev script, optionally with `--port N` passed through to the tool the script ends with.
    func runDev(port: Int?) -> String {
        let base: String
        switch self {
        case .npm: base = "npm run dev"
        case .pnpm: base = "pnpm run dev"
        case .yarn: base = "yarn dev"
        case .bun: base = "bun run dev"
        }
        guard let port else { return base }
        return self == .npm ? "\(base) -- --port \(port)" : "\(base) --port \(port)"
    }
    var install: String { "\(rawValue) install" }

    func updateCommand(for package: String) -> String {
        switch self {
        case .npm: return "npm install -D \(package)@latest"
        case .pnpm: return "pnpm add -D \(package)@latest"
        case .yarn: return "yarn add -D \(package)@latest"
        case .bun: return "bun add -d \(package)@latest"
        }
    }
}

struct Project: Codable, Identifiable, Hashable {
    /// Folder path containing the wrangler config. Doubles as the stable id.
    var path: String
    var configFile: String
    var name: String
    /// Root folder this was discovered under; nil when added manually.
    var rootPath: String?
    var hidden: Bool = false
    /// Optional so registries saved before favourites existed still load.
    var favorite: Bool?
    var port: Int?
    var inspectorPort: Int?
    var runModeOverride: RunModeKind?
    var customCommand: String?

    var id: String { path }
    var isFavorite: Bool { favorite == true }
    var url: URL { URL(fileURLWithPath: path) }
}

enum BindingKind: String, CaseIterable {
    case d1, kv, r2, queue, durableObject, workflow, service
    case ai, vectorize, hyperdrive, analytics, browser, assets, other

    var title: String {
        switch self {
        case .d1: return "D1 databases"
        case .kv: return "KV namespaces"
        case .r2: return "R2 buckets"
        case .queue: return "Queues"
        case .durableObject: return "Durable Objects"
        case .workflow: return "Workflows"
        case .service: return "Service bindings"
        case .ai: return "Workers AI"
        case .vectorize: return "Vectorize"
        case .hyperdrive: return "Hyperdrive"
        case .analytics: return "Analytics Engine"
        case .browser: return "Browser Rendering"
        case .assets: return "Static assets"
        case .other: return "Other"
        }
    }
    var symbol: String {
        switch self {
        case .d1: return "cylinder.split.1x2"
        case .kv: return "key"
        case .r2: return "externaldrive"
        case .queue: return "tray.full"
        case .durableObject: return "cube"
        case .workflow: return "arrow.triangle.branch"
        case .service: return "link"
        case .ai: return "sparkles"
        case .vectorize: return "point.3.connected.trianglepath.dotted"
        case .hyperdrive: return "bolt"
        case .analytics: return "chart.bar"
        case .browser: return "safari"
        case .assets: return "photo.on.rectangle"
        case .other: return "square.dashed"
        }
    }
}

struct WorkerBinding: Hashable, Identifiable {
    var kind: BindingKind
    var name: String
    var detail: String?
    var id: String { "\(kind.rawValue):\(name):\(detail ?? "")" }
}

struct ProjectInfo {
    var configKind: ConfigKind = .jsonc
    var workerName: String?
    var mainEntry: String?
    var compatibilityDate: String?
    var bindings: [WorkerBinding] = []
    /// Names only. Values are never read into memory.
    var varNames: [String] = []
    var parseError: String?
    var wranglerVersion: String?
    var vitePluginVersion: String?
    var packageManager: PackageManager = .npm
    var detectedMode: RunModeKind = .wrangler
    var hasDevScript = false
    var depsInstalled = false
    var nodeModulesPresent = false
    /// Set when the config has `pages_build_output_dir` (a Cloudflare Pages project).
    var pagesOutputDir: String?
    /// Detected web framework (Astro, Nuxt, Next.js, SvelteKit…), if any.
    var framework: String?
    /// Folder holding the lockfile / workspace root (where installs should run); may be above the config folder.
    var packageRoot: String?
    /// Nearest folder with a package.json (where `dev` scripts live).
    var scriptRoot: String?
    /// Detected CMS (currently EmDash), which adds quick links such as its admin/login page.
    var cms: String?
}

/// A shortcut to a page served by a running project.
struct ProjectLink: Identifiable, Hashable {
    var title: String
    var path: String
    var symbol: String
    var id: String { path }

    func url(base: URL) -> URL? {
        URL(string: base.absoluteString.trimmingSuffix("/") + path)
    }

    static let site = ProjectLink(title: "Open Site", path: "/", symbol: "safari")
    static let emdashAdmin = ProjectLink(title: "Open EmDash Admin (Login)", path: "/_emdash/admin", symbol: "person.badge.key")

    static func links(for info: ProjectInfo?) -> [ProjectLink] {
        var links = [ProjectLink.site]
        if info?.cms == "EmDash" { links.append(.emdashAdmin) }
        return links
    }
}

// MARK: - Runtime state

enum ProjectStatus: Equatable {
    case stopped, starting, running
    case error(String)

    var isActive: Bool {
        switch self {
        case .starting, .running: return true
        default: return false
        }
    }
    var label: String {
        switch self {
        case .stopped: return "Stopped"
        case .starting: return "Starting…"
        case .running: return "Running"
        case .error(let m): return "Error: \(m)"
        }
    }
}

struct LogLine: Identifiable, Hashable {
    let id: Int
    let text: String
    let isError: Bool
}

@Observable
final class LogBuffer {
    static let capacity = 5000
    private(set) var lines: [LogLine] = []
    @ObservationIgnored private var nextID = 0

    func append(_ text: String, isError: Bool = false) {
        lines.append(LogLine(id: nextID, text: text, isError: isError))
        nextID += 1
        if lines.count > Self.capacity + 500 {
            lines.removeFirst(lines.count - Self.capacity)
        }
    }

    func clear() { lines.removeAll() }
}

/// A dev server that couldn't start because its port is taken, and who has it if we know.
struct PortConflict: Equatable {
    var port: Int
    var ownerID: String?
    var ownerName: String?
}

@Observable
final class ProjectRuntime {
    var portConflict: PortConflict?
    var status: ProjectStatus = .stopped
    var url: URL?
    var pid: Int32?
    /// True when WorkerDock spawned the process (vs. detected from a terminal).
    var managed = false
    var external = false
    var externalPIDs: [Int32] = []
    var memoryBytes: UInt64?
    /// PID of a dev server that was already running when we tried to start (e.g. Astro's background server).
    var attachedPID: Int32?
    @ObservationIgnored var sawAlreadyRunning = false
    let log = LogBuffer()

    var port: Int? { url?.port }
    var explorerURL: URL? { url.flatMap { URL(string: $0.absoluteString.trimmingSuffix("/") + AppInfo.explorerPath) } }
}

extension String {
    func trimmingSuffix(_ suffix: String) -> String {
        hasSuffix(suffix) ? String(dropLast(suffix.count)) : self
    }
}

// MARK: - Persisted files

enum AppearanceMode: String, Codable, CaseIterable, Identifiable {
    case system, light, dark
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
}

struct AppSettings: Codable, Equatable {
    var appearance = AppearanceMode.system
    var showDockIcon = true
    var terminalApp = ""     // bundle id or path; empty = automatic
    var editorApp = ""       // bundle id or path; empty = automatic
    var editorCommand = ""   // optional shell command that overrides editorApp
    var nodePath = ""
    var watchRoots = false

    init() {}
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        appearance = try c.decodeIfPresent(AppearanceMode.self, forKey: .appearance) ?? .system
        showDockIcon = try c.decodeIfPresent(Bool.self, forKey: .showDockIcon) ?? true
        terminalApp = try c.decodeIfPresent(String.self, forKey: .terminalApp) ?? ""
        editorApp = try c.decodeIfPresent(String.self, forKey: .editorApp) ?? ""
        // "code" used to be the default command; it is now covered by automatic detection.
        let legacy = try c.decodeIfPresent(String.self, forKey: .editorCommand) ?? ""
        editorCommand = legacy == "code" ? "" : legacy
        nodePath = try c.decodeIfPresent(String.self, forKey: .nodePath) ?? ""
        watchRoots = try c.decodeIfPresent(Bool.self, forKey: .watchRoots) ?? false
    }
}

struct Registry: Codable {
    var roots: [String] = []
    var projects: [Project] = []
}

struct RunningRecord: Codable {
    var projectID: String
    var pid: Int32
    var startSec: UInt64
}
