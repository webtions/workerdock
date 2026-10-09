import SwiftUI
import AppKit

/// What kind of project this is (framework, CMS, Pages, plain Worker) and the icon that stands for it.
/// Each badge prefers a bundled brand mark (`brand-<id>` in Icons.xcassets) and falls back to a Lucide glyph.
struct KindBadge: Identifiable, Equatable {
    let name: String
    let brand: String
    let fallback: String
    var id: String { brand }
}

enum ProjectKind {
    private static let frameworks: [String: KindBadge] = [
        "Astro": .init(name: "Astro", brand: "astro", fallback: "rocket"),
        "Nuxt": .init(name: "Nuxt", brand: "nuxt", fallback: "leaf"),
        "Next.js": .init(name: "Next.js", brand: "nextjs", fallback: "globe"),
        "SvelteKit": .init(name: "SvelteKit", brand: "svelte", fallback: "zap"),
        "Remix": .init(name: "Remix", brand: "remix", fallback: "layers"),
        "React Router": .init(name: "React Router", brand: "reactrouter", fallback: "waypoints"),
        "VitePress": .init(name: "VitePress", brand: "vitepress", fallback: "file-text"),
        "Docusaurus": .init(name: "Docusaurus", brand: "docusaurus", fallback: "file-text"),
        "Gatsby": .init(name: "Gatsby", brand: "gatsby", fallback: "sparkles"),
    ]
    static let emdash = KindBadge(name: "EmDash", brand: "emdash", fallback: "minus")
    static let pages = KindBadge(name: "Pages", brand: "cloudflare-pages", fallback: "globe")
    static let worker = KindBadge(name: "Worker", brand: "cloudflare-workers", fallback: "cloud")

    /// Most specific first: CMS, then framework, then Pages.
    static func badges(_ info: ProjectInfo?) -> [KindBadge] {
        guard let info else { return [] }
        var list: [KindBadge] = []
        if info.cms == "EmDash" { list.append(emdash) }
        if let fw = info.framework { list.append(frameworks[fw] ?? .init(name: fw, brand: fw.lowercased(), fallback: "layout-dashboard")) }
        if info.pagesOutputDir != nil { list.append(pages) }
        return list
    }

    static func primary(_ info: ProjectInfo?) -> KindBadge { badges(info).first ?? worker }
}

/// Brand mark if bundled, Lucide glyph otherwise. Template-rendered, so it takes the foreground colour.
struct KindIcon: View {
    let badge: KindBadge
    var size: CGFloat = IconSize.md

    var body: some View {
        if NSImage(named: "brand-\(badge.brand)") != nil {
            Image("brand-\(badge.brand)").renderingMode(.template).resizable().interpolation(.high)
                .aspectRatio(contentMode: .fit).frame(width: size, height: size)
        } else {
            Icon(badge.fallback, size: size)
        }
    }
}
