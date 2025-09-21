import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import '../ads/ad_manager.dart';
import '../services/prefs_service.dart';
import '../services/comment_service.dart';
import 'talk_page.dart';

const Map<String, String> kSpeciesToJsonKey = {
  '犬':'犬','猫':'猫','うさぎ':'ウサギ','鳥':'鳥','ゾウ':'象','ハムスター':'ハムスター',
  'フクロモモンガ':'フクロモモンガ','フェレット':'フェレット','ウーパールーパー':'ウーパールーパー',
  '馬':'馬','パンダ':'パンダ','牛':'牛','サル':'猿',
};

const List<String> kPersonalities = ['元気','おっとり','クール','甘えん坊','臆病','おしゃべり','やんちゃ'];

const List<String> kDialects = [
  '標準語','関西弁','新潟弁','福岡弁','広島弁','福島弁','秋田弁','名古屋弁','金沢弁'
];

class TopPage extends StatefulWidget {
  const TopPage({super.key});
  @override
  State<TopPage> createState() => _TopPageState();
}

class _TopPageState extends State<TopPage> {
  String? _species;
  String? _personality;
  String _name = '';
  String _owner = '';
  String _dialect = '標準語';
  List<CameraDescription>? _cameras;

  @override
  void initState() {
    super.initState();
    _restore();
    availableCameras().then((v){ _cameras = v; });
  }

  Future<void> _restore() async {
    final p = await PrefsService.load();
    setState(() {
      _species = p.species;
      _personality = p.personality;
      _name = p.petName ?? '';
      _owner = p.ownerName ?? '';
      _dialect = p.dialect ?? '標準語';
    });
  }

  Future<void> _save() async {
    await PrefsService.save(
      species: _species,
      personality: _personality,
      petName: _name,
      ownerName: _owner,
      dialect: _dialect,
    );
  }

  Future<void> _pickSpecies() async {
    final sel = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _SpeciesSheet(current: _species),
    );
    if (sel != null) setState(()=>_species = sel);
  }

  Future<void> _pickPersonality() async {
    final sel = await showModalBottomSheet<String>(
      context: context,
      builder: (_) => _PickListSheet(
        title: '性格を選択',
        items: kPersonalities,
        current: _personality,
      ),
    );
    if (sel != null) setState(()=>_personality = sel);
  }

  Future<void> _pickDialect() async {
    final sel = await showModalBottomSheet<String>(
      context: context,
      builder: (_) => _PickListSheet(
        title: 'なまり（方言）を選択',
        items: kDialects,
        current: _dialect,
      ),
    );
    if (sel != null) setState(()=>_dialect = sel);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (c, cons){
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: cons.maxHeight - 28),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      children: [
                        Row(
                          children: [
                            Image.asset('assets/app_icon.png', width: 56, height: 56),
                            const SizedBox(width: 12),
                            Text('あなたとペットちゃんの情報を入れてね', style: Theme.of(context).textTheme.titleLarge),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _RoundedCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _LabeledField(
                                label: '飼い主さんの名前',
                                child: TextField(
                                  controller: TextEditingController(text: _owner),
                                  onChanged: (v)=>_owner=v,
                                  decoration: const InputDecoration(hintText: '例）たろう'),
                                  style: const TextStyle(fontSize: 18),
                                ),
                              ),
                              const SizedBox(height: 8),
                              _LabeledField(
                                label: 'ペットの名前',
                                child: TextField(
                                  controller: TextEditingController(text: _name),
                                  onChanged: (v)=>_name=v,
                                  decoration: const InputDecoration(hintText: '例）ポチ'),
                                  style: const TextStyle(fontSize: 18),
                                ),
                              ),
                              const SizedBox(height: 8),
                              _LabeledField(
                                label: 'ペットの種類',
                                child: FilledButton.tonal(
                                  onPressed: _pickSpecies,
                                  child: Text(_species ?? '選択する'),
                                ),
                              ),
                              const SizedBox(height: 8),
                              _LabeledField(
                                label: '性格',
                                child: FilledButton.tonal(
                                  onPressed: _pickPersonality,
                                  child: Text(_personality ?? '選択する'),
                                ),
                              ),
                              const SizedBox(height: 8),
                              _LabeledField(
                                label: 'なまり（方言）',
                                child: FilledButton.tonal(
                                  onPressed: _pickDialect,
                                  child: Text(_dialect),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () async {
                                  await _save();
                                  CommentService.instance.configure(
                                    species: _species,
                                    personality: _personality,
                                    petName: _name,
                                    ownerName: _owner,
                                    dialect: _dialect,
                                  );
                                  await AdManager.loadInterstitial(); // 開始押下の前ロード
                                  if (!mounted) return;
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => TalkPage(cameras: _cameras),
                                    ),
                                  ).then((_) => AdManager.showInterstitial()); // 遷移タイミングで広告
                                },
                                child: const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 16),
                                  child: Text('カメラを開始', style: TextStyle(fontSize: 20)),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        // 下余白を詰めるための小さめバナー配置スペース（実表示は TalkPage）
                        Container(height: 4),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
      bottomNavigationBar: _BottomAdBar(color: cs.surface),
    );
  }
}

