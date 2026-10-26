#include "flutter_window.h"

#include <optional>

#include "flutter/generated_plugin_registrant.h"

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  // The size here must match the window dimensions to avoid unnecessary surface
  // creation / destruction in the startup path.
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  // Ensure that basic setup of the controller was successful.
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());
  SetChildContent(flutter_controller_->view()->GetNativeWindow());

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
      SetWindowPos(hwnd, always_on_top ? HWND_TOPMOST : HWND_NOTOPMOST, 0, 0, 0, 0,
                   SWP_NOMOVE | SWP_NOSIZE);
      result->Success(flutter::EncodableValue(true));
    } else if (call.method_name() == "isAlwaysOnTop") {
      LONG_PTR exStyle = GetWindowLongPtr(hwnd, GWL_EXSTYLE);
      bool isTopmost = (exStyle & WS_EX_TOPMOST) != 0;
      result->Success(flutter::EncodableValue(isTopmost));
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
      if (const auto* args = std::get_if<flutter::EncodableMap>(call.arguments())) {
        auto it = args->find(flutter::EncodableValue("enabled"));
        if (it != args->end() && std::holds_alternative<bool>(it->second)) {
          enabled = std::get<bool>(it->second);
        }
      }
      if (RegOpenKeyExW(HKEY_CURRENT_USER, subKey, 0, KEY_SET_VALUE, &hKey) == ERROR_SUCCESS) {
        if (enabled) {
          wchar_t exePath[MAX_PATH];
          GetModuleFileNameW(nullptr, exePath, MAX_PATH);
          RegSetValueExW(hKey, L"SyncTask", 0, REG_SZ,
                         reinterpret_cast<const BYTE*>(exePath),
                         (lstrlenW(exePath) + 1) * sizeof(wchar_t));
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

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    this->Show();
  });

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::OnDestroy() {
  if (flutter_controller_) {
    window_channel_ = nullptr;
    startup_channel_ = nullptr;
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  // Give Flutter, including plugins, an opportunity to handle window messages.
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  switch (message) {
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
