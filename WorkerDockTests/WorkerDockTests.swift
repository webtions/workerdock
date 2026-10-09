import XCTest
import Darwin
@testable import WorkerDock

final class ParsingTests: XCTestCase {
    func testSemVer() {
        XCTAssertTrue(SemVer("4.82.0")! < SemVer("4.82.1")!)
        XCTAssertTrue(SemVer("4.9.0")! < SemVer("4.82.1")!)
        XCTAssertFalse(SemVer("5.0.0")! < SemVer("4.82.1")!)
        XCTAssertEqual(SemVer("v4.82.1-beta.2")!, SemVer("4.82.1")!.self)
    }

    func testJSONCStripsCommentsAndTrailingCommas() throws {
        let text = """
        {
          // line comment
          "name": "my-worker", /* block */
          "url": "https://example.com//not-a-comment",
          "vars": { "A": "x,]", "B": "y", },
          "kv_namespaces": [ { "binding": "KV", }, ],
        }
        """
        let d = try ConfigParser.dictionary(from: text, kind: .jsonc)
        XCTAssertEqual(d["name"] as? String, "my-worker")
        XCTAssertEqual(d["url"] as? String, "https://example.com//not-a-comment")
        let cfg = ConfigParser.extract(d)
        XCTAssertEqual(cfg.varNames, ["A", "B"])
        XCTAssertEqual(cfg.bindings.map(\.name), ["KV"])
    }

    func testTOMLBindingsNamesOnly() throws {
        let text = """
        name = "api"
        main = "src/index.ts"
        compatibility_date = "2025-01-01"

        [vars]
        API_KEY = "super-secret"

        [[d1_databases]]
        binding = "DB"
        database_name = "prod-db"

        [[kv_namespaces]]
        binding = "CACHE"
        id = "abc"

        [[r2_buckets]]
        binding = "FILES"
        bucket_name = "files"

        [[queues.producers]]
        binding = "JOBS"
        queue = "jobs"

        [[durable_objects.bindings]]
        name = "COUNTER"
        class_name = "Counter"

        [[workflows]]
        binding = "WF"
        name = "wf"
        class_name = "MyWorkflow"

        [[services]]
        binding = "AUTH"
        service = "auth-worker"
        """
        let cfg = ConfigParser.extract(try ConfigParser.dictionary(from: text, kind: .toml))
        XCTAssertEqual(cfg.workerName, "api")
        XCTAssertEqual(cfg.varNames, ["API_KEY"])
        let kinds = Set(cfg.bindings.map(\.kind))
        XCTAssertEqual(kinds, [.d1, .kv, .r2, .queue, .durableObject, .workflow, .service])
        XCTAssertFalse(cfg.bindings.contains { $0.name.contains("secret") || ($0.detail ?? "").contains("secret") })
    }

    func testOutputParser() {
        XCTAssertEqual(OutputParser.stripANSI("\u{1B}[32mReady\u{1B}[0m on"), "Ready on")
        XCTAssertEqual(OutputParser.detectURL(in: "[wrangler:info] Ready on http://localhost:8788", mode: .wrangler)?.port, 8788)
        XCTAssertNil(OutputParser.detectURL(in: "  ➜  Local:   http://localhost:5173/", mode: .wrangler))
        XCTAssertEqual(OutputParser.detectURL(in: "  ➜  Local:   http://localhost:5173/", mode: .vite)?.port, 5173)
    }

    func testPortInUseIsDetected() {
        XCTAssertEqual(OutputParser.detectPortInUse(in: "✘ [ERROR] Address already in use (127.0.0.1:8788). Please check"), 8788)
        XCTAssertEqual(OutputParser.detectPortInUse(in: "Error: listen EADDRINUSE: address already in use :::4321"), 4321)
        XCTAssertEqual(OutputParser.detectPortInUse(in: "Port 5173 is already in use"), 5173)
        XCTAssertNil(OutputParser.detectPortInUse(in: "[wrangler:info] Ready on http://localhost:8787"))
        XCTAssertNil(OutputParser.detectPortInUse(in: "GET /api/ports 200 OK"))
    }

    func testRunDevPassesPortToTheScript() {
        XCTAssertEqual(PackageManager.npm.runDev(port: 8790), "npm run dev -- --port 8790")
        XCTAssertEqual(PackageManager.pnpm.runDev(port: 8790), "pnpm run dev --port 8790")
        XCTAssertEqual(PackageManager.yarn.runDev(port: nil), "yarn dev")
    }

