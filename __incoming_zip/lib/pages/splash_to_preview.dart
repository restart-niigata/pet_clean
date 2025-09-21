// lib/pages/splash_to_preview.dart
import 'dart:async';
import 'package:flutter/material.dart';
import '../services/ad_service.dart';
import 'preview_page.dart';

// アプリ起動中は1回だけ遷移広告を出す
bool _interstitialShownOnce = false;

class SplashToPreview extends StatefulWidget {
  final String? owner;
  final String? pet;
  final String? species;
  final String? personality;
  final String? dialect;

  const SplashToPreview({
    super.key,
    this.owner,
    this.pet,
    this.species,
    this.personality,
    this.dialect,
  });

  @override
  State<SplashToPreview> createState() => _SplashToPreviewState();
}

class _SplashToPreviewState extends State<SplashToPreview> {
  @override
  void initState() {
    super.initState();
    _go();
  }

  Future<void> _go() async {
    // 遷移演出（top_pet.pngを全画面で少しだけ表示）
    await Future.delayed(const Duration(milliseconds: 900));

    // インタースティシャルはアプリ起動中1回だけ
    if (!_interstitialShownOnce) {
      await AdService.loadInterstitial(onLoaded: () {
        AdService.showInterstitialIfReady();
      });
      _interstitialShownOnce = true;
      // 表示の僅かな待ち
      await Future.delayed(const Duration(milliseconds: 400));
    }

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => PreviewPage(
          owner: widget.owner ?? '',
          pet: widget.pet ?? '',
          species: widget.species ?? '',
          personality: widget.personality ?? '',
          dialect: widget.dialect ?? '標準語',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 画面全体に top_pet.png を表示
    return Scaffold(
      body: Container(
        color: Colors.white,
        alignment: Alignment.center,
        child: Image.asset(
          'assets/images/top_pet.png',
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
        ),
      ),
    );
  }
}
