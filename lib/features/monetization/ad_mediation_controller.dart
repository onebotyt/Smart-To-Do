import 'dart:async';
import 'package:flutter/foundation.dart';

/// Supported Ad Network Providers
enum AdProviderType {
  googleAdMob,
  unityAds,
  appLovin,
  houseSponsor,
}

/// Metadata representation for an active ad unit
class AdUnitPayload {
  final AdProviderType provider;
  final String title;
  final String subtitle;
  final String callToAction;
  final String? clickUrl;
  final String? iconUrl;

  const AdUnitPayload({
    required this.provider,
    required this.title,
    required this.subtitle,
    required this.callToAction,
    this.clickUrl,
    this.iconUrl,
  });
}

/// Interface for individual ad providers in the mediation waterfall
abstract class BaseAdProvider {
  AdProviderType get type;
  Future<bool> initialize();
  Future<AdUnitPayload?> loadBannerAd();
}

/// Google AdMob Provider (Primary Mobile Network)
class GoogleAdMobProvider implements BaseAdProvider {
  final String appId;
  final String bannerUnitId;
  bool _initialized = false;

  GoogleAdMobProvider({
    this.appId = 'ca-app-pub-3940256099942544~3347511713', // Google Test ID
    this.bannerUnitId = 'ca-app-pub-3940256099942544/6300978111',
  });

  @override
  AdProviderType get type => AdProviderType.googleAdMob;

  @override
  Future<bool> initialize() async {
    _initialized = true;
    return true;
  }

  @override
  Future<AdUnitPayload?> loadBannerAd() async {
    if (!_initialized) await initialize();
    // Simulate real network fetch with high fill rate
    await Future.delayed(const Duration(milliseconds: 150));
    return const AdUnitPayload(
      provider: AdProviderType.googleAdMob,
      title: 'Google AdMob Partner',
      subtitle: 'Smart productivity tools & cloud services.',
      callToAction: 'Learn More',
      clickUrl: 'https://google.com',
    );
  }
}

/// Unity / AppLovin Provider (Secondary Fallback Network)
class SecondaryAdNetworkProvider implements BaseAdProvider {
  final AdProviderType providerType;
  final String placementId;
  bool _initialized = false;

  SecondaryAdNetworkProvider({
    this.providerType = AdProviderType.unityAds,
    this.placementId = 'synctask_banner_fallback',
  });

  @override
  AdProviderType get type => providerType;

  @override
  Future<bool> initialize() async {
    _initialized = true;
    return true;
  }

  @override
  Future<AdUnitPayload?> loadBannerAd() async {
    if (!_initialized) await initialize();
    await Future.delayed(const Duration(milliseconds: 100));
    return AdUnitPayload(
      provider: providerType,
      title: providerType == AdProviderType.unityAds ? 'Unity Ads Partner' : 'AppLovin MAX Partner',
      subtitle: 'Streamline your day with curated utility apps.',
      callToAction: 'View Offer',
      clickUrl: 'https://unity.com',
    );
  }
}

/// Internal House Sponsor Provider (Failsafe Local Fallback)
/// Guarantees the ad container never looks broken even if completely offline.
class HouseSponsorProvider implements BaseAdProvider {
  static final List<AdUnitPayload> _houseAds = [
    const AdUnitPayload(
      provider: AdProviderType.houseSponsor,
      title: 'SyncTask Pro Ad-Free',
      subtitle: 'Enjoy unlimited distraction-free focus for ₹10/mo.',
      callToAction: 'Upgrade ₹10',
    ),
    const AdUnitPayload(
      provider: AdProviderType.houseSponsor,
      title: 'SyncTask Direct P2P',
      subtitle: 'Transfer gigabytes of photos & videos directly offline.',
      callToAction: 'Try Quick Share',
    ),
  ];

  int _currentIndex = 0;

  @override
  AdProviderType get type => AdProviderType.houseSponsor;

  @override
  Future<bool> initialize() async => true;

  @override
  Future<AdUnitPayload?> loadBannerAd() async {
    final ad = _houseAds[_currentIndex % _houseAds.length];
    _currentIndex++;
    return ad;
  }
}

/// Multi-Network Ad Mediation Controller
/// Orchestrates a waterfall strategy: Provider 1 -> Provider 2 -> House Sponsor
class AdMediationController extends ChangeNotifier {
  final List<BaseAdProvider> _providers;
  AdUnitPayload? _currentAd;
  bool _isLoading = false;
  int _activeProviderIndex = 0;

  AdMediationController({List<BaseAdProvider>? providers})
      : _providers = providers ??
            [
              GoogleAdMobProvider(),
              SecondaryAdNetworkProvider(providerType: AdProviderType.unityAds),
              SecondaryAdNetworkProvider(providerType: AdProviderType.appLovin),
              HouseSponsorProvider(),
            ] {
    loadNextAd();
  }

  AdUnitPayload? get currentAd => _currentAd;
  bool get isLoading => _isLoading;
  AdProviderType get currentProviderType =>
      _currentAd?.provider ?? AdProviderType.houseSponsor;

  /// Loads an ad using waterfall mediation
  Future<void> loadNextAd() async {
    if (_isLoading) return;
    _isLoading = true;
    notifyListeners();

    try {
      // Try each provider in waterfall sequence
      for (int i = 0; i < _providers.length; i++) {
        final providerIndex = (_activeProviderIndex + i) % _providers.length;
        final provider = _providers[providerIndex];

        try {
          final ad = await provider.loadBannerAd().timeout(
                const Duration(seconds: 3),
              );
          if (ad != null) {
            _currentAd = ad;
            _activeProviderIndex = (providerIndex + 1) % _providers.length;
            break;
          }
        } catch (e) {
          debugPrint('[AdMediation] Provider ${provider.type} failed: $e. Cascading to next network...');
        }
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Manually rotate to next ad network
  void rotateAd() {
    loadNextAd();
  }
}
