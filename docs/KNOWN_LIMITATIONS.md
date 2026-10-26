# Known Limitations and Implementation Status (Milestones 1 & 2)

## 1. Implemented Features
- **Local Database Architecture & Migrations (Milestones 1 & 2)**:
  - SQLite schema v2 (`AppDatabase` with `tasks`, `change_log`, `meta`, and `conflict_log` tables).
  - Versioned migration pipeline (`onUpgrade: v1 -> v2`) preserving all user data and indexes.
  - Transactional `TaskRepository` ensuring atomic `tasks` writes and revision/change-log stamping.
  - Soft-deletion tombstone tracking for sync readiness with configurable `purgeTombstones(retention = 30 days)` enforcing sync acknowledgment.
  - Monotonic offline change queue (`getUnsyncedChanges`, `markChangesSynced`).
  - `ConflictResolver` engine implementing 3-way field-level merge, Last-Write-Wins (`updatedAt` + `deviceId` tie-breaker), and Delete vs Edit resurrection.
  - Recurrence logic (advancing due date on daily/weekly tasks upon completion).
  - Stable UUID v4 device ID generation stored in database metadata.
- **State Management & UI**:
  - `TaskController` managing search, categories, completion filters, and task CRUD.
  - `SettingsController` persisting ThemeMode (System, Light, Dark), showCompleted toggle, and default priority via `SharedPreferences`.
  - Responsive `TasksPage` featuring:
    - Search text field.
    - Material 3 `SegmentedButton` view toggle: All, Pending, Completed.
    - Category filter chips (horizontally scrollable, dynamic from tasks).
    - Task list tiles with priority flags, due dates, recurrence badges, strike-through completion, and swipe-to-delete.
  - `TaskEditPage` with form validation, date/time picker, priority selector, and repeat selector.
  - `SettingsPage` with appearance controls, platform capability indicators, and in-app update checker.
- **In-App Update Delivery & CI/CD**:
  - `UpdateService` checking GitHub Releases API (`onebotyt/Smart-To-Do`) for new releases.
  - Settings page one-click update launcher for Android APK and Windows application.
  - Automated GitHub Actions release pipeline (`.github/workflows/build.yml`) auto-numbering releases (`v0.1.<run_number>`) and publishing Android and Windows assets.
- **Automated Testing Suite (16 Tests Passing)**:
  - `test/task_repository_test.dart` (CRUD, change log atomicity, tombstone marking, search & recurrence).
  - `test/task_creation_widget_test.dart` (Full UI creation flow, validation, category chips, view toggle).
  - `test/migration_test.dart` (v1 to v2 database upgrade data preservation & index creation).
  - `test/conflict_resolver_test.dart` (3-way merge, LWW, tie-breakers, resurrection).
  - `test/tombstone_and_queue_test.dart` (Tombstone retention purge, monotonic queue, conflict logging).
  - `test/update_service_test.dart` (Release info model and version checking).
  - Clean `flutter analyze` (0 issues).

## 2. Implemented, Untested Features
- **Physical Device Execution**:
  - Verified on x86_64 Android Emulator (`Small_Phone`, Android API 36.1, PID 2567 running Impeller backend without crash).
  - Untested on physical Android hardware.

## 3. Missing Platform Integrations (Planned for Milestones 3+)
- **Device-to-Device Sync (Milestone 3)**:
  - Local Wi-Fi discovery (mDNS), mutual TLS/Noise key exchange, encrypted direct sync protocol over LAN sockets.
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
- None. `flutter analyze` reports zero errors/warnings, and all 16 automated tests pass.
