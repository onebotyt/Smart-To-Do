# AGENTS.md — Read this first (Antigravity / any coding agent)

You are helping build **SyncTask**: a native, cross-platform, local-first task manager
(Flutter + Dart) with direct device-to-device sync, a floating task panel, home-screen
widgets and Universal Clipboard-style text sharing. **No web app. No cloud backend. No accounts.**

## Read in this order
1. `docs/PROJECT_SPEC.md` — what we are building and why
2. `docs/ARCHITECTURE.md` — layers, folder rules, interfaces
3. `docs/ROADMAP.md` — milestones; we are on **Milestone 1**
4. `docs/SETUP.md` — toolchain and first-run commands
5. `docs/SYNC_PROTOCOL.md` and `docs/SECURITY.md` — read before touching sync/clipboard

## Current status
- Milestone 1 code (local task manager, SQLite, settings, tests) is **scaffolded but never compiled**.
  Platform folders (`android/`, `windows/`) do not exist yet — see `docs/SETUP.md` step 3.
- Nothing native (Kotlin/C++) has been written. Sync, clipboard, floating panel, widgets: NOT started.

## Working rules
- Work in **small, testable milestones**. Never generate the whole app at once.
- **Before any major architectural change, explain the plan and wait for approval.**
- After every change run: `flutter analyze` and `flutter test`. Fix all errors before continuing.
- Build for the target when possible (`flutter build apk --debug`, `flutter build windows`).
- Keep working functionality working. Commit to Git before each task so changes can be rolled back.
- All task writes go through `TaskRepository` (it maintains revision + change_log atomically). Never write to SQLite from UI code.
- Schema changes require a new migration and a bumped `AppDatabase.version`. Never edit the v1 schema in place after release.
- Platform-specific code lives behind Dart interfaces in `lib/platform/` (e.g. `ClipboardService`). UI/feature code must not call platform channels directly.
- Do not log task titles, notes or clipboard contents.
- Do not add a web target, a server, Firebase, or any cloud dependency.
- Prefer well-maintained packages; justify each new dependency in the commit message.
- **Never say a native feature is complete until it was tested on a real device/emulator.** Say "implemented, untested" instead, and list it in `docs/KNOWN_LIMITATIONS.md`.
- Record unfinished work and limitations in `docs/KNOWN_LIMITATIONS.md` (create it when first needed).

## Targets
Primary: **Android + Windows**. Later: iOS, macOS, Linux (iOS/macOS need a Mac + Xcode).

## Definition of done (per milestone)
`flutter analyze` clean, `flutter test` passing, app runs on Android and Windows, docs updated.
