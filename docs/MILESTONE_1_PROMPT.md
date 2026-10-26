# Prompt to paste into Antigravity (Milestone 1)

Read AGENTS.md and every file in docs/. We are on Milestone 1.

Tasks, in order:
1. Follow docs/SETUP.md step 3 to generate the android and windows folders without losing the existing lib/ code (use git to restore overwritten files; delete the default test/widget_test.dart).
2. Run `flutter pub get`, `flutter analyze`, `flutter test`. The existing code has never been compiled — fix all errors and warnings, preferring minimal changes that keep the architecture (repository layer, change_log invariant, provider state).
3. Check deprecated API usage (for example DropdownButtonFormField `value`) against the installed Flutter version and update.
4. Run the app on Windows (`flutter run -d windows`) and, if a device/emulator is available, Android. Report what you could and could not verify.
5. Add: category filter chips on the task list, a Pending/Completed toggle, and a widget test for creating a task.
6. Add docs/KNOWN_LIMITATIONS.md listing anything unfinished or untested.

Constraints: explain any architectural change before making it; no web target; no cloud services;
no new dependencies without justification; commit after each numbered task.
Stop after Milestone 1 and summarize results. Do NOT start sync or native features.
