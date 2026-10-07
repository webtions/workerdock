import Foundation
import TOMLKit

struct ParsedConfig {
    var workerName: String?
    var main: String?
    var compatibilityDate: String?
    var pagesOutputDir: String?
    var bindings: [WorkerBinding] = []
    var varNames: [String] = []
}

enum ConfigParser {
    static func kind(forFile name: String) -> ConfigKind {
        switch (name as NSString).pathExtension.lowercased() {
        case "toml": return .toml
        case "json": return .json
        default: return .jsonc
        }
    }

    static func parse(fileURL: URL) throws -> ParsedConfig {
        let text = try String(contentsOf: fileURL, encoding: .utf8)
        return extract(try dictionary(from: text, kind: kind(forFile: fileURL.lastPathComponent)))
    }

    static func dictionary(from text: String, kind: ConfigKind) throws -> [String: Any] {
        switch kind {
        case .toml:
            let table = try TOMLTable(string: text)
            let data = Data(table.convert(to: .json).utf8)
            return (try JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
        case .json, .jsonc:
            let cleaned = stripJSONC(text)
            let data = Data(cleaned.utf8)
            return (try JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
        }
    }

    // MARK: JSONC

    /// Removes `//` and `/* */` comments, a leading BOM and trailing commas, leaving strings intact.
    static func stripJSONC(_ input: String) -> String {
        var scalars = Array(input.unicodeScalars)
        if scalars.first == "\u{FEFF}" { scalars.removeFirst() }
        let n = scalars.count

        var pass1 = String.UnicodeScalarView()
        var i = 0
        var inString = false
        while i < n {
            let c = scalars[i]
            if inString {
                pass1.append(c)
                if c == "\\", i + 1 < n { pass1.append(scalars[i + 1]); i += 2; continue }
                if c == "\"" { inString = false }
                i += 1
                continue
            }
            if c == "\"" { inString = true; pass1.append(c); i += 1; continue }
            if c == "/", i + 1 < n, scalars[i + 1] == "/" {
                while i < n && scalars[i] != "\n" { i += 1 }
                continue
            }
            if c == "/", i + 1 < n, scalars[i + 1] == "*" {
                i += 2
                while i + 1 < n && !(scalars[i] == "*" && scalars[i + 1] == "/") { i += 1 }
                i += 2
                continue
            }
            pass1.append(c)
            i += 1
        }

        let s = Array(pass1)
        var out = String.UnicodeScalarView()
        inString = false
        i = 0
        while i < s.count {
            let c = s[i]
            if inString {
                out.append(c)
                if c == "\\", i + 1 < s.count { out.append(s[i + 1]); i += 2; continue }
                if c == "\"" { inString = false }
                i += 1
                continue
            }
            if c == "\"" { inString = true; out.append(c); i += 1; continue }
            if c == "," {
                var j = i + 1
                while j < s.count, s[j] == " " || s[j] == "\n" || s[j] == "\r" || s[j] == "\t" { j += 1 }
                if j < s.count, s[j] == "}" || s[j] == "]" { i += 1; continue }
            }
            out.append(c)
            i += 1
        }
        return String(out)
    }

    // MARK: Extraction

    /// Reads binding *names* only. Values of `vars` are never kept.
    static func extract(_ d: [String: Any]) -> ParsedConfig {
        var cfg = ParsedConfig()
        cfg.workerName = d["name"] as? String
        cfg.main = d["main"] as? String
        cfg.compatibilityDate = d["compatibility_date"] as? String
        cfg.pagesOutputDir = d["pages_build_output_dir"] as? String

        func list(_ key: String) -> [[String: Any]] { (d[key] as? [[String: Any]]) ?? [] }
        func add(_ kind: BindingKind, _ name: String?, _ detail: String? = nil) {
            if let name, !name.isEmpty { cfg.bindings.append(WorkerBinding(kind: kind, name: name, detail: detail)) }
        }

        for x in list("d1_databases") { add(.d1, x["binding"] as? String, x["database_name"] as? String) }
        for x in list("kv_namespaces") { add(.kv, x["binding"] as? String) }
        for x in list("r2_buckets") { add(.r2, x["binding"] as? String, x["bucket_name"] as? String) }
        if let q = d["queues"] as? [String: Any] {
            for x in (q["producers"] as? [[String: Any]]) ?? [] { add(.queue, x["binding"] as? String, x["queue"] as? String) }
            for x in (q["consumers"] as? [[String: Any]]) ?? [] {
                if let name = x["queue"] as? String { add(.queue, name, "consumer") }
            }
        }
        if let dos = d["durable_objects"] as? [String: Any] {
            for x in (dos["bindings"] as? [[String: Any]]) ?? [] { add(.durableObject, x["name"] as? String, x["class_name"] as? String) }
        }
        for x in list("workflows") { add(.workflow, x["binding"] as? String, x["name"] as? String) }
        for x in list("services") { add(.service, x["binding"] as? String, x["service"] as? String) }
        for x in list("vectorize") { add(.vectorize, x["binding"] as? String, x["index_name"] as? String) }
        for x in list("hyperdrive") { add(.hyperdrive, x["binding"] as? String) }
        for x in list("analytics_engine_datasets") { add(.analytics, x["binding"] as? String, x["dataset"] as? String) }
        if let ai = d["ai"] as? [String: Any] { add(.ai, ai["binding"] as? String) }
        if let br = d["browser"] as? [String: Any] { add(.browser, br["binding"] as? String) }
        if let assets = d["assets"] as? [String: Any] { add(.assets, assets["binding"] as? String ?? "assets", assets["directory"] as? String) }

        if let vars = d["vars"] as? [String: Any] { cfg.varNames = vars.keys.sorted() }
        return cfg
    }
}
