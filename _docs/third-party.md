# Third-party tools, libraries and assets

## In the app (shipped)
| Name | Use | Licence | Notes |
|---|---|---|---|
| [Sparkle](https://github.com/sparkle-project/Sparkle) 2.x (resolved 2.10.0) | Automatic updates | MIT-style | Swift package. Docs: sparkle-project.org |
| [TOMLKit](https://github.com/LebJe/TOMLKit) 0.6+ | Parse `wrangler.toml` | MIT | Swift package |
| [Lucide](https://lucide.dev) | UI icons (bundled as template SVGs) | ISC | Notice in `WorkerDock/Resources/LUCIDE-LICENSE.txt` and About window |
| [Simple Icons](https://simpleicons.org) (v13.21.0 via jsDelivr) | Framework logos: Astro, Nuxt, Next.js, Svelte, Remix, React Router, VitePress, Docusaurus, Gatsby | CC0 | Logos remain trademarks of their owners; used only to identify the framework |
| EmDash mark | Derived from the official favicon at emdashcms.com/brand | Trademark of its owner | Made single-colour so it follows light/dark |
| Apple frameworks | SwiftUI, AppKit, WebKit (Explorer), ServiceManagement (login item), libproc, FSEvents | Apple | |

## Build tooling
| Name | Use |
|---|---|
| [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`) | Generates `WorkerDock.xcodeproj` from `project.yml` |
| Xcode + command line tools | Build and test |

## Things the app calls at runtime
- The user's own `wrangler`, `npm`/`pnpm`/`yarn`/`bun`, `node` (found through the login shell environment).
- Wrangler's Local Explorer at `http://localhost:<port>/cdn-cgi/explorer` (embedded web view).
- `https://workerdock.app/appcast.xml` (Sparkle update check). This is the only outbound network call.

## Keeping this list current
When adding a dependency, add it here with its licence and, for assets, the exact source URL/version.
