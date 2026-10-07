import Foundation
import Darwin

struct ExternalProcess: Equatable {
    var pids: [Int32]
    var port: Int?
}

/// Finds `workerd` processes started outside WorkerDock (e.g. from a terminal) and matches
/// them to registered projects by working directory of workerd or its parent chain.
enum RunningDetector {
    private static let killable: Set<String> = ["workerd", "node", "bun", "deno", "npm", "pnpm", "yarn", "npx"]

    static func scan(projects: [(id: String, path: String, port: Int?)],
                     excludingPGIDs: Set<pid_t>) -> [String: ExternalProcess] {
        let pids = ProcessInspector.allPIDs()
        var result: [String: ExternalProcess] = [:]
        let sorted = projects.sorted { $0.path.count > $1.path.count }   // longest path wins

        for pid in pids {
            guard ProcessInspector.name(pid) == "workerd",
                  let info = ProcessInspector.bsd(pid),
                  !excludingPGIDs.contains(pid_t(info.pbi_pgid)) else { continue }

            // workerd, then its ancestors, while they look like part of the dev server.
            var chain: [pid_t] = [pid]
            var cur = pid_t(info.pbi_ppid)
            var depth = 0
            while cur > 1 && depth < 6, killable.contains(ProcessInspector.name(cur)) {
                chain.append(cur)
                guard let b = ProcessInspector.bsd(cur) else { break }
                cur = pid_t(b.pbi_ppid)
                depth += 1
            }

            let cwds = chain.compactMap(ProcessInspector.cwd)
            guard let match = sorted.first(where: { p in cwds.contains { isInside($0, of: p.path) } }) else { continue }

            let ports = ProcessInspector.listeningPorts(pid)
            var entry = result[match.id] ?? ExternalProcess(pids: [], port: nil)
            entry.pids.append(contentsOf: chain.map { Int32($0) })
            entry.port = choosePort(from: ports, preferred: match.port) ?? entry.port
            result[match.id] = entry
        }
        return result.mapValues { ExternalProcess(pids: Array(Set($0.pids)).sorted(), port: $0.port) }
    }

    /// workerd also opens ephemeral internal ports; the user-facing one is the lowest
    /// non-ephemeral listener, unless we already know the project's port.
    static func choosePort(from ports: [Int], preferred: Int?) -> Int? {
        if let p = preferred, ports.contains(p) { return p }
        return ports.first(where: { $0 < 49152 }) ?? ports.first
    }

    static func isInside(_ cwd: String, of root: String) -> Bool {
        let a = (cwd as NSString).standardizingPath
        let b = (root as NSString).standardizingPath
        return a == b || a.hasPrefix(b + "/")
    }
}
