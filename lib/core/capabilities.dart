import 'dart:io';

/// Feature capability check. Settings screens use this to show when an
/// option is unsupported on the current OS. Update as native adapters land.
class Capabilities {
  static bool get floatingPanel => Platform.isAndroid || Platform.isWindows;
  static bool get homeWidgets => Platform.isAndroid; // iOS WidgetKit later
  static bool get clipboardSync => Platform.isAndroid || Platform.isWindows;
  static bool get launchAtStartup => Platform.isWindows;
}