    func testAstroAlreadyRunningLineIsParsed() {
        let line = #"{"message":"Dev server already running at http://localhost:4321 (pid 35873)\n  Stop:   astro dev stop","level":"info"}"#
        let r = OutputParser.detectAlreadyRunning(in: line)
        XCTAssertEqual(r?.0.port, 4321)
        XCTAssertEqual(r?.1, 35873)
        XCTAssertNil(OutputParser.detectAlreadyRunning(in: "Ready on http://localhost:8787"))
    }

    func testAstroMultiLineRefusalIsParsed() {
        XCTAssertEqual(OutputParser.detectAttachField(in: "Another astro dev server is already running."), .marker)
        XCTAssertEqual(OutputParser.detectAttachField(in: "  URL:  http://localhost:4321"), .url(URL(string: "http://localhost:4321")!))
        XCTAssertEqual(OutputParser.detectAttachField(in: "  PID:  35873"), .pid(35873))
        XCTAssertNil(OutputParser.detectAttachField(in: "Ready on http://localhost:8787"))
    }

    func testAgentEnvironmentMarkersAreStripped() {
        let base = ["PATH": "/usr/bin", "AI_AGENT": "claude", "CLAUDECODE": "1", "CLAUDE_CODE_ENTRYPOINT": "x",
                    "ANTHROPIC_API_KEY": "keep-me", "HOME": "/Users/x"]
        let env = ShellEnvironment.effective(base: base, nodePath: "")
        XCTAssertNil(env["AI_AGENT"]); XCTAssertNil(env["CLAUDECODE"]); XCTAssertNil(env["CLAUDE_CODE_ENTRYPOINT"])
        XCTAssertEqual(env["ANTHROPIC_API_KEY"], "keep-me")
        XCTAssertEqual(env["HOME"], "/Users/x")
    }

    func testLineSplitterHandlesPartialLines() {
        let s = LineSplitter()
        XCTAssertEqual(s.feed(Data("hel".utf8)), [])
        XCTAssertEqual(s.feed(Data("lo\nwor".utf8)), ["hello"])
        XCTAssertEqual(s.feed(Data("ld\r\n".utf8)), ["world"])
    }

    func testLogBufferIsCapped() {
        let b = LogBuffer()
        for i in 0..<(LogBuffer.capacity + 2000) { b.append("line \(i)") }
        XCTAssertLessThanOrEqual(b.lines.count, LogBuffer.capacity + 500)
        XCTAssertEqual(b.lines.last?.text, "line \(LogBuffer.capacity + 1999)")
    }

    func testShellEnvParsing() {
        let out = "motd noise\n__WORKERDOCK_ENV_BEGIN__\nPATH=/a:/b\nFOO=bar=baz\nnot an env line\n"
        let env = ShellEnvironment.parse(out)
        XCTAssertEqual(env["PATH"], "/a:/b")
        XCTAssertEqual(env["FOO"], "bar=baz")
    }

    func testLoginShellResolvesNode() {
        let env = ShellEnvironment.resolveBlocking(timeout: 15)
        XCTAssertNotNil(env["PATH"])
    }
}

