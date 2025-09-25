// lib/pages/top_page.dart  ← 全差し替え
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher_string.dart';

import '../widgets/banner_ad_view.dart';
import 'name_input_page.dart';

class TopPage extends StatelessWidget {
  const TopPage({super.key});

  Future<void> _open(String url) async {
    await launchUrlString(url, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    const seed = Color(0xFF4C72FF);              // 基調の薄い青系
    const bg   = Color(0xFFEDF3FF);              // 画面背景
    const padH = 16.0;
    const padV = 12.0;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        elevation: 0.5,
        backgroundColor: Colors.white,
        title: const Text('PetClean 🐾', style: TextStyle(fontWeight: FontWeight.w700)),
        actions: [
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'privacy') {
                _open('https://restart-niigata.github.io/petclean-legal/privacy.html');
              } else if (v == 'terms') {
                _open('https://restart-niigata.github.io/petclean-legal/terms.html');
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'privacy', child: Text('プライバシーポリシー')),
              PopupMenuItem(value: 'terms', child: Text('利用規約')),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, c) {
            // ===== レイアウト計算（「1画面に収める」ことを最優先）=====
            const titleH    = 28.0 + 8.0;  // 見出し + 余白の概算
            const subTitleH = 18.0 + 16.0; // サブ見出し + 余白の概算
            const buttonH   = 56.0 + 12.0; // ボタン + 余白
            const bannerH   = 54.0;        // 下部バナーの概算（SafeArea分含む）
            const topPads   = padV + 0;    // 上側の余白
            final reservedH = titleH + subTitleH + buttonH + topPads;

            // 使える高さ = 画面の高さ - 予約領域 - 下部バナー分（重ならないよう少し引く）
            final usableH   = math.max(0, c.maxHeight - reservedH - 8);
            // 画像は「正方形」かつ、画面幅と usableH の小さいほう
            final side      = math.min(c.maxWidth, usableH);

            return Padding(
              padding: const EdgeInsets.fromLTRB(padH, padV, padH, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // --- 上部ロゴ（正方形＆自動フィット）---
                  if (side > 0)
                    Center(
                      child: SizedBox(
                        width: side,
                        height: side,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Image.asset(
                            'assets/images/top_pet.png',
                            fit: BoxFit.cover, // 余白なく正方形にトリミング
                          ),
                        ),
                      ),
                    ),

                  const SizedBox(height: 16),

                  // 見出し（大きめ）
                  const Text(
                    'ようこそ！',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: seed,
                    ),
                  ),
                  const SizedBox(height: 8),

                  const Text(
                    'ペットといっしょにキレイを記録しよう',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF3A4A66),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ボタン（必ず1画面に入る）
                  SizedBox(
                    height: 56,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: seed,
                        foregroundColor: Colors.white,
                        textStyle: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const NameInputPage()),
                        );
                      },
                      child: const Text('はじめる'),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            );
          },
        ),
      ),

      // --- 下部バナー（非 const／常設）---
      bottomNavigationBar: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            BannerAdView(),
            const SizedBox(height: 6),
          ],
        ),
      ),
    );
  }
}
