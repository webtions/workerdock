# Development

## Prerequisites
- macOS 14+, Xcode 15+ (developed on Xcode 26)
- XcodeGen: `brew install xcodegen`
- The project file is generated: `*.xcodeproj` and `WorkerDock/Info.plist` are git-ignored. After pulling,
  adding or removing source files, or changing `project.yml`, run `xcodegen generate`.

## Build and run
```bash
xcodegen generate
open WorkerDock.xcodeproj            # then ⌘R
# or
xcodebuild -project WorkerDock.xcodeproj -scheme WorkerDock -configuration Debug -destination 'platform=macOS' build
```
Swift packages (TOMLKit, Sparkle) resolve automatically on first build.

## Tests
```bash
xcodebuild -project WorkerDock.xcodeproj -scheme WorkerDock -destination 'platform=macOS' test
```
28 tests: SemVer, JSONC/TOML parsing, output parsing (including port-in-use detection), process manager
(start/stop/group kill), discovery and an end-to-end run with a fake `npx wrangler`. Tests set
`WORKERDOCK_SUPPORT_DIR` so they never touch the real registry, and the test host app stays invisible.

## Demo mode (screenshots, marketing)
`WORKERDOCK_DEMO=1` shows invented projects (aurora-api, lumen-checkout, ...) with fake logs, memory and
favourites, and persists nothing. Combine with `WORKERDOCK_DEMO_TAB=logs` (or overview/explorer/settings) and
`WORKERDOCK_WIDTH=820`.
```bash
WORKERDOCK_DEMO=1 WORKERDOCK_DEMO_TAB=logs \
  ~/Library/Developer/Xcode/DerivedData/WorkerDock-*/Build/Products/Debug/WorkerDock.app/Contents/MacOS/WorkerDock
```
Running the binary directly starts a second process next to a running real copy; they share saved window
state (UserDefaults) but demo mode does not write the registry.

Screenshot tips: capture only the app window (`screencapture -l <windowID>`, window ID from
`CGWindowListCopyWindowInfo` filtered by process ID), never the whole screen.

## Debugging switches
See the table in [architecture.md](architecture.md). `WORKERDOCK_UPDATER=1` enables Sparkle in debug builds.
`WORKERDOCK_DEBUG_START=<project name>` + `WORKERDOCK_DEBUG_OUT=<file>` starts a real project headless and
writes a status report (this runs the project's real dev script, which may write build output in that project).

## Conventions
- Small, logical commits with a clear body.
- After UI changes, quit the app (⌘Q, or `osascript -e 'tell application id "dev.workerdock.app" to quit'`) and
  relaunch so the new build is the one on screen. Never `pkill` the app: it skips the clean shutdown and leaves
  `workerd` processes behind (the app then shows a "found projects still running" prompt).
- UI changes follow [design-system.md](design-system.md). Verify in light mode; dark mode is supported but is
  not the focus.
- Never add a feature that writes to a project folder.
