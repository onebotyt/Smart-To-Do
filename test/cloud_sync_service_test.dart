import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:synctask/data/services/cloud_sync_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CloudSyncService Unit Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('Initial state is unauthenticated and non-premium by default', () async {
      final service = CloudSyncService();
      await Future.delayed(const Duration(milliseconds: 50));

      expect(service.isAuthenticated, isFalse);
      expect(service.isPremium, isFalse);
      expect(service.jwtToken, isNull);
      expect(service.currentUser, isNull);
      expect(service.backendUrl, CloudSyncService.defaultBackendUrl);
    });

    test('Updating backend URL persists to SharedPreferences', () async {
      final service = CloudSyncService();
      await Future.delayed(const Duration(milliseconds: 50));

      await service.setBackendUrl('https://custom-todo.onrender.com/');
      expect(service.backendUrl, 'https://custom-todo.onrender.com');

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('synctask_backend_url'), 'https://custom-todo.onrender.com');
    });

    test('Activating ad-free plan enables isPremium and persists to storage', () async {
      final service = CloudSyncService();
      await Future.delayed(const Duration(milliseconds: 50));

      expect(service.isPremium, isFalse);

      final success = await service.activateAdFreePlan(purchaseToken: 'gplay_token_test_123');
      expect(success, isTrue);
      expect(service.isPremium, isTrue);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('synctask_is_premium'), isTrue);
    });

    test('Sign out clears user and auth token', () async {
      final service = CloudSyncService();
      await Future.delayed(const Duration(milliseconds: 50));

      // Simulate sign in state
      await service.signInWithGoogle(
        idToken: 'mock_token',
        email: 'test@example.com',
        displayName: 'Test User',
      );

      await service.signOut();

      expect(service.isAuthenticated, isFalse);
      expect(service.currentUser, isNull);
      expect(service.jwtToken, isNull);
    });
  });
}