final class DiscoveryTests: XCTestCase {
    var root: URL!

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent("wd-test-\(UUID().uuidString)")
        let fm = FileManager.default
        func write(_ rel: String, _ text: String) throws {
            let url = root.appendingPathComponent(rel)
            try fm.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try text.write(to: url, atomically: true, encoding: .utf8)
        }
        try write("a/wrangler.toml", "name = \"a\"")
        try write("b/wrangler.jsonc", "{ // hi\n \"name\": \"b\", }")
        try write("b/wrangler.toml", "name = \"b-old\"")
        try write("c/node_modules/dep/wrangler.json", "{}")
        try write("c/.wrangler/wrangler.json", "{}")
        try write("d/dist/wrangler.json", "{}")
        try write("e/pnpm-lock.yaml", "")
        try write("e/wrangler.json", "{\"name\":\"e\"}")
        try write("e/node_modules/wrangler/package.json", "{\"version\":\"4.90.0\"}")
        try write("e/vite.config.ts", "import { cloudflare } from '@cloudflare/vite-plugin'")
        try write("e/package.json", "{\"scripts\":{\"dev\":\"vite\"}}")
        try write("a/node_modules/wrangler/package.json", "{\"version\":\"4.70.0\"}")
    }

    override func tearDownWithError() throws { try? FileManager.default.removeItem(at: root) }

    func testScanFindsConfigsAndSkipsExcludedDirs() {
        let found = ProjectScanner.scan(root: root.path)
        let names = found.map { ($0.dir as NSString).lastPathComponent }
        XCTAssertEqual(Set(names), ["a", "b", "e"])
        XCTAssertEqual(found.first { $0.dir.hasSuffix("/b") }?.file, "wrangler.jsonc")
    }

    func testInspectorDetectsVitePnpmAndVersions() {
        let p = Project(path: root.appendingPathComponent("e").path, configFile: "wrangler.json", name: "e")
        let info = ProjectInspector.inspect(p)
        XCTAssertEqual(info.packageManager, .pnpm)
        XCTAssertEqual(info.detectedMode, .vite)
        XCTAssertEqual(info.wranglerVersion, "4.90.0")
        XCTAssertTrue(info.depsInstalled)
        XCTAssertTrue(info.hasDevScript)
        XCTAssertEqual(ExplorerSupport.evaluate(info: info, mode: .wrangler), .ok)
    }

    func testConfigInSubfolderUsesParentPackageRoot() throws {
        let fm = FileManager.default
        let parent = root.appendingPathComponent("mono")
        let sub = parent.appendingPathComponent("apps/api")
        try fm.createDirectory(at: sub, withIntermediateDirectories: true)
        try fm.createDirectory(at: parent.appendingPathComponent("node_modules/wrangler"), withIntermediateDirectories: true)
        try "{\"version\":\"4.91.0\"}".write(to: parent.appendingPathComponent("node_modules/wrangler/package.json"), atomically: true, encoding: .utf8)
        try "".write(to: parent.appendingPathComponent("yarn.lock"), atomically: true, encoding: .utf8)
        try "{\"scripts\":{\"dev\":\"vite\"}}".write(to: sub.appendingPathComponent("package.json"), atomically: true, encoding: .utf8)
        try "name = \"api\"".write(to: sub.appendingPathComponent("wrangler.toml"), atomically: true, encoding: .utf8)

        let found = ProjectScanner.scan(root: root.path)
        XCTAssertTrue(found.contains { $0.dir.hasSuffix("/mono/apps/api") })
        let info = ProjectInspector.inspect(Project(path: sub.path, configFile: "wrangler.toml", name: "api"))
        XCTAssertEqual(info.packageManager, .yarn)
        XCTAssertEqual(info.wranglerVersion, "4.91.0")
        XCTAssertTrue(info.depsInstalled)
        XCTAssertTrue(info.packageRoot?.hasSuffix("/mono") == true)
        XCTAssertTrue(info.scriptRoot?.hasSuffix("/mono/apps/api") == true)
    }

    func testAstroPagesProjectRunsItsOwnDevScript() throws {
        let fm = FileManager.default
        let dir = root.appendingPathComponent("astro-pages")
        try fm.createDirectory(at: dir.appendingPathComponent("node_modules/wrangler"), withIntermediateDirectories: true)
        try "{\"version\":\"4.110.0\"}".write(to: dir.appendingPathComponent("node_modules/wrangler/package.json"), atomically: true, encoding: .utf8)
        try "name = \"svgready\"\npages_build_output_dir = \"dist\"".write(to: dir.appendingPathComponent("wrangler.toml"), atomically: true, encoding: .utf8)
        try "export default {}".write(to: dir.appendingPathComponent("astro.config.mjs"), atomically: true, encoding: .utf8)
        try "{\"scripts\":{\"dev\":\"npm run build && wrangler pages dev dist\"}}".write(to: dir.appendingPathComponent("package.json"), atomically: true, encoding: .utf8)
        var info = ProjectInspector.inspect(Project(path: dir.path, configFile: "wrangler.toml", name: "x"))
        XCTAssertEqual(info.pagesOutputDir, "dist")
        XCTAssertEqual(info.framework, "Astro")
        XCTAssertEqual(info.detectedMode, .devScript)
        XCTAssertTrue(info.nodeModulesPresent)

        // Same project without a dev script falls back to `wrangler pages dev`.
        try "{}".write(to: dir.appendingPathComponent("package.json"), atomically: true, encoding: .utf8)
        info = ProjectInspector.inspect(Project(path: dir.path, configFile: "wrangler.toml", name: "x"))
        XCTAssertEqual(info.detectedMode, .pages)
    }

    func testFrameworkSiteWithoutPagesUsesDevScript() throws {
        let fm = FileManager.default
        let dir = root.appendingPathComponent("astro-worker")
        try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        try "{\"name\":\"w\",\"main\":\"dist/_worker.js/index.js\"}".write(to: dir.appendingPathComponent("wrangler.jsonc"), atomically: true, encoding: .utf8)
        try "export default {}".write(to: dir.appendingPathComponent("astro.config.ts"), atomically: true, encoding: .utf8)
        try "{\"scripts\":{\"dev\":\"astro dev\"}}".write(to: dir.appendingPathComponent("package.json"), atomically: true, encoding: .utf8)
        let info = ProjectInspector.inspect(Project(path: dir.path, configFile: "wrangler.jsonc", name: "w"))
        XCTAssertEqual(info.detectedMode, .devScript)
        XCTAssertEqual(OutputParser.detectURL(in: "  ┃ Local    http://localhost:4321/", mode: .devScript)?.port, 4321)
    }

    func testEmDashProjectGetsAdminLink() throws {
        let fm = FileManager.default
        let dir = root.appendingPathComponent("danang")
        try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        try "{\"name\":\"danang\",\"main\":\"./src/worker.ts\"}".write(to: dir.appendingPathComponent("wrangler.jsonc"), atomically: true, encoding: .utf8)
        try "import emdash, { local } from 'emdash/astro';".write(to: dir.appendingPathComponent("astro.config.mjs"), atomically: true, encoding: .utf8)
        try "{\"scripts\":{\"dev\":\"astro dev\"},\"dependencies\":{\"emdash\":\"^1.1.0\"}}".write(to: dir.appendingPathComponent("package.json"), atomically: true, encoding: .utf8)
        let info = ProjectInspector.inspect(Project(path: dir.path, configFile: "wrangler.jsonc", name: "danang"))
        XCTAssertEqual(info.cms, "EmDash")
        XCTAssertEqual(info.framework, "Astro")
        XCTAssertEqual(info.detectedMode, .devScript)
        let links = ProjectLink.links(for: info)
        XCTAssertEqual(links.map(\.path), ["/", "/_emdash/admin"])
        XCTAssertEqual(links[1].url(base: URL(string: "http://localhost:4321/")!)?.absoluteString, "http://localhost:4321/_emdash/admin")
        XCTAssertEqual(ProjectLink.links(for: nil).map(\.path), ["/"])
    }

    func testOldWranglerShowsUpdateCommand() {
        let p = Project(path: root.appendingPathComponent("a").path, configFile: "wrangler.toml", name: "a")
        let info = ProjectInspector.inspect(p)
        XCTAssertEqual(info.wranglerVersion, "4.70.0")
        if case .tooOld(_, _, _, let cmd) = ExplorerSupport.evaluate(info: info, mode: .wrangler) {
            XCTAssertEqual(cmd, "npm install -D wrangler@latest")
        } else { XCTFail("expected tooOld") }
    }

    func testInspectorNeverReturnsVarValues() {
        let dir = root.appendingPathComponent("s")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try? "name=\"s\"\n[vars]\nTOKEN=\"hunter2\"".write(to: dir.appendingPathComponent("wrangler.toml"), atomically: true, encoding: .utf8)
        let info = ProjectInspector.inspect(Project(path: dir.path, configFile: "wrangler.toml", name: "s"))
        XCTAssertEqual(info.varNames, ["TOKEN"])
        XCTAssertFalse(String(describing: info).contains("hunter2"))
    }

    func testPortAllocatorSkipsBusyPorts() throws {
        let fd = socket(AF_INET, SOCK_STREAM, 0)
        defer { close(fd) }
        var addr = sockaddr_in()
        addr.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = 0
        addr.sin_addr = in_addr(s_addr: INADDR_ANY)
        _ = withUnsafePointer(to: &addr) { $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { Darwin.bind(fd, $0, socklen_t(MemoryLayout<sockaddr_in>.size)) } }
        listen(fd, 1)
        var len = socklen_t(MemoryLayout<sockaddr_in>.size)
        _ = withUnsafeMutablePointer(to: &addr) { $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { getsockname(fd, $0, &len) } }
        let busy = Int(UInt16(bigEndian: addr.sin_port))

        XCTAssertFalse(PortAllocator.isFree(busy))
        XCTAssertNotEqual(PortAllocator.allocate(start: busy, avoiding: []), busy)
    }
}