class _RoundedCard extends StatelessWidget {
  const _RoundedCard({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(top: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(padding: const EdgeInsets.all(16), child: child),
    );
  }
}

class _LabeledField extends StatelessWidget {
  const _LabeledField({required this.label, required this.child});
  final String label;
  final Widget child;
  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 6),
      child,
    ]);
  }
}

class _PickListSheet extends StatelessWidget {
  const _PickListSheet({required this.title, required this.items, this.current});
  final String title;
  final List<String> items;
  final String? current;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          ...items.map((e) => ListTile(
                title: Text(e, style: const TextStyle(fontSize: 18)),
                trailing: current == e ? const Icon(Icons.check) : null,
                onTap: () => Navigator.pop(context, e),
              )),
        ]),
      ),
    );
  }
}

class _SpeciesSheet extends StatelessWidget {
  const _SpeciesSheet({this.current});
  final String? current;

  @override
  Widget build(BuildContext context) {
    final entries = kSpeciesToJsonKey.keys.toList();
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('ペットの種類を選択', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            GridView.builder(
              shrinkWrap: true,
              itemCount: entries.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3, childAspectRatio: 0.85, crossAxisSpacing: 8, mainAxisSpacing: 8),
              itemBuilder: (_, i) {
                final sp = entries[i];
                final img = _assetForSpecies(sp);
                final selected = sp == current;
                return InkWell(
                  onTap: ()=>Navigator.pop(context, sp),
                  child: Column(
                    children: [
                      Expanded(
                        child: Stack(
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: selected ? Colors.blue : Colors.grey.shade300, width: 2),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.asset(img, fit: BoxFit.cover, width: double.infinity),
                              ),
                            ),
                            if (selected)
                              const Positioned(right: 6, top: 6, child: Icon(Icons.check_circle, color: Colors.blue, size: 22))
                          ],
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(sp, style: const TextStyle(fontSize: 16)),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  String _assetForSpecies(String sp) {
    switch (sp) {
      case '犬': return 'assets/species/dog.png';
      case '猫': return 'assets/species/cat.png';
      case 'うさぎ': return 'assets/species/rabbit.png';
      case '鳥': return 'assets/species/bird.png';
      case 'ゾウ': return 'assets/species/elephant.png';
      case 'ハムスター': return 'assets/species/hamster.png';
      case 'フクロモモンガ': return 'assets/species/sugar_glider.png';
      case 'フェレット': return 'assets/species/ferret.png';
      case 'ウーパールーパー': return 'assets/species/axolotl.png';
      case '馬': return 'assets/species/horse.png';
      case 'パンダ': return 'assets/species/panda.png';
      case '牛': return 'assets/species/cow.png';
      case 'サル': return 'assets/species/monkey.png';
      default: return 'assets/app_icon.png';
    }
  }
}

class _BottomAdBar extends StatelessWidget {
  const _BottomAdBar({required this.color});
  final Color color;
  @override
  Widget build(BuildContext context) {
    return Container(height: 8, color: color); // 余白詰めのダミー（実広告はTalkPage）
  }
}
