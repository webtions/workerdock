# Changelog

## Unreleased
- WorkerDock no longer installs dependencies. The "dependencies not installed" banner shows the command with Copy and Open Terminal, and Start is disabled until they are installed.

## M4: Explorer, detection, memory, polish
- Explorer tab embeds Local Explorer in a WKWebView that exists only while the tab is visible and the project is running; Wrangler < 4.82.1 (or Vite plugin < 1.32.0) shows the exact update command for the project's package manager.
- Detects `workerd` processes started from a terminal and matches them to projects by working directory (libproc, no `lsof`).
- Per-project memory (resident size of the whole process group), measured only while the Overview tab is on screen.
- Orphan detection after a crash, with an offer to stop them (guarded against PID reuse).
- README, tests.

## M3: Process manager
- `ProcessManager` actor: `posix_spawn` with its own process group, SIGTERM to the group then SIGKILL after 5s.
- Port allocation from 8787 (inspector from 9230), availability checks, persisted per project.
- "Ready on http://…" is the source of truth for the URL; Vite/custom commands use the first localhost URL printed.
- Log ring buffer (5,000 lines), ANSI stripped, filter / clear / auto-scroll.
- Quit asks before stopping running projects.

## M2: Discovery and config parsing
- Recursive scanner with the required skip list; manual add, hide, remove; rescan; optional FSEvents watching.
- TOML (TOMLKit) / JSON / JSONC parsing; bindings by name only.
- Package manager, Wrangler version, Vite-plugin detection; "dependencies not installed" with Install button.
- Registry persisted as JSON in Application Support.

## M1: Skeleton
- XcodeGen project (macOS 14, sandbox off, local networking allowed).
- Main window (NavigationSplitView), menu bar extra, Settings, login-shell environment resolution with timeout and fallback, Node path override.