final class ProcessTests: XCTestCase {
    /// A fake "wrangler": prints a Ready line, then keeps a long-lived child (like workerd) alive.
    func testStartParsesOutputAndStopKillsWholeGroup() async throws {
        let pm = ProcessManager()
        let lines = LockedBox<[String]>([])
        let exit = LockedBox<(Int32, Bool)?>(nil)
        let pid = try await pm.start(
            id: "t", command: "echo 'Ready on http://localhost:8799'; sleep 300 & sleep 300",
            cwd: NSTemporaryDirectory(), env: ShellEnvironment.fallback(),
            onLine: { text, _ in lines.mutate { $0.append(text) } },
            onExit: { code, intentional in exit.set((code, intentional)) })

        try await waitUntil { lines.value.contains { $0.contains("Ready on") } }
        XCTAssertEqual(OutputParser.detectURL(in: lines.value.first ?? "", mode: .wrangler)?.port, 8799)
        XCTAssertTrue(ProcessInspector.groupAlive(pid))
        XCTAssertGreaterThanOrEqual(ProcessInspector.groupResidentBytes(pgid: pid), 1)

        await pm.stop(id: "t")
        XCTAssertFalse(ProcessInspector.groupAlive(pid), "whole process group must be gone")
        try await waitUntil { exit.value != nil }
        XCTAssertEqual(exit.value?.1, true)
    }

