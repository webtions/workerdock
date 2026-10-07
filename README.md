# WorkerDock

A native macOS app (Swift + SwiftUI) for managing all your local Cloudflare Workers / Wrangler projects in one place: discover them, start and stop them, watch their logs, and browse their local data.

> WorkerDock is an independent project and is not affiliated with or endorsed by Cloudflare.

## What it does

- **Finds your projects**: add root folders (e.g. `~/Sites`); it scans for `wrangler.toml`, `wrangler.json`, `wrangler.jsonc` (skipping `node_modules`, `.wrangler`, `.git`, `dist`, `.output`, `.next`). You can also add a single project folder, and hide or remove projects.
- **Runs them**: plain `wrangler dev`, Cloudflare Vite plugin projects (`<pm> run dev`), or any custom command. Package manager is detected from the lockfile. Each project runs in its own process group, so stopping it also stops `workerd`.
- **Logs**: live stdout/stderr, ANSI stripped, 5,000-line ring buffer, filter (⌘F), clear, auto-scroll.
- **Explorer**: embeds Wrangler's built-in Local Explorer (`/cdn-cgi/explorer`) for D1/KV/R2/Durable Objects/Workflows. Needs Wrangler 4.82.1+ (or Vite plugin 1.32.0+). Older versions get the exact update command.
- **Overview**: bindings parsed from config (names only, never values), versions, port, run mode, memory.
- **Menu bar**: start/stop toggles, open in browser / Explorer, stop all. The app keeps running from the menu bar when the window is closed.
- **Detects projects started from a terminal** (workerd processes matched to projects by working directory).

It never writes to your project folders (except when you press **Install** for missing dependencies), never modifies wrangler config, and never shows `vars` or `.dev.vars` values.

## Design

Colours come from the Webtions / SVG Ready design tokens (cream `#FFFDF9` and near-black `#0A0A0A` backgrounds, coral accent `#FF3253`, amber `#FFB500` highlight in dark mode) and follow the system light/dark setting. Icons are [Lucide](https://lucide.dev) (ISC licence, see `WorkerDock/Resources/LUCIDE-LICENSE.txt`), bundled as vector assets. The bindings diagram on the Overview tab mirrors Cloudflare's Worker-to-resources view, and its connections animate while a project runs. The app icon is drawn in code (`AppIconArt.swift`); the 1024px master is in `tools/icon/`.

## Requirements

- macOS 14+, Xcode 15+ (developed on Xcode 26)
- [XcodeGen](https://github.com/yonaskolb/XcodeGen): `brew install xcodegen`

## Build and run

```bash
xcodegen generate
open WorkerDock.xcodeproj      # then press ⌘R in Xcode
```

Or from the command line:

```bash
xcodegen generate
xcodebuild -project WorkerDock.xcodeproj -scheme WorkerDock -configuration Debug -destination 'platform=macOS' build
xcodebuild -project WorkerDock.xcodeproj -scheme WorkerDock -destination 'platform=macOS' test
```

The built app is in `~/Library/Developer/Xcode/DerivedData/WorkerDock-*/Build/Products/Debug/WorkerDock.app`.

The Xcode project is generated from `project.yml` and is not committed.

## Keyboard shortcuts

| Shortcut | Action |
|---|---|
| ⌘↩ | Start selected project |
| ⌘R | Restart |
| ⌘. | Stop |
| ⌘F | Search logs |
| ⇧⌘R | Rescan folders |

## Where things are stored

`~/Library/Application Support/WorkerDock/`: `registry.json` (folders, projects, ports, per-project run settings), `settings.json` (editor command, Node override, folder watching) and `running.json` (processes started by the app, used to offer cleanup after a crash).

## Renaming the app

Change the name in `project.yml` (`name`, `PRODUCT_NAME`, bundle ID), `AppInfo.name` / `AppInfo.supportDirName` in `WorkerDock/Models/Models.swift`, and rename the `WorkerDock/` folder references in `project.yml`. Then run `xcodegen generate`.

## Layout

```
project.yml                 XcodeGen spec
WorkerDock/
  App/                      App entry, menu bar, quit handling
  Core/                     AppModel, persistence, login-shell environment
  Discovery/                Scanner, TOML/JSON/JSONC parser, inspector, FSEvents watcher
  Process/                  ProcessManager (actor), ports, output parsing, libproc, running detection
  Models/                   Project, bindings, runtime state
  Views/                    SwiftUI views
WorkerDockTests/            Unit tests (parsing, discovery, real process-group tests)
```

## Known limitations (v1)

- Distribution needs a Developer ID certificate + notarization (the project builds with ad-hoc signing; sandbox is off by design).
- Logs can't be captured for projects started outside the app.
- For terminal-started projects the port is inferred from workerd's listening sockets.
- Out of scope for v1 (architecture is ready): deploys, D1 migrations UI, `.dev.vars` editor, `project.test` domains, request inspector sidecar, multi-worker sessions.
