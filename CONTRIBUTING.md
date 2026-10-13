# Contributing to WorkerDock

Thanks for wanting to help. WorkerDock is a small, focused app, and the way to keep it good is to keep it focused. This page
explains how to report problems, ask for features and send code.

## Before you start
- Read the [principles in the README](README.md#principles). The big one: **WorkerDock never writes to a project folder,
  never edits Wrangler config and never installs anything.** Changes that break these won't be accepted.
- Search the [existing issues](../../issues) first. Your bug or idea may already be there; add a 👍 or a comment.
- Be kind. See the [Code of Conduct](CODE_OF_CONDUCT.md).

## Reporting a bug
Use the **Bug report** form: [new bug report](../../issues/new?template=bug_report.yml). The most useful reports include:
- WorkerDock version (WorkerDock menu > About), macOS version, and your Wrangler version.
- Exactly what you did, what you expected and what happened. A screenshot or a short screen recording helps.
- The project type (plain Worker, Pages, Astro, Vite plugin, EmDash) and run mode (Settings tab of that project).
- Relevant log lines. **Remove anything private** (tokens, URLs, customer data) before pasting.

Security problems go through [SECURITY.md](SECURITY.md), not a public issue.

## Requesting a feature
Use the **Feature request** form: [new feature request](../../issues/new?template=feature_request.yml). We read every one.
To make a request easy to say yes to:
1. **Describe the problem first**, then your idea. "I lose track of which Worker uses port 8787" beats "add a port table".
2. Say how often it happens and what you do today instead.
3. Check it against the principles: read-only, private, native and quiet. If it needs write access to a project, say why
   and what the safest version would be.
4. One idea per request.

What happens next: we label it, ask questions if needed, and decide whether it fits. A "no" usually means "not in scope",
not "bad idea". The website's roadmap lists things we're already considering: <https://workerdock.app>.

## Sending code
1. **Open an issue first** for anything bigger than a small fix, so we can agree on the approach before you spend time.
2. Fork the repo and create a branch from `main`.
3. Set up the project ([README](README.md#build-from-source)) and run the tests before and after your change:
   ```bash
   xcodegen generate
   xcodebuild -project WorkerDock.xcodeproj -scheme WorkerDock -destination 'platform=macOS' test
   ```
4. Keep changes small and focused, with a clear commit message that explains **why**. Add or update tests for logic you touch
   (parsing, process handling, port detection and similar have good coverage; follow those examples).
5. For UI changes, follow the [design system](_docs/design-system.md): the spacing, radius, icon and type tokens in
   `WorkerDock/Views/Theme.swift`, flat styling (no shadows, gradients or tinted icon tiles), a hover state on everything
   clickable, and plain wording. Include before/after screenshots in the pull request.
6. Run the app and try your change. Demo mode (`WORKERDOCK_DEMO=1`) lets you test without touching real projects; see
   [_docs/development.md](_docs/development.md).
7. Open a pull request and fill in the template.

### Code style
Match the surrounding code: naming, comment density and idiom. Prefer small views and small functions. No new third-party
dependencies without discussing it first; if one is added, list it in [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).

### Licence of contributions
By submitting a contribution you agree it can be distributed under the project's [MIT License](LICENSE). You keep the
copyright to your work. Don't submit code you don't have the right to share.

### Branding
Contributions must not add new Webtions or WorkerDock marks, and the name, logo and icon stay under
[TRADEMARKS.md](TRADEMARKS.md).

## Releases
Releases are built and signed by the maintainer (see [_docs/release-and-updates.md](_docs/release-and-updates.md)). Pull
requests don't need to touch version numbers or the update feed.
