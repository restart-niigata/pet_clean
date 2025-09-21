// lib/utils/ad_manager.dart  ← 全文置き換え
import 'dart:async';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AdManager {
  static InterstitialAd? _interstitialAd;
  static bool _loading = false;
  static bool _initialized = false;

  // テスト用 Unit ID（本番は差し替え）
  static const String interstitialId = 'ca-app-pub-3940256099942544/1033173712';
  static const String bannerId       = 'ca-app-pub-3940256099942544/6300978111';

  // 1回だけ初期化
  static Future<void> _ensureInitialized() async {
    if (_initialized) return;
    await MobileAds.instance.initialize();
    _initialized = true;
  }

  // バナー（既存互換）
  static BannerAd createBanner() {
    return BannerAd(
      adUnitId: bannerId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: const BannerAdListener(),
    )..load();
  }

  // 事前ロード（多重ロード防止）
  static Future<void> loadInterstitial() async {
    await _ensureInitialized();
    if (_interstitialAd != null || _loading) return;

    _loading = true;
    await InterstitialAd.load(
      adUnitId: interstitialId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) { _interstitialAd = ad; _loading = false; },
        onAdFailedToLoad: (_) { _interstitialAd = null; _loading = false; },
      ),
    );
  }

  /// ★ボタンで使う：まず広告→閉じたら action 実行。未ロードなら広告スキップで即実行。
  static Future<void> runWithInterstitial(Future<void> Function() action) async {
    // 先にロードだけ仕掛ける（awaitしない）
    // ignore: discarded_futures
    loadInterstitial();

    final ad = _interstitialAd;
    if (ad == null) {
      await action();
      // ignore: discarded_futures
      loadInterstitial();
      return;
    }

    bool ran = false;
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (_) async {
        _disposeAndPreloadNext();
        if (!ran) { ran = true; await action(); }
      },
      onAdFailedToShowFullScreenContent: (_, __) async {
        _disposeAndPreloadNext();
        if (!ran) { ran = true; await action(); }
      },
    );

    await ad.show();
  }

  static void _disposeAndPreloadNext() {
    _interstitialAd?.dispose();
    _interstitialAd = null;
    // ignore: discarded_futures
    loadInterstitial();
  }

  // 既存互換API（必要ならそのまま使える）
  static void showInterstitial() {
    final ad = _interstitialAd;
    if (ad != null) {
      ad.fullScreenContentCallback = FullScreenContentCallback(
        onAdDismissedFullScreenContent: (_) => _disposeAndPreloadNext(),
        onAdFailedToShowFullScreenContent: (_, __) => _disposeAndPreloadNext(),
      );
      ad.show();
    } else {
      // ignore: discarded_futures
      loadInterstitial();
    }
  }

  static Future<void> checkAppOpenAd() async {
    final prefs = await SharedPreferences.getInstance();
    int count = prefs.getInt('launchCount') ?? 0;
    await prefs.setInt('launchCount', ++count);
    if (count % 2 == 0) showInterstitial();
  }

  static void onShare() => showInterstitial();

  static Future<void> onPhotoSaved() async {
    final prefs = await SharedPreferences.getInstance();
    int saveCount = prefs.getInt('photoSaveCount') ?? 0;
    await prefs.setInt('photoSaveCount', ++saveCount);
    if (saveCount % 3 == 0) showInterstitial();
  }

  static Future<void> onCommentShown() async {
    final prefs = await SharedPreferences.getInstance();
    int commentCount = prefs.getInt('commentCount') ?? 0;
    await prefs.setInt('commentCount', ++commentCount);
    if (commentCount % 15 == 0) showInterstitial();
  }
}
