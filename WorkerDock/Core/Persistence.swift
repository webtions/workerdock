import Foundation

/// JSON files in ~/Library/Application Support/<app>/. Never touches project folders.
enum Persistence {
    static var directory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent(AppInfo.supportDirName, isDirectory: true)
    }

    static func load<T: Decodable>(_ type: T.Type, file: String) -> T? {
        let url = directory.appendingPathComponent(file)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }

    static func save<T: Encodable>(_ value: T, file: String) {
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let enc = JSONEncoder()
            enc.outputFormatting = [.prettyPrinted, .sortedKeys]
            try enc.encode(value).write(to: directory.appendingPathComponent(file), options: .atomic)
        } catch {
            NSLog("\(AppInfo.name): failed to save \(file): \(error)")
        }
    }

    static func remove(file: String) {
        try? FileManager.default.removeItem(at: directory.appendingPathComponent(file))
    }
}
