import Foundation
import CoreServices

/// Optional FSEvents watcher: calls back (debounced) when a wrangler config appears/disappears.
final class RootWatcher {
    private var stream: FSEventStreamRef?
    private let onChange: () -> Void
    private var debounce: DispatchWorkItem?

    init(paths: [String], onChange: @escaping () -> Void) {
        self.onChange = onChange
        guard !paths.isEmpty else { return }
        var ctx = FSEventStreamContext(version: 0, info: Unmanaged.passUnretained(self).toOpaque(),
                                       retain: nil, release: nil, copyDescription: nil)
        let callback: FSEventStreamCallback = { _, info, count, eventPaths, _, _ in
            guard let info else { return }
            let watcher = Unmanaged<RootWatcher>.fromOpaque(info).takeUnretainedValue()
            let paths = unsafeBitCast(eventPaths, to: NSArray.self) as? [String] ?? []
            if paths.prefix(count).contains(where: RootWatcher.isRelevant) { watcher.fire() }
        }
        let flags = UInt32(kFSEventStreamCreateFlagFileEvents | kFSEventStreamCreateFlagUseCFTypes | kFSEventStreamCreateFlagNoDefer)
        stream = FSEventStreamCreate(nil, callback, &ctx, paths as CFArray,
                                     FSEventStreamEventId(kFSEventStreamEventIdSinceNow), 1.0, flags)
        if let stream {
            FSEventStreamSetDispatchQueue(stream, .main)
            FSEventStreamStart(stream)
        }
    }

    static func isRelevant(_ path: String) -> Bool {
        let comps = path.split(separator: "/").map(String.init)
        guard let last = comps.last, ProjectScanner.configNames.contains(last) else { return false }
        return !comps.contains(where: { ProjectScanner.skipped.contains($0) })
    }

    private func fire() {
        debounce?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.onChange() }
        debounce = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5, execute: work)
    }

    func stop() {
        debounce?.cancel()
        if let stream {
            FSEventStreamStop(stream)
            FSEventStreamInvalidate(stream)
            FSEventStreamRelease(stream)
        }
        stream = nil
    }

    deinit { stop() }
}
