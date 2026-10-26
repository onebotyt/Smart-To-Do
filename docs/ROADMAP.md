# Roadmap
Targets: **Android + Windows first.**

1. **Foundation (CURRENT)** — Flutter project, task screens, SQLite persistence, settings, tests. *(code scaffolded in repo; needs first compile)*
2. **Reliable local data** — migrations, change tracking hardening, offline queue, tombstones, conflict-resolution primitives, crash/restart tests.
3. **Phone–PC sync** — discovery, pairing, authenticated encrypted transport, incremental sync; test disconnects, duplicates, simultaneous edits.
4. **Native productivity** — Windows floating panel + tray, Android floating service + widget, clipboard sharing, startup/background behaviour.
5. **Expand & validate** — iOS/macOS/Linux, platform widgets, security review, usability testing, packaging.

Rule: do not start a milestone until the previous one passes analyze, tests and a real-device run.
