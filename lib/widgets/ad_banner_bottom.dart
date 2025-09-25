// lib/widgets/ad_banner_bottom.dart
import 'package:flutter/material.dart';
import 'banner_ad_view.dart';

/// 画面最下部に敷く共通バナー。
class AdBannerBottom extends StatelessWidget {
  const AdBannerBottom({super.key}); // ← const コンストラクタ

  @override
  Widget build(BuildContext context) {
    return const SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: BannerAdView(), // ← これも const でOK
      ),
    );
  }
}
