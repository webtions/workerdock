# Overview

**WorkerDock** is a native macOS app (Swift + SwiftUI, macOS 14+) that manages every local Cloudflare Workers,
Pages and Astro/Vite project on a developer's Mac from one window and the menu bar. It is an independent
project, not affiliated with or endorsed by Cloudflare. Published by Webtions OÜ (author: Harish Chouhan).

## What it does
- **Finds projects.** Add root folders (e.g. `~/Sites`); it scans for `wrangler.toml`, `wrangler.json`,
  `wrangler.jsonc` (skipping `node_modules`, `.wrangler`, `.git`, `dist`, `.output`, `.next`). Single project
  folders can be added, and projects can be hidden, removed or marked as favourites.
- **Detects what each project is.** Framework (Astro, Nuxt, Next.js, SvelteKit, Remix, React Router,
  VitePress, Docusaurus, Gatsby), CMS (EmDash), Pages, Cloudflare Vite plugin, plain Worker. Shows a matching
  icon and a type chip.
- **Starts and stops them.** Picks the right command per project (see "Run modes"), a free port, and the right
  folder. Each project runs in its own process group so stopping it also stops `workerd`.
- **Shows live state.** Status, memory (including `workerd`), logs (selectable, copyable, filterable).
- **Shows the wiring.** A diagram or list of bindings (D1, KV, R2, queues, Durable Objects, workflows,
  service bindings, AI, Vectorize, Hyperdrive, Analytics, Browser, Assets) and variable *names*.
- **Embeds Wrangler's Local Explorer** (`/cdn-cgi/explorer`) to browse local D1/KV/R2/Durable Object/Workflow
  data. Needs Wrangler 4.82.1+ or Cloudflare Vite plugin 1.32.0+.
- **Lives in the menu bar.** Start/stop/restart, open site/explorer/admin, show in app, stop all.
- **Detects servers started from a terminal** and shows them as running (can stop them, or restart them under
  WorkerDock so logs become available).
- **Explains problems.** Missing dependencies (shows the command to run), port already in use (names the
  owner, offers "Start on a free port").
- **Updates itself** with Sparkle.

## Run modes
| Mode | Command WorkerDock runs |
|---|---|
| Plain Wrangler | `<pm exec> wrangler dev --port N --inspector-port M` |
| Wrangler Pages | `<pm exec> wrangler pages dev <dir> --port N --inspector-port M` |
| Project dev script / Vite plugin | `<pm> run dev` (optionally with `--port N`) in the nearest `package.json` folder |
| Custom command | whatever the user typed (Settings tab) |

The package manager (npm, pnpm, yarn, bun) is detected from the lockfile.

## Principles
1. **Read-only toward projects.** It never writes to a project folder, never changes wrangler config and never
   installs anything. (The earlier Install button was removed on purpose; the website promises "read-only".)
2. **Secrets stay secret.** Only variable *names* are shown, never values from `vars` or `.dev.vars`.
3. **Private.** Everything runs on the Mac. The only network use is the update check (Sparkle) and the
   embedded Local Explorer on localhost.
4. **Native and light.** SwiftUI/AppKit, no Electron.
5. **Flat design, plain wording.** See [design-system.md](design-system.md).

## Requirements
macOS 14 (Sonoma) or later, Apple silicon or Intel (universal build). Node/Wrangler are the user's own; the
app reads the login-shell environment to find them.

## Price
Free.
