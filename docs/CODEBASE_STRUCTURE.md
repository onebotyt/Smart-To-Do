# SyncTask Codebase Structure & Architecture

This document describes the codebase architecture of **SyncTask**, explaining how code is organized and how native hardware controls are separated between **Android** and **Windows (PC)**.

---

## 1. High-Level Architecture Overview

SyncTask is built with **Clean Architecture** principles in Flutter & Dart, with direct native platform channels:

```
synctask/
├── android/                   # Native Android (Kotlin + Gradle)
├── windows/                   # Native Windows (C++ Win32 Runner + CMake)
├── lib/
│   ├── core/                  # Core infrastructure (Crypto, SQLite, Logger, Theme)
│   ├── data/                  # Data layer (SQLite DAOs, Models, Repositories)
│   ├── domain/                # Domain entities & business contracts
│   ├── features/              # Feature modules (UI, Controllers, Dialogs)
│   └── platform/              # Platform abstraction layer
│       ├── common/            # Cross-platform services
│       ├── android/           # Android-specific platform services
│       └── windows/           # Windows-specific native Win32 services
├── test/                      # Unit & integration tests
└── docs/                      # Architectural & protocol documentation
```

---

## 2. Platform Native Separation: Android vs Windows

### A. Windows (PC Native Win32)
Windows code provides full hardware and OS window control via native Win32 C++ APIs in `windows/runner/flutter_window.cpp`:

1. **Window Management (`com.synctask/window`)**:
   - `normal` mode: Standard Win32 overlapped window (`WS_OVERLAPPEDWINDOW`), always `HWND_NOTOPMOST` so file pickers and dialogs appear in the foreground.
   - `bubble` mode: Circular borderless popup (`WS_POPUP`), masked with `CreateEllipticRgn`, pinned topmost (`HWND_TOPMOST`).
   - `panel` mode: Rounded-rectangle popup (`WS_POPUP`), masked with `CreateRoundRectRgn(..., radius 24)`.
   - `startDragging`: Seamless window dragging via `SendMessage(hwnd, WM_NCLBUTTONDOWN, HTCAPTION, 0)`.

2. **Official Silent Update System (`com.synctask/native_update`)**:
   - Executes Inno Setup silent updates via Win32 `ShellExecuteExW` with `SW_HIDE` and `/VERYSILENT /SUPPRESSMSGBOXES /FORCECLOSEAPPLICATIONS`.
   - **Zero `cmd.exe` or console windows** spawn during updates.
   - For portable ZIP builds, launches background extraction via `CreateProcessW` with `CREATE_NO_WINDOW`.

3. **Hardware & Settings Controller (`com.synctask/native_settings`)**:
   - Dispatches directly to Win32 `ShellExecuteW` for `ms-settings:bluetooth`, `ms-settings:network-wifi`, and `ms-settings:network-mobilehotspot`.

4. **Auto-Start at Boot (`com.synctask/startup`)**:
   - Writes directly to `HKCU\Software\Microsoft\Windows\CurrentVersion\Run\SyncTask`.

---

### B. Android Native (Kotlin)
Android code handles Android OS lifecycle, permissions, and background services in `android/app/src/main/kotlin/com/synctask/synctask/`:

1. **Overlay Bubble Service (`com.synctask/floating_panel`)**:
   - `FloatingBubbleService.kt`: Android `SYSTEM_ALERT_WINDOW` floating overlay service with touch dragging and bubble expansion.

2. **Home Screen Widgets (`com.synctask/widget`)**:
   - `SyncTaskWidgetProvider.kt`: Android `AppWidgetProvider` for rendering task counters and priority pills directly on the Android home screen.

3. **Native APK Installer (`com.synctask/installer`)**:
   - `MainActivity.kt`: Direct native package installation prompt using `FileProvider.getUriForFile` and `ACTION_VIEW` intent with `FLAG_GRANT_READ_URI_PERMISSION`.

4. **Native Settings (`com.synctask/native_settings`)**:
   - Checks Bluetooth adapter status and launches `Settings.ACTION_BLUETOOTH_SETTINGS`, `Settings.ACTION_WIFI_SETTINGS`, or `ACTION_TETHER_SETTINGS`.

5. **Boot Receiver (`BootReceiver.kt`)**:
   - Restores floating bubble or widget state upon device reboot (`RECEIVE_BOOT_COMPLETED`).

---

## 3. Platform Abstraction Layer (`lib/platform/`)

To keep UI code completely decoupled from platform-specific code, all platform interactions go through `lib/platform/`:

| Folder / File | Target OS | Description |
|---|---|---|
| `lib/platform/common/native_network_service.dart` | All | Unified interface for Bluetooth, Wi-Fi, and Hotspot settings |
| `lib/platform/common/clipboard_service.dart` | All | P2P Universal Clipboard sync monitor and broadcaster |
| `lib/platform/common/update_service.dart` | All | GitHub Releases update checker with semver comparison |
| `lib/platform/android/android_widget_service.dart` | Android | Updates Android home screen widget counts and tasks |
| `lib/platform/android/android_floating_service.dart` | Android | Controls Android overlay bubble and permissions |
| `lib/platform/android/android_installer_service.dart` | Android | Triggers Android package installer for downloaded APKs |
| `lib/platform/windows/windows_window_service.dart` | Windows | Win32 window modes (normal, bubble, panel), topmost, drag |
| `lib/platform/windows/windows_update_service.dart` | Windows | Silent Win32 update execution (zero console window) |
| `lib/platform/windows/windows_settings_service.dart` | Windows | Direct Win32 `ShellExecuteW` ms-settings launcher |
| `lib/platform/windows/windows_startup_service.dart` | Windows | Win32 registry autorun configuration |
| `lib/platform/windows/windows_tray_service.dart` | Windows | Win32 system tray notification area icon |

---

## 4. In-App Resumable Update System (`lib/features/update/`)

- **HTTP 206 Partial Content Resumption**: When network drops mid-download, the client requests `Range: bytes=<downloaded>-` to resume instead of restarting from 0%.
- **Auto-Retry with Backoff**: Automatically attempts up to 5 progressive retries on socket disconnects without discarding downloaded bytes.
- **Fail-Safe UI**: If network drops permanently, user has one-click "Retry Download" (resumes instantly) and "Open in Browser" options.
