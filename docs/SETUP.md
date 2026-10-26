# Setup (Windows-oriented; Android Studio IDE not required, Android SDK is)

## 1. Install toolchain
- Flutter SDK (stable) and add to PATH
- JDK 17
- Android SDK: easiest via Android Studio's SDK Manager (use it only for SDK + emulator). Manual option: command-line tools + `sdkmanager "platform-tools" "platforms;android-34" "build-tools;34.0.0"`
- Visual Studio with the **Desktop development with C++** workload (for Windows builds)
- Git
- Run `flutter doctor` and fix everything it flags; `flutter doctor --android-licenses`

## 2. Open the project in Antigravity
Open this folder. Make sure the agent reads `AGENTS.md` first.

## 3. Generate platform folders (first run only)
```
git init && git add -A && git commit -m "Scaffold"
flutter create --platforms=android,windows --project-name synctask --org com.synctask .
```
`flutter create` may overwrite `lib/main.dart`, `pubspec.yaml` or add `test/widget_test.dart`.
If so: `git checkout -- lib/main.dart pubspec.yaml` and delete `test/widget_test.dart`
(it references the default counter app and will fail).

## 4. Verify
```
flutter pub get
flutter analyze
flutter test
flutter run -d windows        # or: flutter run -d <android-device-id>
```
Android: enable Developer options + USB debugging on a real phone, or create an emulator.

## 5. Fix-forward loop
Paste the exact error output to the agent. Fix `analyze`/`test`/build errors before adding features.
