# WorkerDock

**One window for all your local Cloudflare Workers projects.** A native, fast macOS app (Swift and SwiftUI) that finds every
Workers, Pages and Astro/Vite project on your Mac, starts and stops them, streams their logs, shows what each one is wired
to, and lives in your menu bar.

[Website](https://workerdock.app) · [Download](https://workerdock.app) · [Docs](_docs/README.md) · [Report a bug](../../issues/new?template=bug_report.yml) · [Request a feature](../../issues/new?template=feature_request.yml)

[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE) ![Platform: macOS 14+](https://img.shields.io/badge/macOS-14%2B-lightgrey) ![Swift](https://img.shields.io/badge/Swift-SwiftUI-orange)

> WorkerDock is an independent project and is not affiliated with or endorsed by Cloudflare.

## What it does

- **Finds your projects.** Add a folder like `~/Sites`; it scans for `wrangler.toml`, `wrangler.json` and `wrangler.jsonc`
  (skipping `node_modules`, `.wrangler`, `.git`, `dist` and similar). Hide, remove or favorite projects.
- **Knows what each one is.** Astro, Nuxt, Next.js, SvelteKit, Remix, React Router, VitePress, Docusaurus, Gatsby, EmDash,
  Pages, Vite plugin, plain Worker, with the right icon and the right start command.
- **Starts and stops them cleanly.** Each project runs in its own process group, so stopping it also stops `workerd`. Free
  ports are picked for you, and a port clash tells you who has the port and offers "Start on a free port".
- **Shows the wiring.** D1, KV, R2, queues, Durable Objects, workflows, service bindings, AI and more as a diagram or a
  list. Variable *names* only, never values.
- **Logs you can use.** Live output with colour, filter, follow, and normal text selection and copy.
- **Local Explorer built in.** Browse local D1, KV, R2, Durable Object and Workflow data (needs Wrangler 4.82.1+ or the
  Cloudflare Vite plugin 1.32.0+).
- **Menu bar control.** Start, stop, restart and open sites without switching windows.
- **Light on memory.** Native, no Electron. Each running project shows its real memory use.
- **Updates itself** with [Sparkle](https://sparkle-project.org).

## Principles

1. **Read-only toward your projects.** It never writes to a project folder, never edits your Wrangler config and never
   installs anything. When dependencies are missing it shows the command and leaves running it to you.
2. **Secrets stay secret.** Variable names appear, values from `vars` and `.dev.vars` never do.
3. **Private.** Everything runs on your Mac. The only network call is the update check.
4. **Native and quiet.** Flat design, plain wording, nothing that nags.

Feature requests are judged against these. See [CONTRIBUTING.md](CONTRIBUTING.md).

## Install

Download the latest signed and notarised build from <https://workerdock.app>, open the `.dmg` and drag WorkerDock to
Applications. Requires macOS 14 (Sonoma) or later.

## Build from source

You need macOS 14+, Xcode 15+ (developed on a current Xcode) and [XcodeGen](https://github.com/yonaskolb/XcodeGen).

```bash
brew install xcodegen
xcodegen generate
open WorkerDock.xcodeproj      # then press ⌘R
```

Or from the command line:

```bash
xcodegen generate
xcodebuild -project WorkerDock.xcodeproj -scheme WorkerDock -configuration Debug -destination 'platform=macOS' build
xcodebuild -project WorkerDock.xcodeproj -scheme WorkerDock -destination 'platform=macOS' test
```

The Xcode project is generated from `project.yml` and is not committed. A build you make yourself is unsigned for
distribution and doesn't update itself. See [_docs/development.md](_docs/development.md) for demo mode, debug switches
and conventions.

## Keyboard shortcuts

| Shortcut | Action |
|---|---|
| ⌘↩ | Start the selected project |
| ⌘R | Restart |
| ⌘. | Stop |
| ⌘F | Find in logs |
| ⇧⌘R | Rescan folders |
| ⌘, | Settings |

## Where it stores things

`~/Library/Application Support/WorkerDock/` holds `registry.json` (folders, projects, per-project run settings),
`settings.json` (theme, terminal and editor, Node override, login item) and `running.json` (processes it started, used to
offer cleanup after a crash). Nothing is written to your project folders.

## Documentation

Everything else is in [`_docs/`](_docs/README.md): architecture, design system, development, how releases and updates
work, third-party tools and the reasons behind decisions.

## Contributing

Bug reports, ideas and pull requests are welcome. Please read [CONTRIBUTING.md](CONTRIBUTING.md) first, and the
[Code of Conduct](CODE_OF_CONDUCT.md). To report a security problem, see [SECURITY.md](SECURITY.md).

## License

The code is released under the [MIT License](LICENSE), copyright © 2026 Webtions OÜ. The WorkerDock name, the Webtions logomark and the app icon are not
covered by that licence; see [TRADEMARKS.md](TRADEMARKS.md). Third-party components and their licences are listed in
[THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).

---

Built by [Webtions](https://webtions.com).
