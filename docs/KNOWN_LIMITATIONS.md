# Known Limitations and Implementation Status (Milestone 1)

## 1. Implemented Features
- **Local Database Architecture**:
  - SQLite schema v1 (`AppDatabase` with `tasks`, `change_log`, and `meta` tables).
  - Transactional `TaskRepository` ensuring atomic `tasks` writes and revision/change-log stamping.
  - Soft-deletion tombstone tracking for sync readiness.
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
  - `TaskEditPage` with form validation, date/time picker, priority selector, and repeat selector (using updated non-deprecated `initialValue` APIs).
  - `SettingsPage` with appearance controls and platform capability inspection indicators.
- **Automated Testing**:
  - Repository unit tests (`test/task_repository_test.dart`): 4 tests covering creation revision/change-log logging, tombstone deletion, search/completion filtering, and recurring task advancement.
  - Widget & UI flow tests (`test/task_creation_widget_test.dart`): end-to-end task creation, form submission, category chip rendering, pending/completed filtering, and repository persistence.
  - Clean `flutter analyze` (0 issues) and passing `flutter test` (5/5 tests passing).
- **CI/CD Automation**:
  - GitHub Actions workflow (`.github/workflows/build.yml`) configured to automatically analyze, test, and build downloadable artifacts for both Android APK and Windows desktop release.

## 2. Implemented, Untested Features
- **Physical Device Execution**:
  - Verified on x86_64 Android Emulator (`Small_Phone`, Android API 36.1, PID 2567 running Impeller backend without crash).
  - Untested on physical Android hardware.

## 3. Missing Platform Integrations (Planned for Later Milestones)
- **Windows Desktop Native Integration (Milestone 4)**:
  - System-tray icon, always-on-top floating task panel, launch-at-startup.
- **Android Native Productivity Integration (Milestone 4 & 6)**:
  - Android home-screen AppWidget (`AppWidgetProvider`).
  - Android floating overlay window (`SYSTEM_ALERT_WINDOW` foreground service).
- **Device-to-Device Sync (Milestones 2 & 3)**:
  - Local Wi-Fi discovery (mDNS), mutual TLS/Noise key exchange, encrypted direct sync protocol, conflict resolution, offline queueing.
- **Universal Clipboard (Milestone 5)**:
  - Native clipboard listeners, deduplication, encrypted peer clipboard sync.

## 4. Required Tools & Environment Constraints
- **Local Windows Build Tools**:
  - Building Windows desktop binaries locally requires Microsoft Visual Studio with the "Desktop development with C++" workload and Windows Developer Mode enabled (for symlink support).
  - In this local environment, Visual Studio C++ is not installed; Windows desktop builds are therefore delegated to the newly created GitHub Actions CI workflow which runs in a fully equipped `windows-latest` environment.
- **Android Gradle Kotlin Incremental Bug**:
  - When the project workspace resides on a separate drive (`D:\`) from the user Pub/Gradle cache (`C:\`), Kotlin's incremental compiler encounters an `IllegalArgumentException: this and base files have different roots`.
  - Resolved and stabilized by setting `kotlin.incremental=false` in `android/gradle.properties`.

## 5. Outstanding Errors
- None. `flutter analyze` reports zero errors/warnings, and all 5 automated unit and widget tests pass.