    func testStopEscalatesToSIGKILLWhenTermIsIgnored() async throws {
        let pm = ProcessManager()
        let started = LockedBox(false)
        let pid = try await pm.start(
            id: "stubborn", command: "trap '' TERM; echo up; while true; do sleep 1; done",
            cwd: NSTemporaryDirectory(), env: ShellEnvironment.fallback(),
            onLine: { _, _ in started.set(true) }, onExit: { _, _ in })
        try await waitUntil { started.value }
        await pm.stop(id: "stubborn")
        XCTAssertFalse(ProcessInspector.groupAlive(pid))
    }

    func testCrashReportsNonZeroExit() async throws {
        let pm = ProcessManager()
        let exit = LockedBox<(Int32, Bool)?>(nil)
        _ = try await pm.start(id: "x", command: "echo boom >&2; exit 3", cwd: NSTemporaryDirectory(),
                               env: ShellEnvironment.fallback(), onLine: { _, _ in },
                               onExit: { c, i in exit.set((c, i)) })
        try await waitUntil { exit.value != nil }
        XCTAssertEqual(exit.value?.0, 3)
        XCTAssertEqual(exit.value?.1, false)
    }

    func testDetectorFindsRunningWorkerdByCwd() async throws {
        // Fake "workerd" binary: a copy of sleep named workerd, run with cwd inside a fake project.
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("wd-detect-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let fake = dir.appendingPathComponent("workerd")
        try makeFakeWorkerd(at: fake)

        let p = Process()
        p.executableURL = fake
        p.arguments = ["60"]
        p.currentDirectoryURL = dir
        try p.run()
        defer { p.terminate() }
        try await waitUntil { ProcessInspector.name(p.processIdentifier) == "workerd" }

        let found = RunningDetector.scan(projects: [(id: "proj", path: dir.path, port: nil)], excludingPGIDs: [])
        XCTAssertEqual(found["proj"]?.pids.contains(p.processIdentifier), true)

        let none = RunningDetector.scan(projects: [(id: "other", path: "/nonexistent/project", port: nil)], excludingPGIDs: [])
        XCTAssertNil(none["other"])
    }
}

final class LockedBox<T>: @unchecked Sendable {
    private var v: T
    private let lock = NSLock()
    init(_ v: T) { self.v = v }
    var value: T { lock.lock(); defer { lock.unlock() }; return v }
    func set(_ new: T) { lock.lock(); v = new; lock.unlock() }
    func mutate(_ f: (inout T) -> Void) { lock.lock(); f(&v); lock.unlock() }
}

func waitUntil(timeout: TimeInterval = 10, _ condition: () -> Bool) async throws {
    let end = Date().addingTimeInterval(timeout)
    while !condition() {
        if Date() > end { struct Timeout: Error {}; XCTFail("timed out waiting for condition"); throw Timeout() }
        try await Task.sleep(nanoseconds: 50_000_000)
    }
}

@MainActor
func waitUntilMain(timeout: TimeInterval = 15, line: UInt = #line, _ condition: () -> Bool) async throws {
    let end = Date().addingTimeInterval(timeout)
    while !condition() {
        if Date() > end { struct Timeout: Error {}; XCTFail("timed out waiting for condition", line: line); throw Timeout() }
        try await Task.sleep(nanoseconds: 50_000_000)
    }
}

/// End-to-end: real AppModel + a fake `npx wrangler` (so nothing is installed or touched).
@MainActor
final class EndToEndTests: XCTestCase {
    var tmp: URL!
    var project: URL!

