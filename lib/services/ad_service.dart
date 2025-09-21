// lib/services/ad_service.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AdIds {
  // ▼▼ あなたの本番IDを下記3つに設定してください ▼▼
  static const String appIdAndroidProd        = 'ca-app-pub-XXXXXXXXXXXXXXXX~YYYYYYYYYY';
  static const String interstitialAndroidProd = 'ca-app-pub-XXXXXXXXXXXXXXXX/IIIIIIIIII';
  static const String bannerAndroidProd       = 'ca-app-pub-XXXXXXXXXXXXXXXX/BBBBBBBBBB';
  // ▲▲----------------------------------------------▲▲

  // テストID（Google公式）
  static const String interstitialTest = 'ca-app-pub-3940256099942544/1033173712';
  static const String bannerTest       = 'ca-app-pub-3940256099942544/6300978111';

  // 本番を使うか（trueのままでOK。未設定項目は自動でテストにフォールバック）
  static const bool useProd = true;

  static bool _looksValid(String s) =>
      s.startsWith('ca-app-pub-') && !s.contains('XXXXXXXX');

  static String get interstitial =>
      (useProd && _looksValid(interstitialAndroidProd))
          ? interstitialAndroidProd
          : interstitialTest;

  static String get banner =>
      (useProd && _looksValid(bannerAndroidProd))
          ? bannerAndroidProd
          : bannerTest;
}

class AdService {
  AdService._();

  static InterstitialAd? _ad;
  static bool _loading = false;
  static bool _showing = false;

  static String get bannerUnitId => AdIds.banner;

  /// 事前ロード
  static Future<void> loadInterstitial() async {
    if (_ad != null || _loading) return;
    _loading = true;
    await InterstitialAd.load(
      adUnitId: AdIds.interstitial,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _ad = ad;
          _loading = false;
        },
        onAdFailedToLoad: (err) {
          _ad = null;
          _loading = false;
          if (kDebugMode) {
            // ignore: avoid_print
            print('Interstitial failed to load: $err');
          }
        },
      ),
    );
  }

  /// あれば表示し、閉じたら [after] 実行。最大3秒だけロード待ちして無ければフォールバック。
  static Future<void> runWithInterstitial(Future<void> Function() after) async {
    unawaited(loadInterstitial());

    for (int i = 0; i < 30; i++) {
      if (_ad != null) break;
      await Future.delayed(const Duration(milliseconds: 100));
    }

    if (_ad == null || _showing) {
      await after();
      unawaited(loadInterstitial());
      return;
    }

    final ad = _ad!;
    _ad = null;
    _showing = true;

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) async {
        _showing = false;
        ad.dispose();
        await after();
        unawaited(loadInterstitial());
      },
      onAdFailedToShowFullScreenContent: (ad, err) async {
        _showing = false;
        ad.dispose();
        await after();
        unawaited(loadInterstitial());
      },
    );

    ad.show();
  }

  /// 起動5回に1回だけ起動直後インタースティシャル
  static Future<void> maybeShowLaunchInterstitialOn5th() async {
    final p = await SharedPreferences.getInstance();
    int c = p.getInt('launch_counter') ?? 0;
    c += 1;
    if (c >= 5) {
      c = 0;
      await loadInterstitial();
      for (int i = 0; i < 20 && _ad == null; i++) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
      if (_ad != null && !_showing) {
        final ad = _ad!;
        _ad = null;
        _showing = true;
        ad.fullScreenContentCallback = FullScreenContentCallback(
          onAdDismissedFullScreenContent: (ad) {
            _showing = false;
            ad.dispose();
            unawaited(loadInterstitial());
          },
          onAdFailedToShowFullScreenContent: (ad, err) {
            _showing = false;
            ad.dispose();
            unawaited(loadInterstitial());
          },
        );
        ad.show();
      }
    }
    await p.setInt('launch_counter', c);
  }
}
