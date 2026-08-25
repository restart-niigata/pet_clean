// lib/pages/name_input_page.dart  ← 全差し替え
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher_string.dart';

import '../services/ad_service.dart'; // ★ 追加：広告呼び出し
import '../widgets/banner_ad_view.dart';
import 'pet_type_select_page.dart';
import 'personality_select_page.dart';
import 'dialect_select_page.dart';
import 'preview_page.dart';

class NameInputPage extends StatefulWidget {
  const NameInputPage({super.key});
  @override
  State<NameInputPage> createState() => _NameInputPageState();
}

class _NameInputPageState extends State<NameInputPage> {
  final _ownerCtrl = TextEditingController();
  final _petCtrl = TextEditingController();

  String _species = '犬';
  String _personality = '元気';
  String _dialect = '標準語';

  @override
  void initState() {
    super.initState();
    _ownerCtrl.addListener(_onNamesChanged);
    _petCtrl.addListener(_onNamesChanged);
    _restore();
  }

  void _onNamesChanged() {
    if (mounted) setState(() {});
  }

  bool get _canStart =>
      _ownerCtrl.text.trim().isNotEmpty && _petCtrl.text.trim().isNotEmpty;

  Future<void> _restore() async {
    final p = await SharedPreferences.getInstance();
    _ownerCtrl.text = p.getString('ownerName') ?? '';
    _petCtrl.text = p.getString('petName') ?? '';
    _species = p.getString('species') ?? _species;
    _personality = p.getString('personality') ?? _personality;
    _dialect = p.getString('dialect') ?? _dialect;
    if (mounted) setState(() {});
  }

  Future<void> _save() async {
    final p = await SharedPreferences.getInstance();
    await p.setString('ownerName', _ownerCtrl.text);
    await p.setString('petName', _petCtrl.text);
    await p.setString('species', _species);
    await p.setString('personality', _personality);
    await p.setString('dialect', _dialect);
  }

