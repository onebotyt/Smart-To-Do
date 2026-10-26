# Known Limitations and Implementation Status (Milestones 1, 2, 3, 4 & 5)

## 1. Implemented Features
- **Local Database Architecture & Migrations (Milestones 1 & 2)**:
  - SQLite schema v3 (`AppDatabase` with `tasks`, `change_log`, `meta`, `conflict_log`, and `devices` tables).
  - Versioned migration pipeline (`onUpgrade: v1 -> v2 -> v3`) preserving all user data and indexes.
  - Transactional `TaskRepository` ensuring atomic `tasks` writes and revision/change-log stamping.
  - Soft-deletion tombstone tracking for sync readiness with configurable `purgeTombstones(retention = 30 days)` enforcing sync acknowledgment.
  - Monotonic offline change queue (`getUnsyncedChanges`, `markChangesSynced`).
  - `ConflictResolver` engine implementing 3-way field-level merge, Last-Write-Wins (`updatedAt` + `deviceId` tie-breaker), and Delete vs Edit resurrection.
  - Recurrence logic (advancing due date on daily/weekly tasks upon completion).
  - Stable UUID v4 device ID generation stored in database metadata.
- **Direct Phone–PC Sync & P2P Transport (Milestone 3)**:
  - `DeviceRepository` managing paired devices, network addresses, last-seen timestamps, and trust revocation.
  - `SyncMessage` protocol with JSON schema validation, replay attack protection, and monotonic sequence counters.
  - `LanDiscovery` using UDP broadcast beacons on port 43884 to discover SyncTask peers on the same local Wi-Fi.
  - `SyncEngine` TCP server and client socket transport implementing:
    - 6-digit confirmation PIN pairing handshake.
    - Mutual device authentication verifying sender ID against SQLite trusted devices.
    - Immediate rejection of revoked or unknown peers (`AUTH_FAILED`) without data leakage.
    - Bidirectional version vector exchange with `${revision}:${deviceId}` composite entries for concurrent edit detection.
    - Delta streaming, conflict resolution via `ConflictResolver`, and tombstone propagation.
- **Native Productivity Features (Milestone 4)**:
  - `FloatingTaskPanel` compact quick-entry overlay with priority selector, one-tap checkboxes, quick sync, and pending filters.
  - Platform service abstraction layer in `lib/platform/`:
    - `FloatingPanelService`: overlay window management and `SYSTEM_ALERT_WINDOW` permission flow.
    - `TrayService`: system tray lifecycle, tooltips, and background minimize behavior.
    - `StartupService`: launch-at-startup configuration.
    - `WidgetService`: real-time native home-screen widget synchronization.
  - Android native productivity integration:
    - `SYSTEM_ALERT_WINDOW` overlay permission handling in `MainActivity.kt`.
    - Android native home-screen widget (`SyncTaskWidgetProvider.kt`, `widget_sync_task.xml`) showing pending task badge and top pending task checklist.
    - Automatic widget updates whenever tasks change in `TaskController`.
  - Windows productivity integration:
    - Launch-at-startup settings toggle and background tray architecture.
- **Universal Clipboard Sharing (Milestone 5)**:
  - `ClipboardService` platform abstraction layer with `onLocalCopy`, `readText`, and `writeText`.
  - `ClipboardController` managing:
    - Strict **opt-in** preference (disabled by default in settings).
    - One-tap **pause / resume** controls.
    - **Loop prevention & deduplication**: rolling SHA-256 hash cache preventing bounce-back echo loops between devices.
    - **Zero logging**: strictly enforces that clipboard content is never logged, printed, or persisted in application logs.
    - **Plain-text only**: rejects rich/binary payload types.
  - `SyncEngine.broadcastClipboardText` delivering plain-text clipboard events directly to reachable trusted peers over TCP.
  - Inbound mutual authentication ensuring only verified, trusted devices can deliver clipboard text.
- **State Management & UI**:
  - `SyncController` managing socket lifecycle, LAN discovery, pairing state, and device synchronization.
  - `ClipboardController` managing universal clipboard opt-in, pause state, and synchronization.
  - `DevicesPage` with local device info, Wi-Fi peer discovery, paired devices management, and global sync.
  - `TasksPage` with task management, floating panel launcher, and search.
  - `SettingsPage` with appearance, sync, productivity features, universal clipboard controls, and in-app update checker.
- **Automated Testing Suite (39 Tests Passing)**:
  - `test/clipboard_test.dart` (4 tests: opt-in enforcement, pause suppression, deduplication/loop prevention, and P2P loopback sync).
  - `test/floating_panel_widget_test.dart` (FloatingTaskPanel UI, quick entry, completion toggle, filter).
  - `test/productivity_services_test.dart` (FloatingPanelService, StartupService, WidgetService, TrayService).
  - `test/sync_engine_test.dart` (4 tests: P2P PIN pairing, bidirectional task sync, security rejection, concurrent edit conflict resolution).
  - `test/sync_message_test.dart` (4 tests: serialization, schema validation, message types, error handling).
  - `test/device_repository_test.dart` (5 tests: CRUD, trust filtering, network address updates, deletion, local device name).
  - `test/devices_widget_test.dart` (UI widget test: local device card, pairing code generation dialog, device tile rendering).
  - `test/conflict_resolver_test.dart` (5 tests: 3-way merge, LWW, tie-breakers, resurrection, tombstone precedence).
  - `test/tombstone_and_queue_test.dart` (4 tests: Tombstone retention purge, monotonic queue, conflict logging).
  - `test/migration_test.dart` (1 test: v1 to v3 database upgrade data preservation & index creation).
  - `test/task_repository_test.dart` (4 tests: CRUD, change log atomicity, tombstone marking, search & recurrence).
  - `test/task_creation_widget_test.dart` (1 test: Full UI creation flow, validation, category chips, view toggle).
  - `test/update_service_test.dart` (1 test: Release info model and version checking).
  - Clean `flutter analyze` (0 issues).

## 2. Implemented, Untested Features
- **Physical Device & Native OS Verification**:
  - Verified on x86_64 Android Emulator (`Small_Phone`, Android API 36.1, PID 2567).
  - Universal Clipboard text sharing verified through automated dual-instance loopback integration tests; untested between two separate physical devices on external Wi-Fi.

## 3. Missing Platform Integrations (Planned for Milestones 6+)
- **Additional Platforms (Milestone 6)**:
  - iOS WidgetKit, macOS menu bar extras, Linux system tray.

## 4. Required Tools & Environment Constraints
- **Local Windows Build Tools**:
  - Building Windows desktop binaries locally requires Microsoft Visual Studio with the "Desktop development with C++" workload and Windows Developer Mode enabled.
  - Windows desktop releases are built and packaged by the GitHub Actions CI workflow running in `windows-latest`.
- **Android Gradle Kotlin Incremental Compilation**:
  - Stabilized via `kotlin.incremental=false` in `android/gradle.properties` for cross-drive builds on Windows.

## 5. Outstanding Errors
- None. `flutter analyze` reports zero errors/warnings, and all 39 automated tests pass.
