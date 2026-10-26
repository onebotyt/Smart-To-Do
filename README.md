<p align="center">
  <img src="assets/logo.png" width="128" height="128" alt="SyncTask Logo" />
</p>

<h1 align="center">SyncTask (Smart-To-Do)</h1>

<p align="center">
  <strong>Native, cross-platform, local-first task manager with direct device-to-device sync.</strong><br>
  <em>No cloud backend. No mandatory accounts. Full user data ownership.</em>
</p>

<p align="center">
  <a href="https://github.com/onebotyt/Smart-To-Do/releases/latest"><img src="https://img.shields.io/github/v/release/onebotyt/Smart-To-Do?label=Latest%20Release&color=indigo" alt="Latest Release" /></a>
  <a href="https://github.com/onebotyt/Smart-To-Do/actions"><img src="https://img.shields.io/github/actions/workflow/status/onebotyt/Smart-To-Do/build.yml?branch=main&label=Build%20Status" alt="Build Status" /></a>
  <img src="https://img.shields.io/badge/Tests-39%20Passing-brightgreen" alt="39 Passing Tests" />
  <img src="https://img.shields.io/badge/Platforms-Android%20%7C%20Windows-blue" alt="Supported Platforms" />
  <img src="https://img.shields.io/badge/License-MIT-green" alt="License" />
</p>

---

## 🚀 Direct One-Click Downloads

Download the latest builds directly with a single click below:

| Platform | Architecture / Format | Direct Download Link | Optimized Size |
| :--- | :--- | :--- | :--- |
| 📱 **Android (Recommended)** | `arm64-v8a` (All modern Android phones) | [📥 **Download Android APK (arm64)**](https://github.com/onebotyt/Smart-To-Do/releases/latest/download/SyncTask-Android-arm64.apk) | **~20.4 MB** (87% smaller) |
| 📱 **Android (Universal)** | Multi-ABI (Works on any Android device) | [📥 **Download Universal APK**](https://github.com/onebotyt/Smart-To-Do/releases/latest/download/SyncTask-Android.apk) | ~57 MB |
| 💻 **Windows** | Portable `.zip` executable package | [📥 **Download Windows Desktop (.zip)**](https://github.com/onebotyt/Smart-To-Do/releases/latest/download/SyncTask-Windows.zip) | Portable Bundle |

> 💡 *View all release history, release notes, and version archives on the [GitHub Releases Page](https://github.com/onebotyt/Smart-To-Do/releases).*

---

## ✨ Features

### 🔄 Phone–PC Direct Synchronization (Zero Cloud)
- **Direct Device-to-Device**: Syncs directly between phone and computer over your local Wi-Fi network without third-party servers, Firebase, or external accounts.
- **LAN Discovery**: Automatically discovers nearby SyncTask devices via UDP broadcast on port `43884`.
- **6-Digit Confirmation PIN Pairing**: Secure mutual authentication ensures only explicitly trusted devices can connect.
- **Smart Delta & Conflict Resolution**: Uses composite version vectors (`${revision}:${deviceId}`) to detect concurrent edits, and resolves conflicts using a 3-way merge and Last-Write-Wins (LWW) with deterministic tie-breaking.
- **Soft-Deletion Tombstones**: Deletions propagate across all paired devices before being safely purged.

### 📌 Floating Task Panel & Quick Entry
- **Compact Overlay**: Always-on-top desktop window or floating mobile overlay.
- **Instant Input**: Add tasks with priority selection in a single tap without opening the main window.
- **Interactive Checklist**: One-tap completion checkboxes, dynamic pending badge, and quick sync action.

### 📱 Android Native Home-Screen Widget
- **Live Home-Screen Widget**: Android native `AppWidgetProvider` displaying your active pending task count and top upcoming tasks directly on your launcher.
- **Automatic Background Refresh**: Updates automatically whenever tasks are added, modified, or completed.

### 📋 Universal Clipboard Sharing
- **Cross-Device Text Sharing**: Copy on your phone and paste on your PC (and vice versa) seamlessly.
- **Strict Opt-In & Pause Controls**: Disabled by default for privacy; includes instantaneous pause/resume toggle.
- **Loop Prevention & Deduplication**: Rolling 50-item cryptographic SHA-256 hash cache prevents bounce-back echo loops between devices.
- **Zero Logging Policy**: Strictly enforces that clipboard contents are never printed or saved to application logs.

### 🔒 Local-First SQLite Persistence
- **100% Offline Capable**: All data is stored in local SQLite databases (`AppDatabase` v3 schema).
- **Atomic Transactions**: Every task write atomically commits changes and monotonic `change_log` entries.
- **Categories, Priorities & Recurrence**: Organize with custom categories, priority flags, due dates, and daily/weekly recurring tasks.

### 🔄 In-App One-Click Updates
- Check for new GitHub releases directly inside the app and install updates with one tap from Settings.

---

## 🛠️ Technology Stack

- **Framework**: Flutter (Channel Stable) & Dart 3
- **Local Storage**: SQLite with `sqflite` & `sqflite_common_ffi`
- **Networking**: Direct TCP Sockets & UDP Broadcast (`dart:io`) with zero cloud dependencies
- **Security**: Cryptographic SHA-256 fingerprinting & PIN verification (`crypto`)
- **State Management**: `provider` + `ChangeNotifier`
- **CI/CD**: GitHub Actions compiling optimized Android APKs and Windows desktop releases with automated semantic versioning

---

## 🏃 Getting Started & Local Development

### Prerequisites
- [Flutter SDK](https://flutter.dev) (Stable)
- [Android Studio](https://developer.android.com/studio) / Android SDK (for Android builds)
- [Visual Studio](https://visualstudio.microsoft.com/) with C++ Desktop Workload (for local Windows builds)

### Run Locally
```bash
# Clone the repository
git clone https://github.com/onebotyt/Smart-To-Do.git
cd Smart-To-Do

# Get dependencies
flutter pub get

# Run static analysis (0 warnings / clean)
flutter analyze

# Run all 39 automated tests
flutter test

# Run on connected device or emulator
flutter run
```

---

## 🗺️ Roadmap & Milestones

- [x] **Milestone 1**: Foundation — SQLite repository, Material 3 UI, category chips, pending/completed toggle, widget tests.
- [x] **Milestone 2**: Reliable Local Data — v1 ➔ v2 schema migration, 3-way conflict resolution engine, tombstone purge, offline queue, in-app updates.
- [x] **Milestone 3**: Phone–PC Sync — UDP LAN discovery, 6-digit PIN mutual pairing, encrypted direct socket sync, revision tie-breaking.
- [x] **Milestone 4**: Native Productivity — Compact floating task panel, Android native home-screen widget (`AppWidgetProvider`), tray & startup services.
- [x] **Milestone 5**: Universal Clipboard — Encrypted bidirectional plain-text clipboard sync with loop prevention, pause controls, and zero logging.
- [x] **Milestone 6 / 7**: Packaging Optimization — AOT release split builds (87% APK size reduction), automated CI/CD releases.

---

## 📄 License
This project is open-source under the MIT License.