    override func setUpWithError() throws {
        let fm = FileManager.default
        tmp = fm.temporaryDirectory.appendingPathComponent("wd-e2e-\(UUID().uuidString)")
        let root = tmp.appendingPathComponent("sites")
        project = root.appendingPathComponent("demo")
        let shim = tmp.appendingPathComponent("shim")
        let support = tmp.appendingPathComponent("support")
        for d in [project.appendingPathComponent("node_modules/wrangler"), shim, support] {
            try fm.createDirectory(at: d, withIntermediateDirectories: true)
        }
        try "{\"version\":\"4.90.0\"}".write(to: project.appendingPathComponent("node_modules/wrangler/package.json"), atomically: true, encoding: .utf8)
        try "{}".write(to: project.appendingPathComponent("package-lock.json"), atomically: true, encoding: .utf8)
        try "{ // demo\n \"name\": \"demo-worker\",\n \"vars\": {\"SECRET\": \"hunter2\"},\n \"kv_namespaces\": [{\"binding\": \"KV\"},],\n}"
            .write(to: project.appendingPathComponent("wrangler.jsonc"), atomically: true, encoding: .utf8)

        // Fake wrangler: `npx wrangler dev --port N --inspector-port M`
        try makeFakeWorkerd(at: shim.appendingPathComponent("workerd"))
        let script = """
        #!/bin/sh
        while [ $# -gt 0 ]; do [ "$1" = "--port" ] && PORT=$2; shift; done
        echo "\\033[32m⛅️ wrangler 4.90.0\\033[0m"
        echo "[wrangler:info] Ready on http://localhost:$PORT"
        echo "something on stderr" >&2
        exec "\(shim.path)/workerd" 600
        """
        let npx = shim.appendingPathComponent("npx")
        try script.write(to: npx, atomically: true, encoding: .utf8)
        try fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: npx.path)

        setenv("WORKERDOCK_SUPPORT_DIR", support.path, 1)
    }

    override func tearDownWithError() throws {
        unsetenv("WORKERDOCK_SUPPORT_DIR")
        try? FileManager.default.removeItem(at: tmp)
    }

    private func snapshot() -> [String] {
        let e = FileManager.default.enumerator(atPath: project.path)
        return (e?.allObjects as? [String] ?? []).sorted()
    }

    func testMissingDependenciesBlocksStart() async throws {
        let model = AppModel()
        try FileManager.default.removeItem(at: project.appendingPathComponent("node_modules"))
        model.addRoot(tmp.appendingPathComponent("sites").path)
        try await waitUntilMain { model.projects.count == 1 && !model.isScanning }
        await model.refreshAllInfo()
        let p = model.projects[0]
        XCTAssertFalse(model.info(p.id)!.depsInstalled)
        await model.startAsync(p.id)
        XCTAssertEqual(model.runtime(p.id).status, .error("Dependencies not installed"))
    }

    func testAddSingleProjectHideAndRemove() async throws {
        let model = AppModel()
        XCTAssertNotNil(model.addProjectFolder(tmp.path), "folder without config must be rejected")
        XCTAssertNil(model.addProjectFolder(project.path))
        XCTAssertEqual(model.projects.count, 1)
        let id = model.projects[0].id
        model.setHidden(id, true)
        XCTAssertTrue(model.visibleProjects.isEmpty)
        model.setHidden(id, false)
        model.removeManual(id)
        XCTAssertTrue(model.projects.isEmpty)
    }
}

/// A copy of /bin/sleep named workerd. Copies lose their signature (and get killed on arm64), so re-sign ad hoc.
func makeFakeWorkerd(at url: URL) throws {
    try FileManager.default.copyItem(atPath: "/bin/sleep", toPath: url.path)
    let p = Process()
    p.executableURL = URL(fileURLWithPath: "/usr/bin/codesign")
    p.arguments = ["-s", "-", "--force", url.path]
    p.standardError = FileHandle.nullDevice
    try p.run()
    p.waitUntilExit()
}
