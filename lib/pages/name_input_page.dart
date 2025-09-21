// lib/pages/name_input_page.dart
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/ad_service.dart';
import 'preview_page.dart';
import 'pet_type_select_page.dart';
import 'personality_select_page.dart';
import 'dialect_select_page.dart';

class NameInputPage extends StatefulWidget {
  const NameInputPage({super.key});

  @override
  State<NameInputPage> createState() => _NameInputPageState();
}

class _NameInputPageState extends State<NameInputPage> {
  final _owner = TextEditingController();
  final _pet = TextEditingController();

  String _species = '犬';
  String _personality = '元気';
  String _dialect = '標準語';

  bool _loading = true;

  BannerAd? _banner;
  bool _bannerReady = false;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
    MobileAds.instance.initialize();
    _initBanner();
    AdService.maybeShowLaunchInterstitialOn5th();
  }

  @override
  void dispose() {
    _banner?.dispose();
    _owner.dispose();
    _pet.dispose();
    super.dispose();
  }

  Future<void> _loadPrefs() async {
    final p = await SharedPreferences.getInstance();
    _owner.text = p.getString('ownerName') ?? '';
    _pet.text = p.getString('petName') ?? '';
    _species = p.getString('species') ?? _species;
    _personality = p.getString('personality') ?? _personality;
    _dialect = p.getString('dialect') ?? _dialect;
    setState(() => _loading = false);
  }

  Future<void> _savePrefs() async {
    final p = await SharedPreferences.getInstance();
    await p.setString('ownerName', _owner.text.trim());
    await p.setString('petName', _pet.text.trim());
    await p.setString('species', _species);
    await p.setString('personality', _personality);
    await p.setString('dialect', _dialect);
  }

  void _initBanner() {
    final unitId = AdService.bannerUnitId; // 本番/テストは AdService 側で一元管理
    _banner = BannerAd(
      adUnitId: unitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) => setState(() => _bannerReady = true),
        onAdFailedToLoad: (ad, _) {
          ad.dispose();
          setState(() => _bannerReady = false);
        },
      ),
    )..load();
  }

  // ← 修正ポイント：右側ピルだけをタップ領域に。左の薄い楕円は置かない。
  Widget _rowPicker({
    required String label,
    required String current,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          SizedBox(
            width: 64,
            child: Text(label, style: const TextStyle(fontSize: 16)),
          ),
          const Spacer(),
          InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(22),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFE7ECFF),
                borderRadius: BorderRadius.circular(22),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(current, style: const TextStyle(fontSize: 16)),
                  const SizedBox(width: 8),
                  const Icon(Icons.chevron_right),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickSpecies() async {
    final v = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => PetTypeSelectPage(current: _species)),
    );
    if (v != null) {
      setState(() => _species = v);
      await _savePrefs();
    }
  }

  Future<void> _pickPersonality() async {
    final v = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => PersonalitySelectPage(current: _personality)),
    );
    if (v != null) {
      setState(() => _personality = v);
      await _savePrefs();
    }
  }

  Future<void> _pickDialect() async {
    final v = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => DialectSelectPage(current: _dialect)),
    );
    if (v != null) {
      setState(() => _dialect = v);
      await _savePrefs();
    }
  }

  Future<void> _onStart() async {
    await _savePrefs();
    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PreviewPage(
          ownerName: _owner.text.trim(),
          petName: _pet.text.trim(),
          species: _species,
          personality: _personality,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const bg = Color(0xFFEFF6FF);
    final double bannerH = _bannerReady ? _banner!.size.height.toDouble() : 0.0;

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : Stack(
                children: [
                  Positioned.fill(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.fromLTRB(16, 8, 16, 120.0 + bannerH),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: const [
                              Icon(Icons.info_outline, color: Color(0xFFFFC107)),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'あなたとペットちゃんの情報を入れてね',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Center(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(24),
                              child: Image.asset(
                                'assets/images/app_icon.png',
                                width: 140,
                                height: 140,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Image.asset(
                                  'assets/images/dog.png',
                                  width: 140,
                                  height: 140,
                                  fit: BoxFit.contain,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Column(
                              children: [
                                TextField(
                                  controller: _owner,
                                  decoration: const InputDecoration(
                                    labelText: 'あなたの名前（任意）',
                                    border: OutlineInputBorder(),
                                  ),
                                  textInputAction: TextInputAction.next,
                                  onChanged: (_) => _savePrefs(),
                                ),
                                const SizedBox(height: 12),
                                TextField(
                                  controller: _pet,
                                  decoration: const InputDecoration(
                                    labelText: 'ペットの名前（任意）',
                                    border: OutlineInputBorder(),
                                  ),
                                  onSubmitted: (_) => _onStart(),
                                  onChanged: (_) => _savePrefs(),
                                ),
                                const SizedBox(height: 12),
                                _rowPicker(label: '種類', current: _species, onTap: _pickSpecies),
                                _rowPicker(label: '性格', current: _personality, onTap: _pickPersonality),
                                _rowPicker(label: '方言', current: _dialect, onTap: _pickDialect),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    left: 16,
                    right: 16,
                    bottom: 16.0 + bannerH,
                    child: SizedBox(
                      height: 56,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          shape: const StadiumBorder(),
                          textStyle: const TextStyle(fontSize: 18),
                        ),
                        onPressed: _onStart,
                        child: const Text('開始'),
                      ),
                    ),
                  ),
                  if (_bannerReady)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: SizedBox(
                        height: bannerH,
                        child: AdWidget(ad: _banner!),
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}
