import 'package:google_mobile_ads/google_mobile_ads.dart';

/// 起動時の全画面広告（App Open Ad）
class AppOpenAdManager {
  AppOpenAd? _appOpenAd;
  bool _isShowing = false;

  AppOpenAdManager._();
  static final AppOpenAdManager instance = AppOpenAdManager._();

  /// テストID（Android）: ca-app-pub-3940256099942544/3419835294
  /// テストID（iOS）    : ca-app-pub-3940256099942544/5662855259
  /// 本番はあなたのIDに差し替えてください。
  String get _adUnitId {
    return TargetPlatform.android == defaultTargetPlatform
        ? 'ca-app-pub-3940256099942544/3419835294'
        : 'ca-app-pub-3940256099942544/5662855259';
  }

  Future<void> load() async {
    await AppOpenAd.load(
      adUnitId: _adUnitId,
      request: const AdRequest(),
      adLoadCallback: AppOpenAdLoadCallback(
        onAdLoaded: (ad) => _appOpenAd = ad,
        onAdFailedToLoad: (error) {
          _appOpenAd = null;
        },
      ),
      orientation: AppOpenAd.orientationPortrait,
    );
  }

  void showIfAvailable() {
    if (_isShowing) return;
    final ad = _appOpenAd;
    if (ad == null) return;

    _isShowing = true;
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) async {
        _isShowing = false;
        ad.dispose();
        _appOpenAd = null;
        // 次回に備えて再ロード
        await load();
      },
      onAdFailedToShowFullScreenContent: (ad, error) async {
        _isShowing = false;
        ad.dispose();
        _appOpenAd = null;
        await load();
      },
    );

    ad.show();
  }
}
