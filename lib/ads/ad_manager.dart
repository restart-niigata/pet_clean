import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// 正準の広告管理（Interstitial のみ制御）
/// - initialize()
/// - preloadInterstitialIfNeeded()
/// - showInterstitialOnceIfAvailable({onDismissed})
class AdManager {
  AdManager._internal();
  static final AdManager _instance = AdManager._internal();
  factory AdManager() => _instance;

  bool _initialized = false;
  InterstitialAd? _interstitial;
  bool _isLoadingInterstitial = false;
  bool _interstitialShownThisSession = false;

  Future<void> initialize() async {
    if (_initialized) return;
    await MobileAds.instance.initialize();
    _initialized = true;
  }

  String get _interstitialUnitId => defaultTargetPlatform == TargetPlatform.iOS
      ? 'ca-app-pub-3940256099942544/5135589807' // iOS test
      : 'ca-app-pub-3940256099942544/1033173712'; // Android test

  Future<void> preloadInterstitialIfNeeded() async {
    if (_interstitialShownThisSession) return;
    if (_isLoadingInterstitial || _interstitial != null) return;

    _isLoadingInterstitial = true;
    await InterstitialAd.load(
      adUnitId: _interstitialUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitial = ad;
          _isLoadingInterstitial = false;
        },
        onAdFailedToLoad: (error) {
          _interstitial = null;
          _isLoadingInterstitial = false;
        },
      ),
    );
  }

  /// セッション中に 1 回だけ表示。表示済みなら false を返す。
  Future<bool> showInterstitialOnceIfAvailable({VoidCallback? onDismissed}) async {
    if (_interstitialShownThisSession) return false;
    if (_interstitial == null) {
      await preloadInterstitialIfNeeded();
    }
    final ad = _interstitial;
    if (ad == null) return false;

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (_) {
        _interstitialShownThisSession = true;
        _interstitial?.dispose();
        _interstitial = null;
        onDismissed?.call();
      },
      onAdFailedToShowFullScreenContent: (_, __) {
        _interstitialShownThisSession = true;
        _interstitial?.dispose();
        _interstitial = null;
        onDismissed?.call();
      },
    );

    try {
      await ad.show();
      return true;
    } catch (_) {
      _interstitialShownThisSession = true;
      _interstitial?.dispose();
      _interstitial = null;
      onDismissed?.call();
      return false;
    }
  }
}
