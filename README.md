<p align="center">
  <img src="assets/logo.png" width="128" height="128" alt="SyncTask Logo" />
</p>

<h1 align="center">SyncTask (Smart-To-Do)</h1>

<p align="center">
  <strong>Native, cross-platform, local-first task manager with direct device-to-device sync.</strong><br>
  <em>No cloud backend. No mandatory accounts. 100% user data ownership.</em>
</p>

<p align="center">
  <a href="https://github.com/onebotyt/Smart-To-Do/releases/latest"><img src="https://img.shields.io/github/v/release/onebotyt/Smart-To-Do?label=Latest%20Release&color=indigo" alt="Latest Release" /></a>
  <a href="https://github.com/onebotyt/Smart-To-Do/releases/tag/v0.1.29"><img src="https://img.shields.io/badge/Current%20Version-v0.1.29-blue" alt="Current Version v0.1.29" /></a>
  <a href="https://github.com/onebotyt/Smart-To-Do/actions"><img src="https://img.shields.io/github/actions/workflow/status/onebotyt/Smart-To-Do/build.yml?branch=main&label=Build%20Status" alt="Build Status" /></a>
  <img src="https://img.shields.io/badge/Tests-39%20Passing-brightgreen" alt="39 Passing Tests" />
  <img src="https://img.shields.io/badge/Platforms-Android%20%7C%20Windows-blue" alt="Supported Platforms" />
  <img src="https://img.shields.io/badge/License-MIT-green" alt="License" />
</p>

---

## 🚀 Direct One-Click Downloads (Latest Version: v0.1.29)

Always get the newest release directly with a single click below:

