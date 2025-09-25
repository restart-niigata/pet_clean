import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../services/ad_service.dart';

/// 画面下部に常駐するバナー。未読み込み時も高さを確保して「消えない」ようにする。
class BannerAdView extends StatefulWidget {
  const BannerAdView({super.key});

  @override
  State<BannerAdView> createState() => _BannerAdViewState();
}

class _BannerAdViewState extends State<BannerAdView> {
  BannerAd? _ad;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    final ad = BannerAd(
      adUnitId: AdService.bannerUnitId, // 本番/テストは AdService 側で管理
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          if (!mounted) return;
          setState(() {
            _ad = ad as BannerAd;
            _loaded = true;
          });
        },
        onAdFailedToLoad: (ad, err) {
          ad.dispose();
          // 失敗しても高さは維持（真っ白）。数秒後に再試行。
          Future.delayed(const Duration(seconds: 10), () {
            if (mounted) _load();
          });
        },
      ),
    );
    ad.load();
  }

  @override
  void dispose() {
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // AdSize.banner の高さに少し余白を足して常に確保
    const reservedHeight = 60.0;

    return SizedBox(
      height: reservedHeight,
      width: double.infinity,
      child: Center(
        child: _loaded && _ad != null
            ? AdWidget(ad: _ad!)
            : const SizedBox(
                height: 50,
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              ),
      ),
    );
  }
}
