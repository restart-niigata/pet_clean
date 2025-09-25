// lib/services/ad_service.dart  --- 全差し替え（5回目はロード完了を待って即表示）
import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AdService {
  AdService._();

  static bool _initialized = false;
  static InterstitialAd? _interstitial;

  // ===== 本番ユニットID =====
  static const _prodBannerAndroid = 'ca-app-pub-6578871044839472/4436844857';
  static const _prodBannerIOS     = 'ca-app-pub-6578871044839472/5083712115';

  static const _prodInterstitialAndroid = 'ca-app-pub-6578871044839472/5401037193';
  static const _prodInterstitialIOS     = 'ca-app-pub-6578871044839472/6205222092';

  // ===== 公式テストID（文字列） =====
  static const _testBannerAndroid       = 'ca-app-pub-3940256099942544/6300978111';
  static const _testBannerIOS           = 'ca-app-pub-3940256099942544/2934735716';
  static const _testInterstitialAndroid = 'ca-app-pub-3940256099942544/1033173712';
  static const _testInterstitialIOS     = 'ca-app-pub-3940256099942544/4411468910';

  static bool get _isMobileAdsSupported =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  // バナー（本番）
  static String get bannerUnitId {
    if (Platform.isAndroid) return _prodBannerAndroid;
    if (Platform.isIOS)     return _prodBannerIOS;
    return _testBannerAndroid; // デスクトップ/Web等はビルド通過用
  }

  // インステ（本番）
  static String get _interstitialUnitId {
    if (Platform.isAndroid) return _prodInterstitialAndroid;
    if (Platform.isIOS)     return _prodInterstitialIOS;
    return _testInterstitialAndroid;
  }

  static Future<void> init() async {
    if (_initialized) return;
    if (!_isMobileAdsSupported) {
      _initialized = true;
      return;
    }
    await MobileAds.instance.initialize();
    _initialized = true;
    await _loadInterstitial(); // 起動時から先読み
  }

  /// 先読み（待たない）
  static Future<void> _loadInterstitial() async {
    if (!_isMobileAdsSupported) return;
    try {
      await InterstitialAd.load(
        adUnitId: _interstitialUnitId,
        request: const AdRequest(),
        adLoadCallback: InterstitialAdLoadCallback(
          onAdLoaded: (ad) => _interstitial = ad,
          onAdFailedToLoad: (_) => _interstitial = null,
        ),
      );
    } catch (_) {
      _interstitial = null;
    }
  }

  /// 先読み（完了を“待つ”）
  static Future<bool> _loadInterstitialAndWait() async {
    if (!_isMobileAdsSupported) return false;
    final completer = Completer<bool>();
    try {
      await InterstitialAd.load(
        adUnitId: _interstitialUnitId,
        request: const AdRequest(),
        adLoadCallback: InterstitialAdLoadCallback(
          onAdLoaded: (ad) {
            _interstitial = ad;
            completer.complete(true);
          },
          onAdFailedToLoad: (_) {
            _interstitial = null;
            completer.complete(false);
          },
        ),
      );
    } catch (_) {
      completer.complete(false);
    }
    return completer.future;
  }

  /// 5回起動ごと（5,10,15, …）に表示。
  /// 未ロードならロード完了を“待ってから”表示するように改善。
  static Future<void> maybeShowLaunchInterstitialOn5th() async {
    try {
      final p = await SharedPreferences.getInstance();
      final current = (p.getInt('launch.count') ?? 0) + 1;
      await p.setInt('launch.count', current);

      if (!_isMobileAdsSupported) return;

      if (current % 5 != 0) {
        // 5回目以外は静かに先読みだけ更新
        if (_interstitial == null) unawaited(_loadInterstitial());
        return;
      }

      // 5回目：未ロードならロード完了を待つ
      if (_interstitial == null) {
        final ok = await _loadInterstitialAndWait();
        if (!ok) return; // 失敗時は諦める
      }

      // 表示
      final ad = _interstitial!;
      _interstitial = null;
      await ad.show();
      ad.dispose();

      // 次回用に先読み
      unawaited(_loadInterstitial());
    } catch (_) {
      // 失敗時は黙ってスキップ
    }
  }

  /// 任意の処理の前に、挟めたらインステを挟む
  static Future<void> runWithInterstitial(Future<void> Function() task) async {
    if (_isMobileAdsSupported && _interstitial != null) {
      final ad = _interstitial!;
      _interstitial = null;
      await ad.show();
      ad.dispose();
      unawaited(_loadInterstitial());
    }
    await task();
  }
}
