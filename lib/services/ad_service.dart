import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AdService {
  AdService._();

  static const _prodBannerAndroid = 'ca-app-pub-6578871044839472/4436844857';
  static const _prodBannerIOS = 'ca-app-pub-6578871044839472/5083712115';
  static const _prodInterstitialAndroid =
      'ca-app-pub-6578871044839472/5401037193';
  static const _prodInterstitialIOS = 'ca-app-pub-6578871044839472/6205222092';

  static const _testBannerAndroid = 'ca-app-pub-3940256099942544/6300978111';
  static const _testBannerIOS = 'ca-app-pub-3940256099942544/2934735716';
  static const _testInterstitialAndroid =
      'ca-app-pub-3940256099942544/1033173712';
  static const _testInterstitialIOS = 'ca-app-pub-3940256099942544/4411468910';

  static const _shareCountKey = 'ad.share.completed.count';
  static const _lastInterstitialAtKey = 'ad.interstitial.lastShownAt';
  static const _interstitialEvery = 3;
  static const _interstitialCooldown = Duration(minutes: 5);

  static final ValueNotifier<bool> canRequestAds = ValueNotifier(false);
  static final ValueNotifier<bool> privacyOptionsRequired =
      ValueNotifier(false);

  static Future<void>? _initializing;
  static bool _mobileAdsInitialized = false;
  static bool _interstitialLoading = false;
  static bool _interstitialShowing = false;
  static InterstitialAd? _interstitial;

  static bool get _isMobileAdsSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  static bool get _isIOS => defaultTargetPlatform == TargetPlatform.iOS;

  static String get bannerUnitId {
    if (!kReleaseMode) {
      return _isIOS ? _testBannerIOS : _testBannerAndroid;
    }
    return _isIOS ? _prodBannerIOS : _prodBannerAndroid;
  }

  static String get _interstitialUnitId {
    if (!kReleaseMode) {
      return _isIOS ? _testInterstitialIOS : _testInterstitialAndroid;
    }
    return _isIOS ? _prodInterstitialIOS : _prodInterstitialAndroid;
  }

  /// 独自規約への同意完了後に一度だけ呼び出す。
  /// UMPの状態更新と必要なフォーム表示を終え、広告要求可能な場合だけSDKを開始する。
  static Future<void> initialize() {
    return _initializing ??= _initialize();
  }

  static Future<void> _initialize() async {
    if (!_isMobileAdsSupported) return;

    final updateCompleted = Completer<void>();
    try {
      ConsentInformation.instance.requestConsentInfoUpdate(
        ConsentRequestParameters(),
        () {
          if (!updateCompleted.isCompleted) updateCompleted.complete();
        },
        (error) {
          debugPrint('UMP consent update failed: ${error.message}');
          if (!updateCompleted.isCompleted) updateCompleted.complete();
        },
      );
    } on Object catch (error) {
      debugPrint('UMP consent update error: $error');
      if (!updateCompleted.isCompleted) updateCompleted.complete();
    }
    await updateCompleted.future;

    try {
      await ConsentForm.loadAndShowConsentFormIfRequired((error) {
        if (error != null) {
          debugPrint('UMP consent form failed: ${error.message}');
        }
      });
    } on Object catch (error) {
      debugPrint('UMP consent form error: $error');
    }

    await _refreshPrivacyState();
    await _startAdsIfAllowed();
  }

  static Future<void> _refreshPrivacyState() async {
    try {
      privacyOptionsRequired.value = await ConsentInformation.instance
              .getPrivacyOptionsRequirementStatus() ==
          PrivacyOptionsRequirementStatus.required;
    } on Object {
      privacyOptionsRequired.value = false;
    }
  }

  static Future<void> _startAdsIfAllowed() async {
    final allowed = await ConsentInformation.instance.canRequestAds();
    canRequestAds.value = allowed;
    if (!allowed || _mobileAdsInitialized) return;

    await MobileAds.instance.initialize();
    _mobileAdsInitialized = true;
    unawaited(_loadInterstitial());
  }

  /// UMPが要求する場合に、広告プライバシー設定画面を開く。
  /// 成功時は `null`、失敗時はユーザー表示用メッセージを返す。
  static Future<String?> showPrivacyOptions() async {
    if (!_isMobileAdsSupported || !privacyOptionsRequired.value) {
      return '現在、変更できる広告プライバシー設定はありません';
    }

    FormError? formError;
    try {
      await ConsentForm.showPrivacyOptionsForm((error) => formError = error);
      await _refreshPrivacyState();
      await _startAdsIfAllowed();
    } on Object catch (error) {
      return '広告プライバシー設定を開けませんでした: $error';
    }
    if (formError != null) {
      return '広告プライバシー設定を開けませんでした: ${formError!.message}';
    }
    return null;
  }

  static Future<void> _loadInterstitial() async {
    if (!canRequestAds.value ||
        !_mobileAdsInitialized ||
        _interstitialLoading ||
        _interstitialShowing ||
        _interstitial != null) {
      return;
    }

    _interstitialLoading = true;
    try {
      await InterstitialAd.load(
        adUnitId: _interstitialUnitId,
        request: const AdRequest(),
        adLoadCallback: InterstitialAdLoadCallback(
          onAdLoaded: (ad) {
            _interstitialLoading = false;
            _interstitial = ad;
          },
          onAdFailedToLoad: (error) {
            _interstitialLoading = false;
            _interstitial = null;
            debugPrint('Interstitial load failed: ${error.message}');
          },
        ),
      );
    } on Object catch (error) {
      _interstitialLoading = false;
      _interstitial = null;
      debugPrint('Interstitial load error: $error');
    }
  }

  /// 共有成功という自然な区切りでのみ、3回ごと・最短5分間隔で表示する。
  /// 未ロード時は操作を待たせず、その回の広告をスキップする。
  static Future<void> maybeShowAfterSuccessfulShare() async {
    if (!canRequestAds.value || _interstitialShowing) return;

    final preferences = await SharedPreferences.getInstance();
    final count = (preferences.getInt(_shareCountKey) ?? 0) + 1;
    await preferences.setInt(_shareCountKey, count);
    if (count % _interstitialEvery != 0) return;

    final lastShownMillis = preferences.getInt(_lastInterstitialAtKey) ?? 0;
    final lastShown = DateTime.fromMillisecondsSinceEpoch(lastShownMillis);
    if (DateTime.now().difference(lastShown) < _interstitialCooldown) return;

    final ad = _interstitial;
    if (ad == null) {
      unawaited(_loadInterstitial());
      return;
    }

    _interstitial = null;
    _interstitialShowing = true;
    final dismissed = Completer<void>();
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (_) async {
        await preferences.setInt(
          _lastInterstitialAtKey,
          DateTime.now().millisecondsSinceEpoch,
        );
      },
      onAdDismissedFullScreenContent: (shownAd) {
        shownAd.dispose();
        _interstitialShowing = false;
        if (!dismissed.isCompleted) dismissed.complete();
        unawaited(_loadInterstitial());
      },
      onAdFailedToShowFullScreenContent: (failedAd, error) {
        failedAd.dispose();
        _interstitialShowing = false;
        debugPrint('Interstitial show failed: ${error.message}');
        if (!dismissed.isCompleted) dismissed.complete();
        unawaited(_loadInterstitial());
      },
    );

    try {
      await ad.show();
      await dismissed.future;
    } on Object catch (error) {
      ad.dispose();
      _interstitialShowing = false;
      if (!dismissed.isCompleted) dismissed.complete();
      debugPrint('Interstitial show error: $error');
      unawaited(_loadInterstitial());
    }
  }
}
