// SyncTask Platform Abstraction Layer
// Exports common, android, and windows native implementations.

// Common cross-platform services
export 'clipboard_service.dart';
export 'update_service.dart';
export 'common/native_network_service.dart';
export 'floating_panel_service.dart';
export 'native_media_service.dart';

// Android platform native services
export 'android/android_widget_service.dart';
export 'android/android_floating_service.dart';
export 'android/android_installer_service.dart';

// Windows platform native services
export 'windows/windows_window_service.dart';
export 'windows/windows_tray_service.dart';
export 'windows/windows_startup_service.dart';
export 'windows/windows_settings_service.dart';
export 'windows/windows_update_service.dart';
