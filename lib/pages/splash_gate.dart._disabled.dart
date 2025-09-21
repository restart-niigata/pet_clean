import 'package:flutter/material.dart';
import '../ads/ad_manager.dart';
import 'top_page.dart';

class SplashGate extends StatefulWidget {
  const SplashGate({super.key});
  @override
  State<SplashGate> createState() => _SplashGateState();
}

class _SplashGateState extends State<SplashGate> {
  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    // 起動時 AppOpenAd（代替で全画面を確実に出すため Interstitial もロード）
    await AdManager.loadAppOpenIfPossible();
    await Future.delayed(const Duration(milliseconds: 400));
    await AdManager.showAppOpenIfAvailable();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const TopPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
