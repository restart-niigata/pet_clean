import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../services/ad_service.dart';

class BannerAdView extends StatefulWidget {
  const BannerAdView({super.key});

  @override
  State<BannerAdView> createState() => _BannerAdViewState();
}

class _BannerAdViewState extends State<BannerAdView> {
  BannerAd? _ad;
  Timer? _retryTimer;
  bool _loading = false;
  int _failureCount = 0;

  @override
  void initState() {
    super.initState();
    AdService.canRequestAds.addListener(_handleAvailabilityChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _handleAvailabilityChanged();
  }

  void _handleAvailabilityChanged() {
    if (AdService.canRequestAds.value && _ad == null && !_loading) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _load();
      });
    } else if (mounted) {
      setState(() {});
    }
  }

  Future<void> _load() async {
    if (!mounted || !AdService.canRequestAds.value || _loading || _ad != null) {
      return;
    }

    _loading = true;
    final width = MediaQuery.sizeOf(context).width.truncate();
    AdSize? size;
    try {
      size =
          await AdSize.getCurrentOrientationAnchoredAdaptiveBannerAdSize(width);
    } on Object catch (error) {
      debugPrint('Banner size lookup failed: $error');
    }
    if (!mounted || size == null) {
      _loading = false;
      _scheduleRetry();
      return;
    }

    final ad = BannerAd(
      adUnitId: AdService.bannerUnitId,
      size: size,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (loadedAd) {
          if (!mounted) {
            loadedAd.dispose();
            return;
          }
          setState(() {
            _ad = loadedAd as BannerAd;
            _loading = false;
            _failureCount = 0;
          });
        },
        onAdFailedToLoad: (failedAd, error) {
          failedAd.dispose();
          _loading = false;
          _failureCount++;
          debugPrint('Banner load failed: ${error.message}');
          _scheduleRetry();
        },
      ),
    );
    try {
      await ad.load();
    } on Object catch (error) {
      ad.dispose();
      _loading = false;
      _failureCount++;
      debugPrint('Banner load error: $error');
      _scheduleRetry();
    }
  }

  void _scheduleRetry() {
    _retryTimer?.cancel();
    final seconds = switch (_failureCount) {
      <= 0 => 30,
      1 => 60,
      _ => 300,
    };
    _retryTimer = Timer(Duration(seconds: seconds), _load);
  }

  @override
  void dispose() {
    AdService.canRequestAds.removeListener(_handleAvailabilityChanged);
    _retryTimer?.cancel();
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ad = _ad;
    if (!AdService.canRequestAds.value || ad == null) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      width: ad.size.width.toDouble(),
      height: ad.size.height.toDouble(),
      child: AdWidget(ad: ad),
    );
  }
}
