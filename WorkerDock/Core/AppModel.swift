import Foundation
import AppKit
import Observation

@MainActor
@Observable
final class AppModel {
    static let shared = AppModel()   // tests create their own instances

    // Persisted
    var settings = AppSettings() { didSet { if settings != oldValue { settingsChanged(old: oldValue) } } }
    private(set) var roots: [String] = []
    private(set) var projects: [Project] = []

    // Derived / transient
    private(set) var infos: [String: ProjectInfo] = [:]
    var selection: String?
    var selectedTab: DetailTab = .overview
    var showHidden = false
    private(set) var isScanning = false
    private(set) var isDemo = ProcessInfo.processInfo.environment["WORKERDOCK_DEMO"] != nil
    private(set) var shellEnvLoaded = false
    private(set) var rawShellEnv: [String: String] = ShellEnvironment.fallback()

    @ObservationIgnored private var runtimes: [String: ProjectRuntime] = [:]
    @ObservationIgnored let processManager = ProcessManager()
    @ObservationIgnored private var watcher: RootWatcher?
    @ObservationIgnored private var pollTask: Task<Void, Never>?
    @ObservationIgnored private var windowVisible = false

    // MARK: - Demo (marketing screenshots)

    func loadDemoState() {
        // Lets screenshots open a given tab: WORKERDOCK_DEMO_TAB=logs|explorer|settings.
        if let t = ProcessInfo.processInfo.environment["WORKERDOCK_DEMO_TAB"], let tab = DetailTab(rawValue: t.capitalized) { selectedTab = tab }
        var ps: [Project] = []
        var infoMap: [String: ProjectInfo] = [:]
        for e in DemoData.entries {
            let path = (e.folder as NSString).expandingTildeInPath
            var p = Project(path: path, configFile: e.config, name: e.name, rootPath: (path as NSString).deletingLastPathComponent)
            p.port = e.port
            ps.append(p)
            var info = ProjectInfo()
            info.configKind = ConfigParser.kind(forFile: e.config)
            info.workerName = e.name
            info.mainEntry = e.entry
            info.compatibilityDate = e.date
            info.bindings = e.bindings
            info.varNames = e.vars
            info.wranglerVersion = e.wrangler
            info.packageManager = e.pm
            info.detectedMode = e.mode
            info.hasDevScript = e.mode != .wrangler
            info.depsInstalled = true
            info.nodeModulesPresent = true
            info.pagesOutputDir = e.pages
            info.framework = e.framework
            info.cms = e.cms
            infoMap[path] = info
            let rt = runtime(path)
            rt.status = e.status
            if e.status == .running, let port = e.port {
                rt.url = URL(string: "http://localhost:\(port)")
                rt.memoryBytes = UInt64(e.memoryMB * 1_048_576)
            }
            for line in (e.name == "aurora-api" ? DemoData.aLogs : ["▶ ready", "[wrangler:info] Ready on http://localhost:\(e.port ?? 8787)"]) {
                rt.log.append(line)
            }
        }
        projects = ps
        infos = infoMap
        roots = ["~/Sites"]
        selection = visibleProjects.first?.id
    }

    // MARK: - Lifecycle

    init() {
        if let s = Persistence.load(AppSettings.self, file: "settings.json") { settings = s }
        if let r = Persistence.load(Registry.self, file: "registry.json") {
            roots = r.roots
            projects = r.projects
        }
        for p in projects { _ = runtime(p.id) }
        selection = visibleProjects.first?.id
    }

