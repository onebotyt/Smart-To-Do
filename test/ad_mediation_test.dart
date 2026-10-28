import 'package:flutter_test/flutter_test.dart';
import 'package:synctask/features/monetization/ad_mediation_controller.dart';

class FailingMockProvider implements BaseAdProvider {
  @override
  AdProviderType get type => AdProviderType.googleAdMob;

  @override
  Future<bool> initialize() async => true;

  @override
  Future<AdUnitPayload?> loadBannerAd() async {
    throw Exception('Simulated AdMob network failure / No-Fill');
  }
}

class SuccessfulMockProvider implements BaseAdProvider {
  final AdProviderType providerType;

  SuccessfulMockProvider(this.providerType);

  @override
  AdProviderType get type => providerType;

  @override
  Future<bool> initialize() async => true;

  @override
  Future<AdUnitPayload?> loadBannerAd() async {
    return AdUnitPayload(
      provider: providerType,
      title: 'Partner Offer',
      subtitle: 'Premium cloud storage',
      callToAction: 'Check out',
    );
  }
}

void main() {
  group('AdMediationController Multi-Network Tests', () {
    test('Default controller initializes with multi-network waterfall', () async {
      final controller = AdMediationController();
      expect(controller.isLoading, isTrue);

      // Wait for initial ad to load
      await Future.delayed(const Duration(milliseconds: 250));
      expect(controller.isLoading, isFalse);
      expect(controller.currentAd, isNotNull);
      expect(controller.currentProviderType, isNotNull);
    });

    test('Cascades to secondary provider when primary provider fails', () async {
      final failingProvider = FailingMockProvider();
      final secondaryProvider = SuccessfulMockProvider(AdProviderType.unityAds);
      final houseProvider = HouseSponsorProvider();

      final controller = AdMediationController(
        providers: [failingProvider, secondaryProvider, houseProvider],
      );

      await Future.delayed(const Duration(milliseconds: 100));
      expect(controller.isLoading, isFalse);
      expect(controller.currentAd, isNotNull);
      expect(controller.currentAd!.provider, AdProviderType.unityAds);
      expect(controller.currentAd!.title, 'Partner Offer');
    });

    test('Cascades to House Sponsor when all external networks fail', () async {
      final failing1 = FailingMockProvider();
      final failing2 = FailingMockProvider();
      final house = HouseSponsorProvider();

      final controller = AdMediationController(
        providers: [failing1, failing2, house],
      );

      await Future.delayed(const Duration(milliseconds: 100));
      expect(controller.currentAd, isNotNull);
      expect(controller.currentAd!.provider, AdProviderType.houseSponsor);
      expect(controller.currentAd!.title, contains('SyncTask'));
    });

    test('House sponsor rotates banners seamlessly', () async {
      final house = HouseSponsorProvider();
      final ad1 = await house.loadBannerAd();
      final ad2 = await house.loadBannerAd();

      expect(ad1, isNotNull);
      expect(ad2, isNotNull);
      expect(ad1!.title, isNot(ad2!.title));
    });
  });
}