  // ===== メニュー関連 =====
  void _openUrl(String url) async {
    final ok = await launchUrlString(url, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('外部ブラウザを開けませんでした')),
      );
    }
  }

  Future<void> _resetConsent() async {
    final p = await SharedPreferences.getInstance();
    await p.setBool('legal.accepted', false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('同意をリセットしました。次回起動時に確認されます。')),
      );
    }
  }

  Future<void> _showAdPrivacyOptions() async {
    final message = await AdService.showPrivacyOptions();
    if (message != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  @override
  void dispose() {
    _ownerCtrl.dispose();
    _petCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const seed = Color(0xFF4C72FF);
    const bg = Color(0xFFF2F6FF);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        elevation: 0.5,
        title: const FittedBox(
          fit: BoxFit.scaleDown,
          child: Text('あなたとペットちゃんの情報を入れてね', maxLines: 1),
        ),
        actions: [
          ValueListenableBuilder<bool>(
            valueListenable: AdService.privacyOptionsRequired,
            builder: (_, showAdPrivacy, __) => PopupMenuButton<String>(
              onSelected: (v) {
                switch (v) {
                  case 'privacy':
                    _openUrl(
                      'https://restart-niigata.github.io/petclean-legal/privacy.html',
                    );
                    break;
                  case 'terms':
                    _openUrl(
                      'https://restart-niigata.github.io/petclean-legal/terms.html',
                    );
                    break;
                  case 'adPrivacy':
                    _showAdPrivacyOptions();
                    break;
                  case 'reset':
                    _resetConsent();
                    break;
                }
              },
              itemBuilder: (_) => [
                const PopupMenuItem(
                  value: 'privacy',
                  child: Text('プライバシーポリシー'),
                ),
                const PopupMenuItem(
                  value: 'terms',
                  child: Text('利用規約'),
                ),
                if (showAdPrivacy)
                  const PopupMenuItem(
                    value: 'adPrivacy',
                    child: Text('広告プライバシー設定'),
                  ),
                const PopupMenuItem(
                  value: 'reset',
                  child: Text('同意をリセット'),
                ),
              ],
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (_, c) {
            final side = math.max(
              96.0,
              math.min(c.maxWidth - 28, (c.maxHeight - 52) * 0.24),
            );

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Column(
                children: [
                  // 上部の正方形ロゴ（画面に合わせて自動調整）
                  SizedBox(
                    width: side,
                    height: side,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: Image.asset(
                        'assets/images/top_pet.png',
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // 入力＆選択
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.only(bottom: 6),
                      physics: const BouncingScrollPhysics(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _label('あなたの名前', seed),
                          _textBox(controller: _ownerCtrl, hint: 'あなたの名前'),
                          const SizedBox(height: 8),
                          _label('ペットの名前', seed),
                          _textBox(controller: _petCtrl, hint: 'ペットの名前'),
                          const SizedBox(height: 8),
                          _label('種類', seed),
                          _selectTileCompact(
                            valueText: _species,
                            onTap: () async {
                              final v =
                                  await Navigator.of(context).push<String>(
                                MaterialPageRoute(
                                  builder: (_) =>
                                      PetTypeSelectPage(current: _species),
                                ),
                              );
                              if (v != null) setState(() => _species = v);
                            },
                          ),
                          const SizedBox(height: 6),
                          _label('性格', seed),
                          _selectTileCompact(
                            valueText: _personality,
                            onTap: () async {
                              final v =
                                  await Navigator.of(context).push<String>(
                                MaterialPageRoute(
                                  builder: (_) => PersonalitySelectPage(
                                    current: _personality,
                                  ),
                                ),
                              );
                              if (v != null) setState(() => _personality = v);
                            },
                          ),
                          const SizedBox(height: 6),
                          _label('方言', seed),
                          _selectTileCompact(
                            valueText: _dialect,
                            onTap: () async {
                              final v =
                                  await Navigator.of(context).push<String>(
                                MaterialPageRoute(
                                  builder: (_) =>
                                      DialectSelectPage(current: _dialect),
                                ),
                              );
                              if (v != null) setState(() => _dialect = v);
                            },
                          ),
                        ],
                      ),
                    ),
                  ),

                  // 開始ボタン（画面下に固定）
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: seed,
                        foregroundColor: Colors.white,
                        textStyle: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w700),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: _canStart
                          ? () async {
                              await _save();
                              if (!context.mounted) return;
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => PreviewPage(
                                    ownerName: _ownerCtrl.text.trim(),
                                    petName: _petCtrl.text.trim(),
                                    species: _species,
                                    personality: _personality,
                                    dialect: _dialect,
                                  ),
                                ),
                              );
                            }
                          : null,
                      child: Text(
                        _canStart ? 'カメラでぺっとーくを始める' : '2つの名前を入力してください',
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                ],
              ),
            );
          },
        ),
      ),
      // 画面最下部バナー
      bottomNavigationBar: const SafeArea(
        child: Padding(
          padding: EdgeInsets.only(bottom: 6),
          child: BannerAdView(),
        ),
      ),
    );
  }

  // ---- UI parts ----
  Widget _label(String text, Color color) => Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 4),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
      );

  Widget _textBox(
      {required TextEditingController controller, required String hint}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 1),
          )
        ],
      ),
      child: TextField(
        controller: controller,
        style: const TextStyle(fontSize: 18),
        decoration: const InputDecoration(
                hintText: '', border: InputBorder.none, isDense: true)
            .copyWith(hintText: hint),
      ),
    );
  }

  Widget _selectTileCompact({
    required String valueText,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 4,
              offset: const Offset(0, 1),
            )
          ],
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 38),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  valueText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.black,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              const Icon(Icons.chevron_right, size: 20, color: Colors.black54),
            ],
          ),
        ),
      ),
    );
  }
}
