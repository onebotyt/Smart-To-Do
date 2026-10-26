# SyncTask — Project Specification

## Goal
One Flutter/Dart codebase for Android, Windows, iOS, macOS, Linux (no web). Tasks stored locally in
SQLite, fully usable offline, synchronized directly between trusted devices. No hosted backend,
no cloud account for core features. Native code is isolated behind platform adapters.

Core principle: shared app logic, a separate local database per device, secure direct communication
when devices can connect.

## Platform capability matrix
| Platform | Floating interface | Widgets | Clipboard sharing |
|---|---|---|---|
| Android | Native overlay (permission) | Native home-screen widget | Native clipboard integration (OS limits apply) |
| Windows | Always-on-top window + tray | Widget-like window | Native clipboard listener |
| iOS | No overlay over other apps | WidgetKit | Heavily restricted in background |
| macOS | Native floating window | Native widgets | Native clipboard |
| Linux | Desktop-specific window | DE dependent | Desktop clipboard |

Not every feature can work identically everywhere. The app exposes a capability check
(`lib/core/capabilities.dart`) so Settings can show unsupported options.

## Features
- **Tasks:** create/edit/complete/delete, due dates, priorities, categories, recurring, pending/completed views, search, optional reminders.
- **Local sync:** device discovery, same-Wi-Fi sync, persistent pairing, offline change queue, reconnect, conflict resolution, deletion propagation.
- **Floating panel:** optional icon, compact task list over other apps, move/resize, opacity/size settings, add/complete without opening full app.
- **Widgets:** today's tasks + pending count, quick complete, configurable filters, reads local cache.
- **Clipboard sharing:** plain text, bidirectional between paired devices, encrypted, loop prevention, pause/enable controls, one latest item (no history).

## Settings groups
Appearance, Tasks, Floating panel, Widgets, Synchronization, Devices (pair/trust/revoke/rename),
Clipboard, Startup, Privacy (retention, backup, export, deletion, diagnostics).

## Tech stack
Dart + Flutter; Kotlin (Android native); Windows native APIs as required; SQLite via a shared Dart
repository layer; LAN peer-to-peer sync; authenticated + encrypted transport; WidgetKit for iOS widgets; Git.
Dev environment: Antigravity IDE (agent-driven coding) + Android SDK for builds/emulators.

## Out of scope (initial)
Web app, mandatory cloud backend, mandatory accounts, cloud-hosted storage, central sync server.
Optional cloud sync may be considered later.

## Status
Requirements and architecture defined. Implementation, platform compatibility and performance are unverified.