    func bootstrap() {
        applyAppearance()
        refreshInstalledApps()
        Task {
            if isDemo {
                loadDemoState()
            } else {
                rawShellEnv = await ShellEnvironment.resolve()
                shellEnvLoaded = true
                await refreshAllInfo()
                await refreshExternal()
                offerToStopOrphans()
                updateWatcher()
            }
            // Debug hook: lets scripts exercise "Add Root Folder" without the file picker.
            let env = ProcessInfo.processInfo.environment
            if let root = env["WORKERDOCK_DEBUG_ADD_ROOT"] { roots.contains((root as NSString).standardizingPath) ? rescan() : addRoot(root) }
            if let name = env["WORKERDOCK_DEBUG_START"], let out = env["WORKERDOCK_DEBUG_OUT"] { await debugStart(name: name, reportPath: out) }
            if let dir = env["WORKERDOCK_DEBUG_SNAPSHOT"] { await debugSnapshot(dir: dir, env: env) }
        }
    }

    /// Debug hook (env-only): render each tab of the window to PNG files, for visual checks.
    private func debugSnapshot(dir: String, env: [String: String]) async {
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        let dark = env["WORKERDOCK_DEBUG_SCHEME"] == "dark"
        NSApp.appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
        let name = env["WORKERDOCK_DEBUG_PROJECT"] ?? ""
        for _ in 0..<120 where !projects.contains(where: { $0.name == name }) { try? await Task.sleep(nanoseconds: 500_000_000) }
        guard let p = projects.first(where: { $0.name == name }) else { exit(1) }
        selection = p.id
        await refreshInfo(p.id)
        if env["WORKERDOCK_DEBUG_ATTACH"] != nil { await startAsync(p.id) }
        try? await Task.sleep(nanoseconds: 4_000_000_000)
        guard let window = NSApp.windows.first(where: { $0.contentView != nil && $0.styleMask.contains(.titled) }) else { exit(2) }
        var size = NSSize(width: 1180, height: 780)
        if let s = env["WORKERDOCK_DEBUG_SIZE"]?.split(separator: "x").compactMap({ Double($0) }), s.count == 2 { size = NSSize(width: s[0], height: s[1]) }
        window.setContentSize(size)
        window.center()
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        window.makeFirstResponder(nil)
        try? await Task.sleep(nanoseconds: 1_500_000_000)
        for tab in DetailTab.allCases {
            selectedTab = tab
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            guard let view = window.contentView?.superview ?? window.contentView,
                  let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { continue }
            view.cacheDisplay(in: view.bounds, to: rep)
            try? rep.representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: "\(dir)/\(dark ? "dark" : "light")-\(tab.rawValue.lowercased()).png"))
        }
        exit(0)
    }

    /// Debug hook (env-only): start a project by name, wait, write a status report, stop it, exit.
    private func debugStart(name: String, reportPath: String) async {
        for _ in 0..<120 where !projects.contains(where: { $0.name == name }) { try? await Task.sleep(nanoseconds: 500_000_000) }
        guard let p = projects.first(where: { $0.name == name }) else {
            try? "project not found".write(toFile: reportPath, atomically: true, encoding: .utf8); exit(1)
        }
        await refreshInfo(p.id)
        await startAsync(p.id)
        try? await Task.sleep(nanoseconds: 30_000_000_000)
        let rt = runtime(p.id)
        let links = quickLinks(p.id).map { $0.url(base: rt.url ?? URL(string: "http://none")!)?.absoluteString ?? "" }
        let report = "mode: \(effectiveMode(p).title)\nstatus: \(rt.status.label)\nurl: \(rt.url?.absoluteString ?? "nil")\nlinks: \(links)\n--- log\n" + rt.log.lines.suffix(25).map(\.text).joined(separator: "\n")
        try? report.write(toFile: reportPath, atomically: true, encoding: .utf8)
        if rt.managed { await stopAsync(p.id) }   // never touch servers we merely attached to
        try? await Task.sleep(nanoseconds: 2_000_000_000)
        exit(0)
    }

    func windowVisibilityChanged(_ visible: Bool) {
        windowVisible = visible
        pollTask?.cancel()
        guard visible else { return }
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.refreshExternal()
                try? await Task.sleep(nanoseconds: 5_000_000_000)
            }
        }
    }

    // MARK: - Accessors

    func runtime(_ id: String) -> ProjectRuntime {
        if let r = runtimes[id] { return r }
        let r = ProjectRuntime()
        runtimes[id] = r
        return r
    }

    func project(_ id: String) -> Project? { projects.first { $0.id == id } }

    func info(_ id: String) -> ProjectInfo? { infos[id] }

    var visibleProjects: [Project] {
        projects
            .filter { showHidden || !$0.hidden }
            .sorted {
                let c = $0.name.localizedCaseInsensitiveCompare($1.name)
                return c == .orderedSame ? $0.path < $1.path : c == .orderedAscending
            }
    }

    var hasHiddenProjects: Bool { projects.contains { $0.hidden } }

    var runningCount: Int { projects.filter { !$0.hidden && runtime($0.id).status.isActive }.count }

    var environment: [String: String] {
        ShellEnvironment.effective(base: rawShellEnv, nodePath: settings.nodePath)
    }

    /// Wrangler-based modes need wrangler installed; script-based modes just need node_modules.
    func depsReady(_ p: Project) -> Bool {
        guard let info = infos[p.id] else { return false }
        switch effectiveMode(p) {
        case .wrangler, .pages: return info.depsInstalled
        case .vite, .devScript: return info.nodeModulesPresent
        case .custom: return true
        }
    }

    /// The command WorkerDock runs for this project, without ports, for display (e.g. "npm run dev").
    func runCommandSummary(_ p: Project) -> String? {
        let pm = infos[p.id]?.packageManager ?? .npm
        switch effectiveMode(p) {
        case .wrangler: return "\(pm.execWrangler) dev"
        case .pages: return "\(pm.execWrangler) pages dev"
        case .vite, .devScript: return pm.runDev
        case .custom:
            let c = (p.customCommand ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            return c.isEmpty ? nil : c
        }
    }

    func effectiveMode(_ p: Project) -> RunModeKind {
        p.runModeOverride ?? infos[p.id]?.detectedMode ?? .wrangler
    }

    // MARK: - Registry

    private func saveRegistry() {
        guard !isDemo else { return }
        Persistence.save(Registry(roots: roots, projects: projects), file: "registry.json")
    }

    private func update(_ id: String, _ change: (inout Project) -> Void) {
        guard let i = projects.firstIndex(where: { $0.id == id }) else { return }
        change(&projects[i])
        saveRegistry()
    }

    func setRunMode(_ id: String, _ mode: RunModeKind?) { update(id) { $0.runModeOverride = mode } }
    func setCustomCommand(_ id: String, _ cmd: String) { update(id) { $0.customCommand = cmd } }
    func setPort(_ id: String, _ port: Int?) { update(id) { $0.port = port } }
    func setHidden(_ id: String, _ hidden: Bool) {
        update(id) { $0.hidden = hidden }
        if hidden && selection == id { selection = visibleProjects.first?.id }
    }

    func removeManual(_ id: String) {
        guard let p = project(id), p.rootPath == nil else { return }
        projects.removeAll { $0.id == id }
        runtimes[id] = nil
        infos[id] = nil
        if selection == id { selection = visibleProjects.first?.id }
        saveRegistry()
    }

    func addRoot(_ path: String) {
        let std = (path as NSString).standardizingPath
        guard !roots.contains(std) else { return }
        roots.append(std)
        saveRegistry()
        updateWatcher()
        rescan()
    }

    func removeRoot(_ path: String) {
        roots.removeAll { $0 == path }
        let gone = projects.filter { $0.rootPath == path }.map(\.id)
        projects.removeAll { $0.rootPath == path }
        for id in gone { runtimes[id] = nil; infos[id] = nil }
        if let s = selection, gone.contains(s) { selection = visibleProjects.first?.id }
        saveRegistry()
        updateWatcher()
    }

    /// Returns an error message, or nil on success.
    @discardableResult
    func addProjectFolder(_ path: String) -> String? {
        let std = (path as NSString).standardizingPath
        guard let found = ProjectScanner.config(inProjectFolder: std) else {
            return "No wrangler.toml, wrangler.json or wrangler.jsonc found in that folder."
        }
        if project(std) != nil {
            setHidden(std, false)
            selection = std
            return nil
        }
        let p = Project(path: std, configFile: found.file, name: (std as NSString).lastPathComponent, rootPath: nil)
        projects.append(p)
        _ = runtime(p.id)
        saveRegistry()
        selection = p.id
        Task { await refreshInfo(p.id) }
        return nil
    }

    // MARK: - Scanning

    func rescan() {
        guard !isScanning else { return }
        isScanning = true
        let roots = self.roots
        Task {
            // Scan and inspect off the main thread, so projects appear already named and sorted.
            let results = await Task.detached(priority: .utility) { () -> [(String, [(DiscoveredConfig, ProjectInfo)])] in
                roots.map { root in
                    (root, ProjectScanner.scan(root: root).map { c in
                        let id = (c.dir as NSString).standardizingPath
                        let stub = Project(path: id, configFile: c.file, name: (id as NSString).lastPathComponent, rootPath: root)
                        return (c, ProjectInspector.inspect(stub))
                    })
                }
            }.value
            merge(results)
            isScanning = false
            await refreshExternal()
        }
    }

    private func merge(_ results: [(String, [(DiscoveredConfig, ProjectInfo)])]) {
        var seen = Set<String>()
        var newProjects = projects
        var newInfos = infos
        for (root, configs) in results {
            for (c, info) in configs {
                let id = (c.dir as NSString).standardizingPath
                seen.insert(id)
                newInfos[id] = info
                let name = info.workerName ?? (id as NSString).lastPathComponent
                if let i = newProjects.firstIndex(where: { $0.id == id }) {
                    newProjects[i].configFile = c.file
                    newProjects[i].name = name
                } else {
                    newProjects.append(Project(path: id, configFile: c.file, name: name, rootPath: root))
                }
            }
        }
        // Drop discovered projects whose config vanished (never manual ones).
        let scannedRoots = Set(results.map(\.0))
        newProjects.removeAll { p in
            guard let r = p.rootPath, scannedRoots.contains(r) else { return false }
            return !seen.contains(p.id)
        }
        let keep = Set(newProjects.map(\.id))
        runtimes = runtimes.filter { keep.contains($0.key) }
        for p in newProjects { _ = runtime(p.id) }
        infos = newInfos.filter { keep.contains($0.key) }
        projects = newProjects      // one mutation, so the sidebar updates once
        saveRegistry()
        selectFirstIfNeeded()
    }

    /// Deferred a tick so the sidebar finishes inserting rows before selection changes.
    private func selectFirstIfNeeded() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            guard let self else { return }
            if self.selection == nil || self.project(self.selection!) == nil {
                self.selection = self.visibleProjects.first?.id
            }
        }
    }

    func refreshInfo(_ id: String) async {
        guard !isDemo, let p = project(id) else { return }
        let info = await Task.detached(priority: .utility) { ProjectInspector.inspect(p) }.value
        applyInfos([(id, info)])
    }

    func refreshAllInfo() async {
        guard !isDemo else { return }
        let snapshot = projects
        let results = await Task.detached(priority: .utility) {
            snapshot.map { ($0.id, ProjectInspector.inspect($0)) }
        }.value
        applyInfos(results)
    }

    /// Applies inspection results in one batch. Many small mutations while the sidebar list
    /// is updating make AppKit's table view complain about reentrancy.
    private func applyInfos(_ results: [(String, ProjectInfo)]) {
        var newInfos = infos
        var newProjects = projects
        var renamed = false
        for (id, info) in results {
            guard let i = newProjects.firstIndex(where: { $0.id == id }) else { continue }
            newInfos[id] = info
            if let name = info.workerName, newProjects[i].name != name {
                newProjects[i].name = name
                renamed = true
            }
        }
        infos = newInfos
        if renamed {
            projects = newProjects
            saveRegistry()
        }
    }

    /// Worker names aren't unique across folders; add the folder when two projects share one.
    func displayName(_ p: Project) -> String {
        guard projects.contains(where: { $0.id != p.id && $0.name == p.name }) else { return p.name }
        let parts = p.path.split(separator: "/").suffix(2).joined(separator: "/")
        return "\(p.name)  (\(parts))"
    }

    private func updateWatcher() {
        watcher?.stop()
        watcher = nil
        guard settings.watchRoots, !roots.isEmpty else { return }
        watcher = RootWatcher(paths: roots) { [weak self] in
            Task { @MainActor in self?.rescan() }
        }
    }

    /// Forces the app (all windows, the menu bar and Settings) into light or dark, or follows the system.
    func applyAppearance() {
        switch settings.appearance {
        case .system: NSApp?.appearance = nil
        case .light: NSApp?.appearance = NSAppearance(named: .aqua)
        case .dark: NSApp?.appearance = NSAppearance(named: .darkAqua)
        }
    }

    private func settingsChanged(old: AppSettings) {
        if old.appearance != settings.appearance { applyAppearance() }
        guard !isDemo else { return }
        Persistence.save(settings, file: "settings.json")
        if old.watchRoots != settings.watchRoots { updateWatcher() }
    }

    func reloadShellEnvironment() {
        shellEnvLoaded = false
        Task {
            rawShellEnv = await ShellEnvironment.resolve()
            shellEnvLoaded = true
        }
    }

    // MARK: - Start / stop

    func start(_ id: String) { Task { await startAsync(id) } }
    func stop(_ id: String) { Task { await stopAsync(id) } }
    func restart(_ id: String) { Task { await restartAsync(id) } }

    func startAsync(_ id: String) async {
        guard let p = project(id) else { return }
        let rt = runtime(id)
        guard !rt.status.isActive else { return }
        guard let info = infos[id] else { await refreshInfo(id); return await startAsync(id) }

        let mode = effectiveMode(p)
        let command: String
        switch mode {
        case .wrangler, .vite, .pages, .devScript:
            guard depsReady(p) else {
                rt.status = .error("Dependencies not installed")
                return
            }
            if mode == .devScript && !info.hasDevScript {
                rt.status = .error("No \"dev\" script in package.json")
                return
            }
            if mode == .wrangler || mode == .pages {
                let others = Set(projects.filter { $0.id != id }.flatMap { [$0.port, $0.inspectorPort].compactMap { $0 } })
                var port = p.port ?? 0
                if port == 0 || !PortAllocator.isFree(port) || others.contains(port) {
                    port = PortAllocator.allocate(start: 8787, avoiding: others)
                }
                var ip = p.inspectorPort ?? 0
                if ip == 0 || !PortAllocator.isFree(ip) || others.contains(ip) || ip == port {
                    ip = PortAllocator.allocate(start: 9230, avoiding: others.union([port]))
                }
                update(id) { $0.port = port; $0.inspectorPort = ip }
                if mode == .pages {
                    let dir = info.pagesOutputDir ?? "dist"
                    command = "\(info.packageManager.execWrangler) pages dev \"\(dir)\" --port \(port) --inspector-port \(ip)"
                } else {
                    command = "\(info.packageManager.execWrangler) dev --port \(port) --inspector-port \(ip)"
                }
            } else {
                command = info.packageManager.runDev
            }
        case .custom:
            let c = (p.customCommand ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            guard !c.isEmpty else {
                rt.status = .error("No custom command set (see the Settings tab)")
                return
            }
            command = c
        }

        // `dev` scripts live in the nearest package.json, which may be above the wrangler config.
        let runDir = ((mode == .vite || mode == .devScript) ? info.scriptRoot : nil) ?? p.path
        rt.status = .starting
        rt.url = nil
        rt.external = false
        rt.attachedPID = nil
        rt.sawAlreadyRunning = false
        rt.log.append("▶ \(command)")

        do {
            let pid = try await processManager.start(
                id: id, command: command, cwd: runDir, env: environment,
                onLine: { [weak self] text, isErr in
                    DispatchQueue.main.async { MainActor.assumeIsolated { self?.handleLine(id, text, isErr, mode: mode) } }
                },
                onExit: { [weak self] code, intentional in
                    DispatchQueue.main.async { MainActor.assumeIsolated { self?.handleExit(id, code: code, intentional: intentional) } }
                })
            rt.pid = pid
            rt.managed = true
            recordRunning(id: id, pid: pid)
            scheduleReadyFallback(id: id, pid: pid, mode: mode)
        } catch {
            rt.status = .error(error.localizedDescription)
            rt.log.append("✖ \(error.localizedDescription)", isError: true)
        }
    }

    func stopAsync(_ id: String) async {
        let rt = runtime(id)
        if rt.managed {
            await processManager.stop(id: id)
        } else if rt.external {
            stopExternal(id)
        }
    }

    func restartAsync(_ id: String) async {
        let rt = runtime(id)
        guard rt.managed else { return }
        await processManager.stop(id: id)
        // wait for the exit handler to flip state
        for _ in 0..<30 where rt.managed { try? await Task.sleep(nanoseconds: 100_000_000) }
        await startAsync(id)
    }

    func stopAll() async {
        await processManager.stopAll()
        for p in projects where runtime(p.id).managed { }
    }

    private func handleLine(_ id: String, _ text: String, _ isErr: Bool, mode: RunModeKind) {
        let rt = runtime(id)
        guard !text.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        rt.log.append(text, isError: isErr)
        if let (url, pid) = OutputParser.detectAlreadyRunning(in: text) {
            // The tool refused to start a second server; adopt the one that's already up.
            rt.url = url
            rt.attachedPID = pid
            rt.status = .running
        }
        switch OutputParser.detectAttachField(in: text) {
        case .marker?: rt.sawAlreadyRunning = true
        case .url(let u)? where rt.sawAlreadyRunning: rt.url = u
        case .pid(let pid)? where rt.sawAlreadyRunning:
            rt.attachedPID = pid
            if rt.url != nil { rt.status = .running }
        default: break
        }
        if rt.url == nil, rt.status == .starting, let url = OutputParser.detectURL(in: text, mode: mode) {
            rt.url = url
            rt.status = .running
            if mode == .wrangler || mode == .pages, let port = url.port { update(id) { $0.port = port } }
        }
    }

    private func handleExit(_ id: String, code: Int32, intentional: Bool) {
        let rt = runtime(id)
        rt.log.append("■ process exited (code \(code))")
        rt.managed = false
        rt.pid = nil
        if let attached = rt.attachedPID, kill(pid_t(attached), 0) == 0 {
            rt.log.append("↪ A dev server is already running (pid \(attached)); attached to it.")
            rt.external = true
            rt.externalPIDs = [attached]
            rt.status = .running
            removeRunning(id)
            return
        }
        rt.attachedPID = nil
        rt.url = nil
        rt.memoryBytes = nil
        rt.status = (intentional || code == 0) ? .stopped : .error("Exited with code \(code)")
        removeRunning(id)
    }

    /// If no "Ready on" line shows up (custom commands, odd output), assume it's up after a while.
    private func scheduleReadyFallback(id: String, pid: Int32, mode: RunModeKind) {
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: 20_000_000_000)
            guard let self else { return }
            let rt = self.runtime(id)
            guard rt.status == .starting, rt.pid == pid else { return }
            rt.status = .running
            if mode == .wrangler || mode == .pages, let port = self.project(id)?.port {
                rt.url = URL(string: "http://localhost:\(port)")
            }
        }
    }

    // MARK: - External (terminal-started) processes

    func refreshExternal() async {
        guard !isDemo else { return }
        let managed = Set(runtimes.values.compactMap { $0.managed ? $0.pid.map { pid_t($0) } : nil })
        let list = projects.map { (id: $0.id, path: $0.path, port: $0.port) }
        let found = await Task.detached(priority: .utility) {
            RunningDetector.scan(projects: list, excludingPGIDs: managed)
        }.value

        for p in projects {
            let rt = runtime(p.id)
            if rt.managed || rt.status == .starting { continue }
            if let ext = found[p.id] {
                rt.external = true
                rt.externalPIDs = ext.pids
                rt.status = .running
                if let port = ext.port { rt.url = URL(string: "http://localhost:\(port)") }
            } else if rt.external, rt.externalPIDs.contains(where: { kill(pid_t($0), 0) == 0 }) {
                continue   // an attached server that isn't workerd-based is still alive
            } else if rt.external {
                rt.external = false
                rt.attachedPID = nil
                rt.externalPIDs = []
                rt.url = nil
                rt.memoryBytes = nil
                rt.status = .stopped
            }
        }
    }

    private func stopExternal(_ id: String) {
        let rt = runtime(id)
        guard let p = project(id) else { return }
        let alert = NSAlert()
        alert.messageText = "Stop \(p.name)?"
        alert.informativeText = "This project wasn't started by \(AppInfo.name) (probably from a terminal). Stopping it will send a quit signal to its wrangler/workerd processes."
        alert.addButton(withTitle: "Stop")
        alert.addButton(withTitle: "Cancel")
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        let pids = rt.externalPIDs
        for pid in pids { kill(pid_t(pid), SIGTERM) }
        rt.attachedPID = nil
        Task {
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            await refreshExternal()
        }
    }

    // MARK: - Orphans from a previous crash

    private func recordRunning(id: String, pid: Int32) {
        guard let start = ProcessInspector.startSec(of: pid) else { return }
        var recs = Persistence.load([RunningRecord].self, file: "running.json") ?? []
        recs.removeAll { $0.projectID == id }
        recs.append(RunningRecord(projectID: id, pid: pid, startSec: start))
        Persistence.save(recs, file: "running.json")
    }

    private func removeRunning(_ id: String) {
        var recs = Persistence.load([RunningRecord].self, file: "running.json") ?? []
        recs.removeAll { $0.projectID == id }
        if recs.isEmpty { Persistence.remove(file: "running.json") } else { Persistence.save(recs, file: "running.json") }
    }

    private func offerToStopOrphans() {
        let recs = Persistence.load([RunningRecord].self, file: "running.json") ?? []
        let orphans = recs.filter { ProcessInspector.isSameProcess(pid: $0.pid, startSec: $0.startSec) }
        Persistence.remove(file: "running.json")
        guard !orphans.isEmpty else { return }

        let names = orphans.map { project($0.projectID)?.name ?? $0.projectID }.joined(separator: ", ")
        let alert = NSAlert()
        alert.messageText = "Found projects still running from a previous session"
        alert.informativeText = "\(names)\n\nThese were started by \(AppInfo.name) and weren't shut down (the app probably crashed). Stop them?"
        alert.addButton(withTitle: "Stop Them")
        alert.addButton(withTitle: "Leave Running")
        if alert.runModal() == .alertFirstButtonReturn {
            Task {
                for o in orphans { await ProcessManager.terminateGroup(o.pid) }
                await refreshExternal()
            }
        }
    }

    // MARK: - Quit handling

    func confirmQuit() -> Bool {
        let active = projects.filter { runtime($0.id).managed }
        if active.isEmpty { return true }
        let alert = NSAlert()
        alert.messageText = "Stop \(active.count) running project\(active.count == 1 ? "" : "s") and quit?"
        alert.informativeText = active.map(\.name).joined(separator: ", ")
        alert.addButton(withTitle: "Stop and Quit")
        alert.addButton(withTitle: "Cancel")
        return alert.runModal() == .alertFirstButtonReturn
    }

    // MARK: - Actions

    func openInBrowser(_ id: String) {
        if let url = runtime(id).url { NSWorkspace.shared.open(url) }
    }

    func quickLinks(_ id: String) -> [ProjectLink] { ProjectLink.links(for: infos[id]) }

    func open(_ link: ProjectLink, for id: String) {
        guard let base = runtime(id).url, let url = link.url(base: base) else { return }
        NSWorkspace.shared.open(url)
    }

    func openExplorer(_ id: String) {
        if let url = runtime(id).explorerURL { NSWorkspace.shared.open(url) }
    }

    func reveal(_ id: String) {
        guard let p = project(id) else { return }
        NSWorkspace.shared.activateFileViewerSelecting([p.url])
    }

    // MARK: - Terminal and editor apps

    private(set) var installedTerminals: [ExternalApp] = AppCatalog.installed(AppCatalog.terminals)

    private(set) var installedEditors: [ExternalApp] = AppCatalog.installed(AppCatalog.editors)

    func refreshInstalledApps() {
        installedTerminals = AppCatalog.installed(AppCatalog.terminals)
        installedEditors = AppCatalog.installed(AppCatalog.editors)
    }

    /// The editor that "Open in Editor" uses: the saved choice, else the first one installed.
    var editorApp: ExternalApp? { AppCatalog.resolve(settings.editorApp, among: installedEditors) }

    /// The terminal that "Open Terminal" uses: the saved choice, else the first one installed.
    var terminalApp: ExternalApp? { AppCatalog.resolve(settings.terminalApp, among: installedTerminals) }

    func openTerminal(_ id: String) {
        guard let p = project(id) else { return }
        guard let app = terminalApp else { showError("No terminal app found. Choose one in Settings."); return }
        NSWorkspace.shared.open([p.url], withApplicationAt: app.url, configuration: NSWorkspace.OpenConfiguration())
    }

    /// Opens the project folder, or one file inside it, in the chosen editor.
    func openInEditor(_ id: String, file: String? = nil) {
        guard let p = project(id) else { return }
        let target = file.map { URL(fileURLWithPath: p.path).appendingPathComponent($0) } ?? p.url
        // A custom command, when set, wins over the chosen app.
        let command = settings.editorCommand.trimmingCharacters(in: .whitespaces)
        if !command.isEmpty {
            let env = environment
            Task.detached { _ = Self.runShell("\(command) \"\(target.path)\"", env: env) }
            return
        }
        guard let app = editorApp else { showError("No code editor found. Choose one in Settings."); return }
        NSWorkspace.shared.open([target], withApplicationAt: app.url, configuration: NSWorkspace.OpenConfiguration())
    }

    nonisolated private static func runShell(_ command: String, env: [String: String]) -> Bool {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/bin/sh")
        p.arguments = ["-c", command]
        p.environment = env
        p.standardOutput = FileHandle.nullDevice
        p.standardError = FileHandle.nullDevice
        do { try p.run() } catch { return false }
        p.waitUntilExit()
        return p.terminationStatus == 0
    }

    // MARK: - Memory (only called while the Overview tab is visible)

    func updateMemory(_ id: String) async {
        guard !isDemo else { return }
        let rt = runtime(id)
        guard rt.status == .running || rt.status == .starting else { rt.memoryBytes = nil; return }
        let pid = rt.pid
        let ext = rt.externalPIDs
        let bytes = await Task.detached(priority: .utility) { () -> UInt64 in
            if let pid { return ProcessInspector.groupResidentBytes(pgid: pid_t(pid)) }
            return ext.reduce(0) { $0 + ProcessInspector.residentBytes(pid_t($1)) }
        }.value
        rt.memoryBytes = bytes
    }
}
