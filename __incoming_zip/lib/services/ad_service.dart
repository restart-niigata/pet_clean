import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../ads/ad_manager.dart';

/// 互換層: 既存コードが参照している静的 API を提供
class AdService {
  /// 初期化（既存コード互換）
  /// - MobileAds の初期化
  /// - AdManager の初期化（内部で重複初期化ガードあり）
  static Future<void> init() async {
    await MobileAds.instance.initialize();
    await AdManager().initialize();
  }

  /// バナー広告ユニットID（テストID）
  /// iOS:  ca-app-pub-3940256099942544/2934735716
  /// AND:  ca-app-pub-3940256099942544/6300978111
  static String get bannerUnitId => defaultTargetPlatform == TargetPlatform.iOS
      ? 'ca-app-pub-3940256099942544/2934735716'
      : 'ca-app-pub-3940256099942544/6300978111';

  /// 既存コードの createBanner 互換:
  /// - 生成直後に自動で .load()（互換性のため既定で true）
  static BannerAd createBanner({AdSize size = AdSize.banner, bool autoLoad = true}) {
    final ad = BannerAd(
      adUnitId: bannerUnitId,
      size: size,
      request: const AdRequest(),
      listener: BannerAdListener(),
    );
    if (autoLoad) {
      ad.load();
    }
    return ad;
  }

  /// 既存コードの loadInterstitial 互換
  static Future<void> loadInterstitial({VoidCallback? onLoaded}) async {
    await AdManager().initialize();
    await AdManager().preloadInterstitialIfNeeded();
    onLoaded?.call();
  }

  /// 既存コードの showInterstitialIfReady 互換
  /// - セッション中 1 回のみ表示（AdManager 側のガード）
  static Future<void> showInterstitialIfReady({VoidCallback? onDismissed}) async {
    await AdManager().showInterstitialOnceIfAvailable(onDismissed: onDismissed);
  }
}