| Platform | Format / Architecture | Direct Download Link | Alternative Link | Notes |
| :--- | :--- | :--- | :--- | :--- |
| 💻 **Windows (Setup Installer)** | Official Setup `.exe` | [📥 **Download Windows Setup (v0.1.29)**](https://github.com/onebotyt/Smart-To-Do/releases/download/v0.1.29/SyncTask-Setup.exe) | [Latest Mirror](https://github.com/onebotyt/Smart-To-Do/releases/latest/download/SyncTask-Setup.exe) | Standard Windows Setup Wizard with Desktop & Start Menu Icons |
| 💻 **Windows (Portable ZIP)** | Portable Bundle + Script | [📥 **Download Windows ZIP (v0.1.29)**](https://github.com/onebotyt/Smart-To-Do/releases/download/v0.1.29/SyncTask-Windows.zip) | [Latest Mirror](https://github.com/onebotyt/Smart-To-Do/releases/latest/download/SyncTask-Windows.zip) | Portable archive with `Install-SyncTask.cmd` script |
| 📱 **Android (Recommended)** | `arm64-v8a` APK | [📥 **Download Android APK (v0.1.29)**](https://github.com/onebotyt/Smart-To-Do/releases/download/v0.1.29/SyncTask-Android-arm64.apk) | [Latest Mirror](https://github.com/onebotyt/Smart-To-Do/releases/latest/download/SyncTask-Android-arm64.apk) | Optimized for modern phones (~28 MB) |
| 📱 **Android (Universal)** | Multi-ABI APK | [📥 **Download Universal APK (v0.1.29)**](https://github.com/onebotyt/Smart-To-Do/releases/download/v0.1.29/SyncTask-Android.apk) | [Latest Mirror](https://github.com/onebotyt/Smart-To-Do/releases/latest/download/SyncTask-Android.apk) | Compatible with all Android devices |

> 📦 *View full changelogs and historical archives on the [GitHub Releases Page](https://github.com/onebotyt/Smart-To-Do/releases).*
> 
> ℹ️ *Note for Android: Because v0.1.29 introduces our permanent cryptographic signing certificate, uninstall any older test version once before installing this build. All future updates will install seamlessly over this release!*

---

## 💻 Installation Instructions

### 🖥️ Windows
**Option 1: Setup Installer (Easiest)**
1. Download [**SyncTask-Setup.exe**](https://github.com/onebotyt/Smart-To-Do/releases/latest/download/SyncTask-Setup.exe).
2. Double-click the downloaded setup file.
3. Follow the standard Windows Setup Wizard.
4. SyncTask will be installed with its official icon on your **Desktop**, **Start Menu Programs**, and Windows **Installed Apps**, and launch automatically!

**Option 2: Portable ZIP Package**
1. Download [**SyncTask-Windows.zip**](https://github.com/onebotyt/Smart-To-Do/releases/latest/download/SyncTask-Windows.zip).
2. Right-click and choose **Extract All...**.
3. Inside the extracted folder, double-click **`Install-SyncTask.cmd`** to automatically set up shortcuts and register the app.

### 📱 Android
1. Download [**SyncTask-Android-arm64.apk**](https://github.com/onebotyt/Smart-To-Do/releases/latest/download/SyncTask-Android-arm64.apk) directly on your device.
2. Tap the downloaded notification to open the package installer.
3. If prompted, allow installation from this source.
4. Tap **Install** or **Update**.

### 🔄 In-App Automatic Updates
SyncTask automatically checks for newer versions on startup:
- An **"Update Available"** banner appears right at the top of your task list whenever a newer release is published.
- Tap **Update Now** to watch live download progress with animated byte indicators.
- **On Android**: Automatically opens the system installer dialog.
- **On Windows**: Automatically extracts and updates files seamlessly.

---

## ✨ Features & Highlights

### 📝 Modern Note-First Task Creator
- **Unified Note Entry**: No more rigid, separate "Title" and "Notes" boxes. Write naturally in a single, spacious note area.
- **Smart Title Extraction**: The first line automatically acts as the concise task summary for widget and notification previews, keeping 100% backward compatibility with sync and SQLite.
- **Clean Quick Controls**: Priority chips, due dates, daily/weekly recurrence, and category tags.

### 🎨 8 Vibrant Color Themes + AMOLED True Black
- Customize the app to match your personal style in **Settings**:
  - 🟣 **Indigo** (Default)
  - 🔵 **Ocean Blue**
  - 🩵 **Teal**
  - 🟢 **Emerald Green**
  - 🟠 **Sunset Amber**
  - 🔮 **Royal Purple**
  - 🌸 **Rose**
  - 🔘 **Slate**
- **AMOLED Dark Mode**: True `#000000` pitch black background for OLED/AMOLED screens, maximizing battery life and contrast.

### 🫧 Round Floating Screen Bubble & Quick Panel
- Draggable round floating bubble with the SyncTask app logo and pending task count badge.
- **Click the bubble** ➔ Expands with a smooth spring zoom (`Curves.easeOutBack`) into the compact `FloatingTaskPanel` to view, check off, or add tasks without interrupting your workflow.
- **Close or tap backdrop** ➔ Smoothly collapses back to the compact draggable bubble.

### 🌊 Fluid 60/120fps Animations & Transitions
- **Native Zoom Page Transitions**: Seamless page transitions across Windows and Android via `ZoomPageTransitionsBuilder` and `PredictiveBackPageTransitionsBuilder`.
- **Tactile Task Completion**: Subtle checkbox bounce, animated strikethrough transition, and soft card opacity fade.
- **Staggered Cascade List**: Tasks gracefully cascade into view with an index-based slide-and-fade animation.
- **`InkSparkle` Ripples**: Material 3 high-fidelity touch feedback.

### 🔄 Direct Phone–PC Synchronization (Zero Cloud)
- **Local Wi-Fi P2P**: Direct socket communication over LAN on port `43884`—no servers, Firebase, or external accounts.
- **LAN Discovery**: Discovers paired devices automatically using UDP broadcast.
- **6-Digit PIN Pairing**: Secure mutual authentication ensures only authorized devices connect.
- **3-Way Delta Conflict Resolver**: Version vectors track concurrent offline edits with Last-Write-Wins (LWW) and device tie-breaking.

### 📋 Universal Clipboard Sharing
- Copy text on your phone and immediately paste it on your PC (and vice-versa).
- Strict opt-in privacy, instant pause toggle, and SHA-256 rolling hash loop prevention. Zero logging policy.

### 📱 Android Native Home-Screen Widget
- Home-screen `AppWidgetProvider` displaying your pending task count and top upcoming tasks directly on your launcher.
- Updates automatically whenever tasks are added, modified, or completed.

### 🔒 100% Local-First SQLite Storage
- All data stays locally on your device in SQLite (`AppDatabase` v3 schema).
- Atomic repository commits ensure data safety and instant offline responsiveness.

---

## 🛠️ Technology Stack

- **Framework**: Flutter (Stable Channel) & Dart 3
- **Local Database**: SQLite via `sqflite` & `sqflite_common_ffi`
- **Networking**: Direct TCP Sockets & UDP Broadcast (`dart:io`) with zero cloud dependencies
- **Security**: Cryptographic SHA-256 hashing (`crypto`)
- **State Management**: `provider` + `ChangeNotifier`
- **CI/CD**: GitHub Actions automating multi-architecture AOT compilation and releases

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
- [x] **Milestone 6**: UI/UX Modernization & Theme Palette — Note-first task editor, 8 selectable color themes, AMOLED mode, responsive filters.
- [x] **Milestone 7**: Packaging & Installer — AOT split APKs (~20MB), Windows one-click desktop installer (`Install-SyncTask.cmd`), animated in-app updater.
- [x] **Milestone 8**: Fluid Animations & Transitions — 60/120fps page zoom transitions, spring morph floating bubble, tactile completion micro-interactions.

---

## 📄 License
This project is open-source under the MIT License.
