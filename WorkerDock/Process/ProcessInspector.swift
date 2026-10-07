import Foundation
import Darwin

/// Thin libproc wrapper: cheaper than spawning ps/lsof.
enum ProcessInspector {
    static func allPIDs() -> [pid_t] {
        let count = proc_listallpids(nil, 0)
        guard count > 0 else { return [] }
        var pids = [pid_t](repeating: 0, count: Int(count) + 64)
        let got = proc_listallpids(&pids, Int32(pids.count * MemoryLayout<pid_t>.size))
        guard got > 0 else { return [] }
        return Array(pids.prefix(Int(got))).filter { $0 > 0 }
    }

    static func bsd(_ pid: pid_t) -> proc_bsdinfo? {
        var info = proc_bsdinfo()
        let size = Int32(MemoryLayout<proc_bsdinfo>.size)
        return proc_pidinfo(pid, PROC_PIDTBSDINFO, 0, &info, size) == size ? info : nil
    }

    static func name(_ pid: pid_t) -> String {
        var buf = [CChar](repeating: 0, count: 256)
        let n = proc_name(pid, &buf, UInt32(buf.count))
        return n > 0 ? String(cString: buf) : ""
    }

    static func residentBytes(_ pid: pid_t) -> UInt64 {
        var ti = proc_taskinfo()
        let size = Int32(MemoryLayout<proc_taskinfo>.size)
        return proc_pidinfo(pid, PROC_PIDTASKINFO, 0, &ti, size) == size ? ti.pti_resident_size : 0
    }

    static func cwd(_ pid: pid_t) -> String? {
        var info = proc_vnodepathinfo()
        let size = Int32(MemoryLayout<proc_vnodepathinfo>.size)
        guard proc_pidinfo(pid, PROC_PIDVNODEPATHINFO, 0, &info, size) == size else { return nil }
        let path = withUnsafePointer(to: &info.pvi_cdir.vip_path) {
            $0.withMemoryRebound(to: CChar.self, capacity: Int(MAXPATHLEN)) { String(cString: $0) }
        }
        return path.isEmpty ? nil : path
    }

    static func listeningPorts(_ pid: pid_t) -> [Int] {
        let bytes = proc_pidinfo(pid, PROC_PIDLISTFDS, 0, nil, 0)
        guard bytes > 0 else { return [] }
        let stride = MemoryLayout<proc_fdinfo>.size
        var fds = [proc_fdinfo](repeating: proc_fdinfo(), count: Int(bytes) / stride + 8)
        let got = proc_pidinfo(pid, PROC_PIDLISTFDS, 0, &fds, Int32(fds.count * stride))
        guard got > 0 else { return [] }

        var ports = Set<Int>()
        for fd in fds.prefix(Int(got) / stride) where fd.proc_fdtype == UInt32(PROX_FDTYPE_SOCKET) {
            var si = socket_fdinfo()
            let size = Int32(MemoryLayout<socket_fdinfo>.size)
            guard proc_pidfdinfo(pid, fd.proc_fd, PROC_PIDFDSOCKETINFO, &si, size) == size,
                  si.psi.soi_kind == Int32(SOCKINFO_TCP) else { continue }
            let tcp = si.psi.soi_proto.pri_tcp
            if tcp.tcpsi_state == Int32(TSI_S_LISTEN) {
                let port = UInt16(bigEndian: UInt16(truncatingIfNeeded: tcp.tcpsi_ini.insi_lport))
                if port > 0 { ports.insert(Int(port)) }
            }
        }
        return ports.sorted()
    }

    /// Total resident memory of every process in a process group.
    static func groupResidentBytes(pgid: pid_t) -> UInt64 {
        var total: UInt64 = 0
        for pid in allPIDs() {
            if let b = bsd(pid), pid_t(b.pbi_pgid) == pgid { total += residentBytes(pid) }
        }
        return total
    }

    /// Guards against PID reuse before killing something left over from a previous session.
    static func isSameProcess(pid: pid_t, startSec: UInt64) -> Bool {
        guard let b = bsd(pid) else { return false }
        return b.pbi_start_tvsec == startSec && pid_t(b.pbi_pgid) == pid
    }

    static func startSec(of pid: pid_t) -> UInt64? { bsd(pid)?.pbi_start_tvsec }

    static func groupAlive(_ pgid: pid_t) -> Bool {
        killpg(pgid, 0) == 0 || errno == EPERM
    }
}
