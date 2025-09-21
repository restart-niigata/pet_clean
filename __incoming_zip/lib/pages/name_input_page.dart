import 'dart:async';
import 'package:flutter/material.dart';
import '../services/ad_service.dart';
import '../services/storage_service.dart';
import 'splash_to_preview.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class NameInputPage extends StatefulWidget {
  const NameInputPage({super.key});
  @override
  State<NameInputPage> createState() => _NameInputPageState();
}

class _NameInputPageState extends State<NameInputPage> {
  final _ownerCtrl = TextEditingController();
  final _petCtrl   = TextEditingController();
  String _species = '犬';
  String _personality = '元気';
  String _dialect = '標準語';

  BannerAd? _banner;
  Timer? _launchAdTimer;

  final _speciesImages = <String, String>{
    '犬': 'assets/images/dog.png',
    '猫': 'assets/images/cat.png',
    'うさぎ': 'assets/images/rabbit.png',
    'ハムスター': 'assets/images/hamster.png',
    '鳥': 'assets/images/bird.png',
    'フェレット': 'assets/images/ferret.png',
    '馬': 'assets/images/horse.png',
    'ウシ': 'assets/images/other_cow.png',
    'ゾウ': 'assets/images/other_elephant.png',
    'サル': 'assets/images/other_monkey.png',
    'パンダ': 'assets/images/other_panda.png',
    'アホロートル': 'assets/images/axolotl.png',
    'フクロモモンガ': 'assets/images/sugar_glider.png',
  };

  final _personalityOptions = const [
    '元気','おっとり','クール','甘えん坊','臆病','おしゃべり','やんちゃ'
  ];
  final _dialectOptions = const [
    '標準語','関西弁','新潟弁','福岡弁','広島弁','福島弁','秋田弁','名古屋弁','金沢弁'
  ];

  @override
  void initState() {
    super.initState();
    _initAdsAndData();
  }

  Future<void> _initAdsAndData() async {
    await AdService.init();
    _banner = AdService.createBanner();
    setState(() {});
    final m = await StorageService.loadAll();
    _ownerCtrl.text = m['owner'] ?? '';
    _petCtrl.text = m['pet'] ?? '';
    _species = m['species'] ?? '犬';
    _personality = m['personality'] ?? '元気';
    _dialect = m['dialect'] ?? '標準語';
    setState(() {});
    AdService.loadInterstitial();
    _launchAdTimer = Timer(const Duration(milliseconds: 900), () {
      AdService.showInterstitialIfReady();
    });
  }

  @override
  void dispose() {
    _launchAdTimer?.cancel();
    _banner?.dispose();
    _ownerCtrl.dispose();
    _petCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickSpecies() async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) {
        final entries = _speciesImages.entries.toList();
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: GridView.builder(
              itemCount: entries.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: .85),
              itemBuilder: (_, i) {
                final e = entries[i];
                return InkWell(
                  onTap: () => Navigator.pop(ctx, e.key),
                  child: Column(
                    children: [
                      Expanded(child: Image.asset(e.value, fit: BoxFit.contain)),
                      const SizedBox(height: 4),
                      Text(e.key, style: const TextStyle(fontSize: 14)),
                    ],
                  ),
                );
              },
            ),
          ),
        );
      },
    );
    if (picked != null) setState(() => _species = picked);
  }

  Future<void> _saveAndStart() async {
    await StorageService.saveAll(
      owner: _ownerCtrl.text.trim(),
      pet: _petCtrl.text.trim(),
      species: _species,
      personality: _personality,
      dialect: _dialect,
    );
    AdService.loadInterstitial(onLoaded: () {
      AdService.showInterstitialIfReady(onDismissed: _goNext);
    });
    AdService.showInterstitialIfReady(onDismissed: _goNext);
  }

  void _goNext() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SplashToPreview(
          owner: _ownerCtrl.text.trim().isEmpty ? 'あなた' : _ownerCtrl.text.trim(),
          pet: _petCtrl.text.trim().isEmpty ? 'ペット' : _petCtrl.text.trim(),
          species: _species,
          personality: _personality,
          dialect: _dialect,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F9FF),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Icon(Icons.info_outline, color: Colors.amber, size: 24),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'あなたとペットちゃんの情報を入れてね',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                      maxLines: 3, softWrap: true, overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 130,
                child: Image.asset('assets/images/app_icon.png', fit: BoxFit.contain),
              ),
              const SizedBox(height: 8),
              Card(
                elevation: 0, color: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    children: [
                      TextField(
                        controller: _ownerCtrl,
                        style: const TextStyle(fontSize: 18),
                        decoration: const InputDecoration(
                          labelText: 'あなたの名前（任意）',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _petCtrl,
                        style: const TextStyle(fontSize: 18),
                        decoration: const InputDecoration(
                          labelText: 'ペットの名前（任意）',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _rowPicker('種類', _species, _pickSpecies),
                      const SizedBox(height: 8),
                      _rowPicker('性格', _personality, () async {
                        final v = await _pickFromList('性格', _personalityOptions, _personality);
                        if (v != null) setState(() => _personality = v);
                      }),
                      const SizedBox(height: 8),
                      _rowPicker('方言', _dialect, () async {
                        final v = await _pickFromList('方言', _dialectOptions, _dialect);
                        if (v != null) setState(() => _dialect = v);
                      }),
                    ],
                  ),
                ),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _saveAndStart,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('開始', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 8),
              if (_banner != null)
                SizedBox(height: 50, child: AdWidget(ad: _banner!)),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _rowPicker(String label, String value, VoidCallback onPressed) {
    return Row(
      children: [
        Text(label, style: const TextStyle(fontSize: 17)),
        const Spacer(),
        FilledButton.tonal(onPressed: onPressed, child: Text(value, style: const TextStyle(fontSize: 16))),
      ],
    );
  }

  Future<String?> _pickFromList(String title, List<String> items, String current) async {
    return showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: ListView.separated(
          shrinkWrap: true,
          itemCount: items.length + 1,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (_, i) {
            if (i == 0) {
              return ListTile(title: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)));
            }
            final v = items[i - 1];
            final sel = v == current;
            return ListTile(
              title: Text(v, style: TextStyle(fontSize: 16, fontWeight: sel ? FontWeight.bold : FontWeight.normal)),
              trailing: sel ? const Icon(Icons.check) : null,
              onTap: () => Navigator.pop(ctx, v),
            );
          },
        ),
      ),
    );
  }
}
