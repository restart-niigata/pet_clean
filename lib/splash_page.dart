import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'pages/pet_type_select_page.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});
  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  InterstitialAd? _startAd;
  bool _navigated = false;

  // AdMob公式テストID（Android・インタースティシャル）
  static const _kInterstitialTestId = 'ca-app-pub-3940256099942544/1033173712';

  @override
  void initState() {
    super.initState();
    _loadAd();
    // 広告の有無に関わらず1.2秒後に遷移
    Future.delayed(const Duration(milliseconds: 1200), _goNextIfNeeded);
  }

  void _loadAd() {
    InterstitialAd.load(
      adUnitId: _kInterstitialTestId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _startAd = ad;
          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (a) {
              a.dispose();
              _goNextIfNeeded();
            },
            onAdFailedToShowFullScreenContent: (a, e) {
              a.dispose();
              _goNextIfNeeded();
            },
          );
          // 起動時に表示
          ad.show();
        },
        onAdFailedToLoad: (_) {
          _startAd = null;
        },
      ),
    );
  }

  void _goNextIfNeeded() {
    if (_navigated) return;
    _navigated = true;
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const PetTypeSelectPage()),
    );
  }

  @override
  void dispose() {
    _startAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // アプリ起動スプラッシュ：app_icon.pngをフルスクリーン
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset('assets/images/app_icon.png', fit: BoxFit.cover),
          // ほんの少し暗く
          Container(color: Colors.black.withOpacity(0.05)),
        ],
      ),
    );
  }
}
