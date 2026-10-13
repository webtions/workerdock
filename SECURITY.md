# Security policy

## Supported versions
Only the latest release is supported with security fixes. WorkerDock updates itself, so most people are on it.

## Reporting a vulnerability
**Please don't open a public issue for security problems.** Instead:
1. Use GitHub's private reporting: the **Security** tab of this repository > **Report a vulnerability**; or
2. Email **mail@workerdock.app** with "WorkerDock security" in the subject.

Include what you found, how to reproduce it, the WorkerDock and macOS versions, and what you think the impact is. We aim to
reply within a few days, agree on a fix and timeline, and credit you if you wish.

## What counts
Things we want to hear about include: the app writing to a project folder or Wrangler config, showing secret values from
`vars` or `.dev.vars`, running or being made to run unintended commands, unsafe handling of project paths or process
output, problems in the update mechanism, and anything that sends data off your Mac other than the update check.

## What WorkerDock does and doesn't do
- It runs commands you'd run yourself (`wrangler dev`, your package manager's dev script, or a custom command you set) in
  your project folders, using your login-shell environment.
- It is not sandboxed by design, because it must run those tools and read your project folders.
- Its only network call is the update check to `https://workerdock.app/appcast.xml`. Updates are signed with an EdDSA key
  and with Apple's Developer ID, and checked before installing.
