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
  <img src="https://img.shields.io/badge/Platforms-Android%20%7C%20Windows-blue" alt="Supported Platforms" />
  <img src="https://img.shields.io/badge/License-MIT-green" alt="License" />
</p>

---

## 🚀 Direct One-Click Downloads

You don't need to dig through GitHub Actions artifacts. Download the latest builds directly with a single click below:

| Platform | Format | Direct Download Link |
| :--- | :--- | :--- |
| 📱 **Android** | `.apk` (All architectures) | [📥 **Download Android APK**](https://github.com/onebotyt/Smart-To-Do/releases/latest/download/SyncTask-Android.apk) |
| 💻 **Windows** | `.zip` (Portable desktop app) | [📥 **Download Windows App (.zip)**](https://github.com/onebotyt/Smart-To-Do/releases/latest/download/SyncTask-Windows.zip) |

> 💡 *View all release history, release notes, and version archives on the [GitHub Releases Page](https://github.com/onebotyt/Smart-To-Do/releases).*

---

## ✨ Key Features

- **📱 Android & 💻 Windows Native**: High-performance Flutter codebase optimized with native Impeller graphics and custom platform adapters.
- **🔒 Local-First SQLite Persistence**: Every task is stored locally in SQLite (`AppDatabase` v2 schema). Operates 100% offline with zero cloud latency.
- **🔄 In-App One-Click Updates**: Check for new GitHub releases and update the app directly with one tap from Settings.
- **🏷️ Categories & Smart Filters**: Filter by category chips (e.g. Work, Personal) and toggle between All, Pending, and Completed tasks seamlessly.
- **⏰ Priorities & Due Dates**: Set priority flags (Low, Normal, High), due dates, and recurring schedules (Daily, Weekly).
- **🛡️ Conflict-Ready Synchronous Logging**: Atomic change tracking via `change_log` and `ConflictResolver` (3-way merge and Last-Write-Wins), laying the foundation for direct LAN synchronization.
- **🌓 Adaptive Theme**: Follows your system theme (Light or Dark) automatically with Material 3 styling.

---

## 🛠️ Technology Stack

- **Framework**: Flutter (Channel Stable) & Dart 3
- **Local Storage**: SQLite with `sqflite` & `sqflite_common_ffi`
- **State Management**: `provider` + `ChangeNotifier`
- **CI/CD**: GitHub Actions building Android APKs and Windows executables with automated semantic releases
- **Architecture**: Strict repository pattern with layered isolation: UI ➔ Controllers ➔ Repository ➔ SQLite / Platform Adapters

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

# Run static analysis
flutter analyze

# Run all 16 automated tests
flutter test

# Run on connected device or emulator
flutter run
```

---

## 🗺️ Roadmap & Milestones

- [x] **Milestone 1**: Foundation — SQLite repository, Material 3 UI, category chips, pending/completed toggle, widget tests.
- [x] **Milestone 2**: Reliable Local Data — v1 ➔ v2 schema migration, 3-way conflict resolution engine, tombstone purge, offline queue, in-app updates.
- [ ] **Milestone 3**: Phone–PC Sync — mDNS LAN discovery, mutual key exchange, encrypted direct socket sync.
- [ ] **Milestone 4**: Native Productivity — Windows system-tray + floating panel, Android floating overlay service.
- [ ] **Milestone 5**: Universal Clipboard — Encrypted bidirectional clipboard sync with loop prevention.
- [ ] **Milestone 6**: Native Home-Screen Widgets.

---

## 📄 License
This project is open-source under the MIT License.
