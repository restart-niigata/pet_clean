import 'dart:io';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdHelper {
  // ★テスト用ユニットID（必要に応じて本番IDに差し替えてください）
  static String get interstitialUnitId {
    if (Platform.isAndroid) {
      return 'ca-app-pub-3940256099942544/1033173712'; // Android test interstitial
    } else if (Platform.isIOS) {
      return 'ca-app-pub-3940256099942544/5135589807'; // iOS test interstitial
    }
    throw UnsupportedError('Unsupported platform');
  }

  static String get bannerUnitId {
    if (Platform.isAndroid) {
      return 'ca-app-pub-3940256099942544/6300978111'; // Android test banner
    } else if (Platform.isIOS) {
      return 'ca-app-pub-3940256099942544/2934735716'; // iOS test banner
    }
    throw UnsupportedError('Unsupported platform');
  }

  static Future<InterstitialAd?> loadInterstitial() async {
    return InterstitialAd.load(
      adUnitId: interstitialUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) => ad,
        onAdFailedToLoad: (error) => null,
      ),
    ).then((_) => _ as InterstitialAd?);
  }

  static BannerAd createBanner() {
    return BannerAd(
      size: AdSize.banner,
      adUnitId: bannerUnitId,
      listener: const BannerAdListener(),
      request: const AdRequest(),
    );
  }
}
