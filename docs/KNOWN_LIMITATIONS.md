# Known Limitations and Implementation Status (Milestones 1, 2 & 3)

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
- **State Management & UI**:
  - `SyncController` managing socket lifecycle, LAN discovery, pairing state, and device synchronization.
  - `DevicesPage` providing:
    - Local device info card with inline rename and "Show Pairing Code" modal.
    - Real-time list of discovered Wi-Fi peers with quick-pair action.
    - Paired devices management with inline "Sync Now", trust toggle, and device removal.
    - Global "Sync All" action in AppBar.
  - `TaskController` managing search, categories, completion filters, and task CRUD.
  - `SettingsController` persisting ThemeMode (System, Light, Dark), showCompleted toggle, and default priority via `SharedPreferences`.
  - Responsive `TasksPage` featuring:
    - Search text field.
    - Material 3 `SegmentedButton` view toggle: All, Pending, Completed.
    - Category filter chips (horizontally scrollable, dynamic from tasks).
    - Task list tiles with priority flags, due dates, recurrence badges, strike-through completion, and swipe-to-delete.
  - `TaskEditPage` with form validation, date/time picker, priority selector, and repeat selector.
  - `SettingsPage` with appearance controls, platform capability indicators, link to Devices & Sync, and in-app update checker.
- **In-App Update Delivery & CI/CD**:
  - `UpdateService` checking GitHub Releases API (`onebotyt/Smart-To-Do`) for new releases.
  - Settings page one-click update launcher for Android APK and Windows application.
  - Automated GitHub Actions release pipeline (`.github/workflows/build.yml`) auto-numbering releases (`v0.1.<run_number>`) and publishing Android and Windows assets.
- **Automated Testing Suite (30 Tests Passing)**:
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
- **Physical Device Execution**:
  - Verified on x86_64 Android Emulator (`Small_Phone`, Android API 36.1, PID 2567).
  - TCP socket sync and UDP discovery verified through automated loopback integration tests; untested across two separate physical devices on external Wi-Fi.

## 3. Missing Platform Integrations (Planned for Milestones 4+)
- **Windows Desktop Native Integration (Milestone 4)**:
  - System-tray icon, always-on-top floating task panel, launch-at-startup.
- **Android Native Productivity Integration (Milestone 4 & 6)**:
  - Android home-screen AppWidget (`AppWidgetProvider`).
  - Android floating overlay window (`SYSTEM_ALERT_WINDOW` foreground service).
- **Universal Clipboard (Milestone 5)**:
  - Native clipboard listeners, deduplication, encrypted peer clipboard sync.

## 4. Required Tools & Environment Constraints
- **Local Windows Build Tools**:
  - Building Windows desktop binaries locally requires Microsoft Visual Studio with the "Desktop development with C++" workload and Windows Developer Mode enabled.
  - Windows desktop releases are built and packaged by the GitHub Actions CI workflow running in `windows-latest`.
- **Android Gradle Kotlin Incremental Compilation**:
  - Stabilized via `kotlin.incremental=false` in `android/gradle.properties` for cross-drive builds on Windows.

## 5. Outstanding Errors
- None. `flutter analyze` reports zero errors/warnings, and all 30 automated tests pass.
