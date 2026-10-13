# Third-party tools, libraries, assets and services

## In the app (shipped)
| Name | Use | Licence | Notes |
|---|---|---|---|
| [Sparkle](https://github.com/sparkle-project/Sparkle) 2.x (resolved 2.10.0) | Automatic updates | MIT-style | Swift package. Helper tools are re-signed at release. Docs: sparkle-project.org |
| [TOMLKit](https://github.com/LebJe/TOMLKit) 0.6+ | Parse `wrangler.toml` | MIT | Swift package |
| [Lucide](https://lucide.dev) | UI icons (bundled as template SVGs) | ISC | Notice in `WorkerDock/Resources/LUCIDE-LICENSE.txt` and About window |
| [Simple Icons](https://simpleicons.org) (v13.21.0 via jsDelivr) | Framework logos: Astro, Nuxt, Next.js, Svelte, Remix, React Router, VitePress, Docusaurus, Gatsby | CC0 | Logos remain trademarks of their owners; used only to identify the framework |
| EmDash mark | Derived from the official favicon at emdashcms.com/brand | Trademark of its owner | Made single-colour so it follows light/dark |
| Apple frameworks | SwiftUI, AppKit, WebKit (Explorer), ServiceManagement (login item), libproc, FSEvents | Apple | |

## Build and release tooling (developer Mac)
| Name | Use |
|---|---|
| [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`) | Generates `WorkerDock.xcodeproj` from `project.yml` |
| Xcode + command line tools | Build, test, archive, `codesign`, `xcrun notarytool`, `xcrun stapler`, `hdiutil`, `spctl` |
| Sparkle tools (inside the package artifacts) | `generate_keys` (create/export the update key), `generate_appcast` (sign the update and write the feed). Found under `~/Library/Developer/Xcode/DerivedData/WorkerDock-*/SourcePackages/artifacts/sparkle/Sparkle/bin/` |
| Apple Developer Program | Developer ID certificate, notarisation (team `6A83PFAKPU`) |

## Services
| Service | Use | Status |
|---|---|---|
| workerdock.app website | Marketing site, download, update feed | Repo: the separate website repository (`workerdock-site`) (Astro). Hosted as Cloudflare Workers with static assets; a Worker handles `POST /api/subscribe` and stores emails in D1 (`workerdock-subscribers`) |
| Creem.io | Optional pay-what-you-want "Support WorkerDock" product (merchant of record, 3.9% + 40¢ per sale stated on its site; verify add-on fees) | Planned. Needs the checkout URL in `AppInfo.supportURL` |
| Cloudflare R2 | Possible host for the `.dmg` | Undecided; the site's `public/download/` works too |
| Webtions Analytics | Site analytics (`dash.webtions.com`) | On the website only, never in the app |

## Things the app calls at runtime
- The user's own `wrangler`, `npm`/`pnpm`/`yarn`/`bun`, `node` (found through the login shell environment).
- Wrangler's Local Explorer at `http://localhost:<port>/cdn-cgi/explorer` (embedded web view).
- `https://workerdock.app/appcast.xml` (Sparkle update check). This is the only outbound network call.

## Keeping this list current
When adding a dependency, add it here with its licence and, for assets, the exact source URL/version.
