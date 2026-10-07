import Foundation
import Darwin

struct SpawnError: Error, LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

/// Spawns each project in its own process group and tears the whole group down on stop,
/// so wrangler's `workerd` child never outlives it.
actor ProcessManager {
    private var live: [String: pid_t] = [:]
    private var intentional: Set<String> = []

    static let termGrace: Int = 50   // x100ms before SIGKILL

    /// `onLine` and `onExit` are called on arbitrary background queues.
    func start(id: String,
               command: String,
               cwd: String,
               env: [String: String],
               onLine: @escaping @Sendable (String, Bool) -> Void,
               onExit: @escaping @Sendable (Int32, Bool) -> Void) throws -> pid_t {
        guard live[id] == nil else { throw SpawnError(message: "Already running") }
        let (pid, outFD, errFD) = try Self.spawn(command: command, cwd: cwd, env: env)
        live[id] = pid
        intentional.remove(id)

        Self.pump(fd: outFD, isError: false, onLine: onLine)
        Self.pump(fd: errFD, isError: true, onLine: onLine)

        DispatchQueue.global(qos: .utility).async { [weak self] in
            var status: Int32 = 0
            while waitpid(pid, &status, 0) == -1 && errno == EINTR {}
            let code: Int32 = (status & 0x7f) == 0 ? (status >> 8) & 0xff : 128 + (status & 0x7f)
            // Leader is gone; make sure no stragglers (workerd) keep running.
            killpg(pid, SIGTERM)
            DispatchQueue.global().asyncAfter(deadline: .now() + 3) {
                if ProcessInspector.groupAlive(pid) { killpg(pid, SIGKILL) }
            }
            Task {
                let wasIntentional = await self?.finish(id: id, pid: pid) ?? false
                onExit(code, wasIntentional)
            }
        }
        return pid
    }

    private func finish(id: String, pid: pid_t) -> Bool {
        if live[id] == pid { live[id] = nil }
        return intentional.remove(id) != nil
    }

    func isRunning(_ id: String) -> Bool { live[id] != nil }
    var runningIDs: [String] { Array(live.keys) }

    /// SIGTERM to the whole group, SIGKILL after ~5s if anything is still alive.
    func stop(id: String) async {
        guard let pid = live[id] else { return }
        intentional.insert(id)
        await Self.terminateGroup(pid)
    }

    func stopAll() async {
        let entries = Array(live)
        for (id, _) in entries { intentional.insert(id) }
        await withTaskGroup(of: Void.self) { group in
            for (_, pid) in entries { group.addTask { await Self.terminateGroup(pid) } }
        }
    }

    static func terminateGroup(_ pgid: pid_t) async {
        killpg(pgid, SIGTERM)
        var waited = 0
        while ProcessInspector.groupAlive(pgid) && waited < termGrace {
            try? await Task.sleep(nanoseconds: 100_000_000)
            waited += 1
        }
        if ProcessInspector.groupAlive(pgid) {
            killpg(pgid, SIGKILL)
            var extra = 0
            while ProcessInspector.groupAlive(pgid) && extra < 20 {
                try? await Task.sleep(nanoseconds: 100_000_000)
                extra += 1
            }
        }
    }

    // MARK: - posix_spawn

    private static func spawn(command: String, cwd: String, env: [String: String]) throws -> (pid_t, Int32, Int32) {
        var outPipe: [Int32] = [0, 0]
        var errPipe: [Int32] = [0, 0]
        guard pipe(&outPipe) == 0 else { throw SpawnError(message: "pipe() failed") }
        guard pipe(&errPipe) == 0 else {
            close(outPipe[0]); close(outPipe[1])
            throw SpawnError(message: "pipe() failed")
        }

        var actions: posix_spawn_file_actions_t?
        posix_spawn_file_actions_init(&actions)
        defer { posix_spawn_file_actions_destroy(&actions) }
        posix_spawn_file_actions_addopen(&actions, 0, "/dev/null", O_RDONLY, 0)
        posix_spawn_file_actions_adddup2(&actions, outPipe[1], 1)
        posix_spawn_file_actions_adddup2(&actions, errPipe[1], 2)
        for fd in outPipe + errPipe { posix_spawn_file_actions_addclose(&actions, fd) }
        posix_spawn_file_actions_addchdir_np(&actions, cwd)

        var attr: posix_spawnattr_t?
        posix_spawnattr_init(&attr)
        defer { posix_spawnattr_destroy(&attr) }
        var allSignals = sigset_t()
        sigfillset(&allSignals)
        posix_spawnattr_setsigdefault(&attr, &allSignals)
        var noSignals = sigset_t()
        sigemptyset(&noSignals)
        posix_spawnattr_setsigmask(&attr, &noSignals)
        posix_spawnattr_setpgroup(&attr, 0)   // new group, led by the child
        posix_spawnattr_setflags(&attr, Int16(POSIX_SPAWN_SETPGROUP | POSIX_SPAWN_SETSIGDEF | POSIX_SPAWN_SETSIGMASK))

        let args: [String] = ["/bin/sh", "-c", command]
        let argv: [UnsafeMutablePointer<CChar>?] = args.map { strdup($0) } + [nil]
        let envp: [UnsafeMutablePointer<CChar>?] = env.map { strdup("\($0.key)=\($0.value)") } + [nil]
        defer { argv.forEach { free($0) }; envp.forEach { free($0) } }

        var pid: pid_t = 0
        let rc = posix_spawn(&pid, "/bin/sh", &actions, &attr, argv, envp)
        close(outPipe[1]); close(errPipe[1])
        guard rc == 0 else {
            close(outPipe[0]); close(errPipe[0])
            throw SpawnError(message: "posix_spawn failed: \(String(cString: strerror(rc)))")
        }
        return (pid, outPipe[0], errPipe[0])
    }

    private static func pump(fd: Int32, isError: Bool, onLine: @escaping @Sendable (String, Bool) -> Void) {
        let handle = FileHandle(fileDescriptor: fd, closeOnDealloc: true)
        let splitter = LineSplitter()
        // The closure captures `handle` on purpose: it keeps the fd open until EOF,
        // where setting the handler to nil breaks the cycle.
        handle.readabilityHandler = { _ in
            let data = handle.availableData
            if data.isEmpty {
                if let rest = splitter.flush() { onLine(rest, isError) }
                handle.readabilityHandler = nil
                return
            }
            for line in splitter.feed(data) { onLine(line, isError) }
        }
    }
}
