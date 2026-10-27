#include "flutter_window.h"

#include <optional>
#include <windows.h>
#include <dwmapi.h>
#include <shellapi.h>
#include <vector>

#include "flutter/generated_plugin_registrant.h"

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

void FlutterWindow::SetWindowMode(const std::string& mode) {
  HWND hwnd = this->GetHandle();
  if (!hwnd) return;

  HMONITOR monitor = MonitorFromWindow(hwnd, MONITOR_DEFAULTTONEAREST);
  MONITORINFO mi = { sizeof(mi) };
  GetMonitorInfo(monitor, &mi);
  RECT workArea = mi.rcWork;

  UINT dpi = FlutterDesktopGetDpiForMonitor(monitor);
  double scale = dpi / 96.0;

  if (mode == "bubble") {
    if (current_mode_ == "normal") {
      GetWindowRect(hwnd, &normal_rect_);
    }

    int bubbleSize = static_cast<int>(72 * scale);

    if (bubble_x_ < workArea.left || bubble_x_ + bubbleSize > workArea.right) {
      bubble_x_ = workArea.right - bubbleSize - static_cast<int>(24 * scale);
    }
    if (bubble_y_ < workArea.top || bubble_y_ + bubbleSize > workArea.bottom) {
      bubble_y_ = workArea.bottom - bubbleSize - static_cast<int>(60 * scale);
    }

    // Set borderless popup style and topmost
    SetWindowLongPtr(hwnd, GWL_STYLE, WS_POPUP | WS_VISIBLE);
    SetWindowLongPtr(hwnd, GWL_EXSTYLE, WS_EX_TOPMOST | WS_EX_TOOLWINDOW);

    SetWindowPos(hwnd, HWND_TOPMOST, bubble_x_, bubble_y_, bubbleSize, bubbleSize,
                 SWP_FRAMECHANGED | SWP_SHOWWINDOW);

    // Circular region mask: outside corners are 100% transparent and pass-through
    HRGN rgn = CreateEllipticRgn(0, 0, bubbleSize, bubbleSize);
    SetWindowRgn(hwnd, rgn, TRUE);

    current_mode_ = "bubble";
  } else if (mode == "panel") {
    if (current_mode_ == "normal") {
      GetWindowRect(hwnd, &normal_rect_);
    }

    int panelWidth = static_cast<int>(360 * scale);
    int panelHeight = static_cast<int>(500 * scale);

    int px = bubble_x_;
    int py = bubble_y_;

    if (px < 0) {
      px = workArea.right - panelWidth - static_cast<int>(24 * scale);
    }
    if (py < 0) {
      py = workArea.bottom - panelHeight - static_cast<int>(60 * scale);
    }

    // Clamp inside screen bounds so panel NEVER clips or goes off-screen
    if (px + panelWidth > workArea.right) {
      px = workArea.right - panelWidth - static_cast<int>(12 * scale);
    }
    if (px < workArea.left) {
      px = workArea.left + static_cast<int>(12 * scale);
    }

    if (py + panelHeight > workArea.bottom) {
      py = workArea.bottom - panelHeight - static_cast<int>(12 * scale);
    }
    if (py < workArea.top) {
      py = workArea.top + static_cast<int>(12 * scale);
    }

    SetWindowLongPtr(hwnd, GWL_STYLE, WS_POPUP | WS_VISIBLE);
    LONG_PTR panelEx = WS_EX_TOOLWINDOW;
    if (is_always_on_top_) {
      panelEx |= WS_EX_TOPMOST;
    }
    SetWindowLongPtr(hwnd, GWL_EXSTYLE, panelEx);

    SetWindowPos(hwnd, is_always_on_top_ ? HWND_TOPMOST : HWND_NOTOPMOST, px, py, panelWidth, panelHeight,
                 SWP_FRAMECHANGED | SWP_SHOWWINDOW);

    // Rounded rectangle region mask (radius 24)
    int radius = static_cast<int>(24 * scale);
    HRGN rgn = CreateRoundRectRgn(0, 0, panelWidth, panelHeight, radius, radius);
    SetWindowRgn(hwnd, rgn, TRUE);

    current_mode_ = "panel";
  } else {
    // "normal" mode
    SetWindowRgn(hwnd, nullptr, TRUE);

    LONG_PTR normalEx = GetWindowLongPtr(hwnd, GWL_EXSTYLE);
    normalEx &= ~WS_EX_TOPMOST;
    normalEx &= ~WS_EX_TOOLWINDOW;
    normalEx |= WS_EX_APPWINDOW;
    SetWindowLongPtr(hwnd, GWL_EXSTYLE, normalEx);
    SetWindowLongPtr(hwnd, GWL_STYLE, WS_OVERLAPPEDWINDOW | WS_VISIBLE);

    int nw = normal_rect_.right - normal_rect_.left;
    int nh = normal_rect_.bottom - normal_rect_.top;
    int nx = normal_rect_.left;
    int ny = normal_rect_.top;

    if (nw < static_cast<int>(600 * scale) || nh < static_cast<int>(400 * scale)) {
      nw = static_cast<int>(1024 * scale);
      nh = static_cast<int>(720 * scale);
      nx = workArea.left + (workArea.right - workArea.left - nw) / 2;
      ny = workArea.top + (workArea.bottom - workArea.top - nh) / 2;
    }

    if (nx + nw > workArea.right) nx = workArea.right - nw;
    if (nx < workArea.left) nx = workArea.left;
    if (ny + nh > workArea.bottom) ny = workArea.bottom - nh;
    if (ny < workArea.top) ny = workArea.top;

    SetWindowPos(hwnd, HWND_NOTOPMOST,
                 nx, ny, nw, nh, SWP_FRAMECHANGED | SWP_SHOWWINDOW);

    ShowWindow(hwnd, SW_RESTORE);
    SetForegroundWindow(hwnd);
    BringWindowToTop(hwnd);

    current_mode_ = "normal";
  }

  if (window_channel_) {
    window_channel_->InvokeMethod(
        "onWindowModeChanged",
        std::make_unique<flutter::EncodableValue>(flutter::EncodableMap{
            {flutter::EncodableValue("mode"),
             flutter::EncodableValue(current_mode_)}}));
  }
}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());
  SetChildContent(flutter_controller_->view()->GetNativeWindow());
  RegisterApplicationRestart(L"", 0);

  // Window Management Channel
  window_channel_ =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          flutter_controller_->engine()->messenger(), "com.synctask/window",
          &flutter::StandardMethodCodec::GetInstance());

  window_channel_->SetMethodCallHandler([this](const auto& call, auto result) {
    HWND hwnd = this->GetHandle();
    if (!hwnd) {
      result->Error("NO_WINDOW", "HWND is null");
      return;
    }
    if (call.method_name() == "setAlwaysOnTop") {
      bool always_on_top = true;
      if (const auto* args = std::get_if<flutter::EncodableMap>(call.arguments())) {
        auto it = args->find(flutter::EncodableValue("alwaysOnTop"));
        if (it != args->end() && std::holds_alternative<bool>(it->second)) {
          always_on_top = std::get<bool>(it->second);
        }
      }
      is_always_on_top_ = always_on_top;
      // Topmost only applies to floating panel and bubble, never to normal app window
      if (current_mode_ != "normal") {
        LONG_PTR exStyle = GetWindowLongPtr(hwnd, GWL_EXSTYLE);
        if (always_on_top) {
          exStyle |= WS_EX_TOPMOST;
        } else {
          exStyle &= ~WS_EX_TOPMOST;
        }
        SetWindowLongPtr(hwnd, GWL_EXSTYLE, exStyle);
        SetWindowPos(hwnd, always_on_top ? HWND_TOPMOST : HWND_NOTOPMOST, 0, 0, 0, 0,
                     SWP_NOMOVE | SWP_NOSIZE | SWP_NOACTIVATE | SWP_FRAMECHANGED);
      } else {
        // Enforce HWND_NOTOPMOST for normal mode
        LONG_PTR exStyle = GetWindowLongPtr(hwnd, GWL_EXSTYLE);
        exStyle &= ~WS_EX_TOPMOST;
        SetWindowLongPtr(hwnd, GWL_EXSTYLE, exStyle);
        SetWindowPos(hwnd, HWND_NOTOPMOST, 0, 0, 0, 0,
                     SWP_NOMOVE | SWP_NOSIZE | SWP_NOACTIVATE | SWP_FRAMECHANGED);
      }
      result->Success(flutter::EncodableValue(true));
    } else if (call.method_name() == "isAlwaysOnTop") {
      LONG_PTR exStyle = GetWindowLongPtr(hwnd, GWL_EXSTYLE);
      bool isTopmost = (exStyle & WS_EX_TOPMOST) != 0;
      result->Success(flutter::EncodableValue(isTopmost));
    } else if (call.method_name() == "setWindowMode") {
      std::string mode = "normal";
      if (const auto* args = std::get_if<flutter::EncodableMap>(call.arguments())) {
        auto it = args->find(flutter::EncodableValue("mode"));
        if (it != args->end() && std::holds_alternative<std::string>(it->second)) {
          mode = std::get<std::string>(it->second);
        }
      }
      this->SetWindowMode(mode);
      result->Success(flutter::EncodableValue(current_mode_));
    } else if (call.method_name() == "getWindowMode") {
      result->Success(flutter::EncodableValue(current_mode_));
    } else if (call.method_name() == "moveWindow") {
      double dx = 0.0;
      double dy = 0.0;
      if (const auto* args = std::get_if<flutter::EncodableMap>(call.arguments())) {
        auto itX = args->find(flutter::EncodableValue("dx"));
        if (itX != args->end()) {
          if (std::holds_alternative<double>(itX->second)) dx = std::get<double>(itX->second);
          else if (std::holds_alternative<int32_t>(itX->second)) dx = std::get<int32_t>(itX->second);
          else if (std::holds_alternative<int64_t>(itX->second)) dx = static_cast<double>(std::get<int64_t>(itX->second));
        }
        auto itY = args->find(flutter::EncodableValue("dy"));
        if (itY != args->end()) {
          if (std::holds_alternative<double>(itY->second)) dy = std::get<double>(itY->second);
          else if (std::holds_alternative<int32_t>(itY->second)) dy = std::get<int32_t>(itY->second);
          else if (std::holds_alternative<int64_t>(itY->second)) dy = static_cast<double>(std::get<int64_t>(itY->second));
        }
      }

      RECT rect;
      GetWindowRect(hwnd, &rect);
      HMONITOR monitor = MonitorFromWindow(hwnd, MONITOR_DEFAULTTONEAREST);
      MONITORINFO mi = { sizeof(mi) };
      GetMonitorInfo(monitor, &mi);
      RECT workArea = mi.rcWork;

      UINT dpi = FlutterDesktopGetDpiForMonitor(monitor);
      double scale = dpi / 96.0;

      int newX = rect.left + static_cast<int>(dx * scale);
      int newY = rect.top + static_cast<int>(dy * scale);
      int w = rect.right - rect.left;
      int h = rect.bottom - rect.top;

      if (newX < workArea.left) newX = workArea.left;
      if (newX + w > workArea.right) newX = workArea.right - w;
      if (newY < workArea.top) newY = workArea.top;
      if (newY + h > workArea.bottom) newY = workArea.bottom - h;

      SetWindowPos(hwnd, nullptr, newX, newY, 0, 0, SWP_NOSIZE | SWP_NOZORDER | SWP_NOACTIVATE);

      if (current_mode_ == "bubble") {
        bubble_x_ = newX;
        bubble_y_ = newY;
      }

      result->Success(flutter::EncodableValue(true));
    } else if (call.method_name() == "startDragging") {
      ReleaseCapture();
      SendMessage(hwnd, WM_NCLBUTTONDOWN, HTCAPTION, 0);
      RECT rect;
      GetWindowRect(hwnd, &rect);
      bubble_x_ = rect.left;
      bubble_y_ = rect.top;
      result->Success(flutter::EncodableValue(true));
    } else if (call.method_name() == "exitApp") {
      close_to_bubble_ = false;
      DestroyWindow(hwnd);
      PostQuitMessage(0);
      result->Success(flutter::EncodableValue(true));
    } else if (call.method_name() == "setCloseToBubble") {
      bool enabled = true;
      if (const auto* args = std::get_if<flutter::EncodableMap>(call.arguments())) {
        auto it = args->find(flutter::EncodableValue("enabled"));
        if (it != args->end() && std::holds_alternative<bool>(it->second)) {
          enabled = std::get<bool>(it->second);
        }
      }
      close_to_bubble_ = enabled;
      result->Success(flutter::EncodableValue(true));
    } else {
      result->NotImplemented();
    }
  });

  // Windows Startup Channel
  startup_channel_ =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          flutter_controller_->engine()->messenger(), "com.synctask/startup",
          &flutter::StandardMethodCodec::GetInstance());

  startup_channel_->SetMethodCallHandler([](const auto& call, auto result) {
    HKEY hKey;
    const wchar_t* subKey = L"Software\\Microsoft\\Windows\\CurrentVersion\\Run";

    if (call.method_name() == "isEnabled") {
      if (RegOpenKeyExW(HKEY_CURRENT_USER, subKey, 0, KEY_READ, &hKey) == ERROR_SUCCESS) {
        DWORD type;
        DWORD size = 0;
        LONG res = RegQueryValueExW(hKey, L"SyncTask", nullptr, &type, nullptr, &size);
        RegCloseKey(hKey);
        result->Success(flutter::EncodableValue(res == ERROR_SUCCESS));
        return;
      }
      result->Success(flutter::EncodableValue(false));
    } else if (call.method_name() == "setEnabled") {
      bool enabled = false;
      bool bubble_mode = false;
      if (const auto* args = std::get_if<flutter::EncodableMap>(call.arguments())) {
        auto it = args->find(flutter::EncodableValue("enabled"));
        if (it != args->end() && std::holds_alternative<bool>(it->second)) {
          enabled = std::get<bool>(it->second);
        }
        auto itB = args->find(flutter::EncodableValue("bubbleMode"));
        if (itB != args->end() && std::holds_alternative<bool>(itB->second)) {
          bubble_mode = std::get<bool>(itB->second);
        }
      }
      if (RegOpenKeyExW(HKEY_CURRENT_USER, subKey, 0, KEY_SET_VALUE, &hKey) == ERROR_SUCCESS) {
        if (enabled) {
          wchar_t exePath[MAX_PATH];
          GetModuleFileNameW(nullptr, exePath, MAX_PATH);
          std::wstring cmd = L"\"" + std::wstring(exePath) + L"\"";
          if (bubble_mode) {
            cmd += L" --floating-bubble";
          }
          RegSetValueExW(hKey, L"SyncTask", 0, REG_SZ,
                         reinterpret_cast<const BYTE*>(cmd.c_str()),
                         static_cast<DWORD>((cmd.length() + 1) * sizeof(wchar_t)));
        } else {
          RegDeleteValueW(hKey, L"SyncTask");
        }
        RegCloseKey(hKey);
      }
      result->Success(flutter::EncodableValue(true));
    } else {
      result->NotImplemented();
    }
  });

  // Native Win32 Update Channel (Silent installer with zero cmd.exe window)
  update_channel_ =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          flutter_controller_->engine()->messenger(), "com.synctask/native_update",
          &flutter::StandardMethodCodec::GetInstance());

  update_channel_->SetMethodCallHandler([this](const auto& call, auto result) {
    if (call.method_name() == "installUpdate") {
      std::string installer_path;
      bool is_zip = false;
      if (const auto* args = std::get_if<flutter::EncodableMap>(call.arguments())) {
        auto itPath = args->find(flutter::EncodableValue("installerPath"));
        if (itPath != args->end() && std::holds_alternative<std::string>(itPath->second)) {
          installer_path = std::get<std::string>(itPath->second);
        }
        auto itZip = args->find(flutter::EncodableValue("isZip"));
        if (itZip != args->end() && std::holds_alternative<bool>(itZip->second)) {
          is_zip = std::get<bool>(itZip->second);
        }
      }

      if (installer_path.empty()) {
        result->Error("BAD_ARGS", "Missing installerPath");
        return;
      }

      int len = MultiByteToWideChar(CP_UTF8, 0, installer_path.c_str(), -1, nullptr, 0);
      std::wstring wInstallerPath(len, 0);
      MultiByteToWideChar(CP_UTF8, 0, installer_path.c_str(), -1, &wInstallerPath[0], len);
      if (!wInstallerPath.empty() && wInstallerPath.back() == L'\0') {
        wInstallerPath.pop_back();
      }

      if (!is_zip) {
        // Official Inno Setup installer execution: completely silent, no console window
        SHELLEXECUTEINFOW sei = { sizeof(sei) };
        sei.cbSize = sizeof(sei);
        sei.fMask = SEE_MASK_NOZONECHECKS;
        sei.lpVerb = L"open";
        sei.lpFile = wInstallerPath.c_str();
        sei.lpParameters = L"/SILENT /SP- /SUPPRESSMSGBOXES /FORCECLOSEAPPLICATIONS /RESTARTAPPLICATIONS";
        sei.nShow = SW_SHOWNORMAL;

        if (ShellExecuteExW(&sei)) {
          result->Success(flutter::EncodableValue(true));
          HWND hwnd = this->GetHandle();
          if (hwnd) {
            DestroyWindow(hwnd);
          }
          PostQuitMessage(0);
          return;
        } else {
          DWORD err = GetLastError();
          result->Error("INSTALL_FAILED", "ShellExecuteExW failed: " + std::to_string(err));
          return;
        }
      } else {
        wchar_t currentExe[MAX_PATH];
        GetModuleFileNameW(nullptr, currentExe, MAX_PATH);
        std::wstring exeDir = currentExe;
        size_t lastSlash = exeDir.find_last_of(L"\\/");
        if (lastSlash != std::wstring::npos) {
          exeDir = exeDir.substr(0, lastSlash);
        }

        std::wstring cmd = L"powershell.exe -NoProfile -NonInteractive -WindowStyle Hidden -Command \"Start-Sleep -Seconds 1; Expand-Archive -Path '" +
                           wInstallerPath + L"' -DestinationPath '" + exeDir + L"' -Force; Start-Process '" + currentExe + L"'\"";

        STARTUPINFOW si = { sizeof(si) };
        si.cbSize = sizeof(si);
        si.dwFlags = STARTF_USESHOWWINDOW;
        si.wShowWindow = SW_HIDE;
        PROCESS_INFORMATION pi = { 0 };

        std::vector<wchar_t> cmdBuf(cmd.begin(), cmd.end());
        cmdBuf.push_back(0);

        if (CreateProcessW(nullptr, cmdBuf.data(), nullptr, nullptr, FALSE,
                           CREATE_NO_WINDOW, nullptr, nullptr, &si, &pi)) {
          CloseHandle(pi.hProcess);
          CloseHandle(pi.hThread);
          result->Success(flutter::EncodableValue(true));
          HWND hwnd = this->GetHandle();
          if (hwnd) {
            DestroyWindow(hwnd);
          }
          PostQuitMessage(0);
          return;
        } else {
          result->Error("EXTRACT_FAILED", "CreateProcessW failed");
          return;
        }
      }
    } else {
      result->NotImplemented();
    }
  });

  // Native Win32 Settings Channel (Bluetooth, Wi-Fi, Hotspot)
  settings_channel_ =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          flutter_controller_->engine()->messenger(), "com.synctask/native_settings",
          &flutter::StandardMethodCodec::GetInstance());

  settings_channel_->SetMethodCallHandler([](const auto& call, auto result) {
    if (call.method_name() == "openBluetoothSettings") {
      ShellExecuteW(nullptr, L"open", L"ms-settings:bluetooth", nullptr, nullptr, SW_SHOWNORMAL);
      result->Success(flutter::EncodableValue(true));
    } else if (call.method_name() == "openWifiSettings") {
      ShellExecuteW(nullptr, L"open", L"ms-settings:network-wifi", nullptr, nullptr, SW_SHOWNORMAL);
      result->Success(flutter::EncodableValue(true));
    } else if (call.method_name() == "openHotspotSettings") {
      ShellExecuteW(nullptr, L"open", L"ms-settings:network-mobilehotspot", nullptr, nullptr, SW_SHOWNORMAL);
      result->Success(flutter::EncodableValue(true));
    } else if (call.method_name() == "isBluetoothEnabled") {
      result->Success(flutter::EncodableValue(true));
    } else {
      result->NotImplemented();
    }
  });

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    this->Show();
  });

  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::OnDestroy() {
  if (flutter_controller_) {
    window_channel_ = nullptr;
    startup_channel_ = nullptr;
    update_channel_ = nullptr;
    settings_channel_ = nullptr;
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  static const UINT WM_SYNCTASK_RESTORE =
      ::RegisterWindowMessageW(L"SyncTask_Restore_Window_Normal");
  if (message == WM_SYNCTASK_RESTORE) {
    SetWindowMode("normal");
    ShowWindow(hwnd, SW_RESTORE);
    SetForegroundWindow(hwnd);
    BringWindowToTop(hwnd);
    return 0;
  }

  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  switch (message) {
    case WM_CLOSE: {
      if (close_to_bubble_) {
        SetWindowMode("bubble");
        return 0;
      }
      break;
    }
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
