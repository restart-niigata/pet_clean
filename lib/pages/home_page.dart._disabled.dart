import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../ads/ad_manager.dart';
import 'talk_page.dart';

const speciesImages = <String, String>{
  '犬': 'assets/images/dog.png',
  '猫': 'assets/images/cat.png',
  'うさぎ': 'assets/images/rabbit.png',
  '鳥': 'assets/images/bird.png',
  'ゾウ': 'assets/images/other_elephant.png',
  'ハムスター': 'assets/images/hamster.png',
  'フクロモモンガ': 'assets/images/sugar_glider.png',
  'フェレット': 'assets/images/ferret.png',
  'ウーパールーパー': 'assets/images/axolotl.png',
  '馬': 'assets/images/horse.png',
  'パンダ': 'assets/images/other_panda.png',
  '牛': 'assets/images/other_cow.png',
  'サル': 'assets/images/other_monkey.png',
};

const personalities = [
  '元気','おっとり','クール','甘えん坊','臆病','おしゃべり','やんちゃ'
];

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final ownerCtrl = TextEditingController();
  final petCtrl = TextEditingController();
  String? species;
  String? personality;

  @override
  void initState() {
    super.initState();
    _restore();
    // ★ 起動直後の全画面広告
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AdManager.I.showAppOpenAdIfAvailable();
    });
  }

  Future<void> _restore() async {
    final sp = await SharedPreferences.getInstance();
    ownerCtrl.text = sp.getString('owner') ?? '';
    petCtrl.text = sp.getString('pet') ?? '';
    species = sp.getString('species');
    personality = sp.getString('personality');
    if (mounted) setState(() {});
  }

  Future<void> _save() async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString('owner', ownerCtrl.text);
    await sp.setString('pet', petCtrl.text);
    if (species != null) await sp.setString('species', species!);
    if (personality != null) await sp.setString('personality', personality!);
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: const Color(0xFFF6FBFF),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (_, c) => SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20), // ★下余白大きすぎ調整
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: c.maxHeight - 36),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 上部ロゴ画像
                  Center(
                    child: Image.asset(
                      'assets/images/app_icon.png',
                      width: w * 0.38,
                    ),
                  ),
                  const SizedBox(height: 16),
                  // ★ 上部に説明文（カギカッコなし）
                  const Text(
                    'あなたとペットちゃんの情報を入れてね',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 16),

                  // 入力カード
                  Card(
                    elevation: 0,
                    color: Colors.white,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          TextField(
                            controller: ownerCtrl,
                            decoration: const InputDecoration(
                              labelText: '飼い主さんの名前',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: petCtrl,
                            decoration: const InputDecoration(
                              labelText: 'ペットの名前',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 12),
                          // 種別選択（ボタン→モーダルで画像グリッド）
                          Row(
                            children: [
                              Expanded(
                                child: FilledButton.tonal(
                                  onPressed: _pickSpecies,
                                  child: Text(
                                    species == null ? 'ペットの種類を選ぶ' : '種類: $species',
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          // 性格選択（ボタン→モーダル）
                          Row(
                            children: [
                              Expanded(
                                child: FilledButton.tonal(
                                  onPressed: _pickPersonality,
                                  child: Text(
                                    personality == null ? '性格を選ぶ' : '性格: $personality',
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // 開始ボタン（押下前にインタースティシャル）
                  FilledButton(
                    onPressed: () async {
                      if ((ownerCtrl.text.isEmpty) ||
                          (petCtrl.text.isEmpty) ||
                          (species == null) ||
                          (personality == null)) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('すべて入力・選択してください')),
                        );
                        return;
                      }
                      await _save();
                      await AdManager.I.showInterstitial(afterDismiss: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => TalkPage(
                              ownerName: ownerCtrl.text,
                              petName: petCtrl.text,
                              species: species!,
                              personality: personality!,
                            ),
                          ),
                        );
                      });
                    },
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text('カメラへ', style: TextStyle(fontSize: 18)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _pickSpecies() async {
    final result = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            child: GridView.count(
              crossAxisCount: 3,
              childAspectRatio: .8,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              children: speciesImages.entries.map((e) {
                return InkWell(
                  onTap: () => Navigator.pop(context, e.key),
                  child: Column(
                    children: [
                      Expanded(child: Image.asset(e.value)),
                      const SizedBox(height: 6),
                      Text(e.key),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        );
      },
    );
    if (result != null) setState(() => species = result);
  }

  Future<void> _pickPersonality() async {
    final result = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (_) {
        return SafeArea(
          child: ListView(
            padding: const EdgeInsets.only(bottom: 12),
            children: personalities.map((p) {
              return ListTile(
                title: Text(p, style: const TextStyle(fontWeight: FontWeight.w600)),
                onTap: () => Navigator.pop(context, p),
              );
            }).toList(),
          ),
        );
      },
    );
    if (result != null) setState(() => personality = result);
  }
}
