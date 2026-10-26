import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:synctask/platform/floating_panel_service.dart';
import 'package:synctask/platform/startup_service.dart';
import 'package:synctask/platform/tray_service.dart';
import 'package:synctask/platform/widget_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('FloatingPanelService', () {
    test('local visibility toggle and stream notifications', () async {
      final service = PlatformFloatingPanelService();
      addTearDown(() => service.dispose());

      expect(await service.isVisible(), isFalse);

      final events = <bool>[];
      final sub = service.onVisibilityChanged.listen(events.add);
      addTearDown(() => sub.cancel());

      await service.show();
      expect(await service.isVisible(), isTrue);

      await service.hide();
      expect(await service.isVisible(), isFalse);

      await service.toggle();
      expect(await service.isVisible(), isTrue);

      expect(events, [true, false, true]);
    });
  });

  group('StartupService', () {
    test('persists launch at startup preference', () async {
      SharedPreferences.setMockInitialValues({});
      final service = PlatformStartupService();

      expect(await service.isLaunchAtStartupEnabled(), isFalse);

      await service.setLaunchAtStartup(true);
      expect(await service.isLaunchAtStartupEnabled(), isTrue);

      await service.setLaunchAtStartup(false);
      expect(await service.isLaunchAtStartupEnabled(), isFalse);
    });
  });

  group('WidgetService', () {
    test('invokes update without crashing on supported/mock environment', () async {
      final service = PlatformWidgetService();
      await expectLater(
        service.updateWidget(
          pendingCount: 3,
          topTaskTitles: ['Task 1', 'Task 2', 'Task 3'],
        ),
        completes,
      );
    });
  });

  group('TrayService', () {
    test('lifecycle and tooltip set without crashing', () async {
      final service = PlatformTrayService();
      await expectLater(
        service.initTray(
          onToggle: () {},
          onExit: () {},
          onSync: () {},
        ),
        completes,
      );

      await expectLater(
        service.setTooltip('SyncTask - 5 pending'),
        completes,
      );

      await expectLater(
        service.dispose(),
        completes,
      );
    });
  });
}
