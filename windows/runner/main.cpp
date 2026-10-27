#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>

#include "flutter_window.h"
#include "utils.h"

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  // Attach to console when present (e.g., 'flutter run') or create a
  // new console when running with a debugger.
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  // Initialize COM, so that it is available for use in the library and/or
  // plugins.
  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  flutter::DartProject project(L"data");

  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();

  bool start_as_bubble = false;
  for (const auto& arg : command_line_arguments) {
    if (arg == "--floating-bubble" || arg == "--bubble") {
      start_as_bubble = true;
      break;
    }
  }

  // Single-instance check:
  // If an instance of SyncTask is already running on the PC:
  HANDLE hMutex = ::CreateMutexW(nullptr, TRUE, L"SyncTask_Single_Instance_Mutex");
  if (::GetLastError() == ERROR_ALREADY_EXISTS) {
    HWND existing_hwnd = ::FindWindowW(L"FLUTTER_RUNNER_WIN32_WINDOW", L"synctask");
    if (!existing_hwnd) {
      existing_hwnd = ::FindWindowW(nullptr, L"synctask");
    }
    if (existing_hwnd && !start_as_bubble) {
      // User clicked SyncTask app icon: restore existing window to normal full mode!
      static const UINT WM_SYNCTASK_RESTORE =
          ::RegisterWindowMessageW(L"SyncTask_Restore_Window_Normal");
      ::PostMessageW(existing_hwnd, WM_SYNCTASK_RESTORE, 0, 0);
      ::ShowWindow(existing_hwnd, SW_RESTORE);
      ::SetForegroundWindow(existing_hwnd);
      ::BringWindowToTop(existing_hwnd);
    }
    if (hMutex) {
      ::CloseHandle(hMutex);
    }
    ::CoUninitialize();
    return EXIT_SUCCESS;
  }

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project);
  Win32Window::Point origin(10, 10);
  Win32Window::Size size(1280, 720);
  if (!window.Create(L"synctask", origin, size)) {
    if (hMutex) ::CloseHandle(hMutex);
    return EXIT_FAILURE;
  }
  window.SetQuitOnClose(true);

  if (start_as_bubble) {
    window.SetWindowMode("bubble");
  }

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  if (hMutex) {
    ::ReleaseMutex(hMutex);
    ::CloseHandle(hMutex);
  }

  ::CoUninitialize();
  return EXIT_SUCCESS;
}
