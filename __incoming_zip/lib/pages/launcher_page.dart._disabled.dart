import 'package:flutter/material.dart';
import 'package:pet_clean/services/comment_loader.dart';
import 'preview_page.dart';

class LauncherPage extends StatefulWidget {
  const LauncherPage({super.key});

  @override
  State<LauncherPage> createState() => _LauncherPageState();
}

class _LauncherPageState extends State<LauncherPage> {
  final _nameCtrl = TextEditingController();
  String? _species;
  String? _personality;

  // ペット候補（ユーザー指定の固定順）
  static const List<String> kSpecies = [
    '犬','猫','ウサギ','ハムスター','鳥（インコ・文鳥など）','フクロモモンガ',
    'フェレット','ウーパールーパー','馬','象','パンダ','牛','猿',
  ];

  // アイコン割当（なければスター）
  IconData _iconFor(String s) {
    switch (s) {
      case '犬': return Icons.pets;
      case '猫': return Icons.pets_outlined;
      case 'ウサギ': return Icons.favorite_border;
      case 'ハムスター': return Icons.adjust;
      case '鳥（インコ・文鳥など）': return Icons.flight;
      case 'フクロモモンガ': return Icons.change_history;
      case 'フェレット': return Icons.filter_vintage;
      case 'ウーパールーパー': return Icons.water;
      case '馬': return Icons.directions_run;
      case '象': return Icons.park;
      case 'パンダ': return Icons.spa;
      case '牛': return Icons.grass;
      case '猿': return Icons.emoji_nature;
      default: return Icons.star_border;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hintStyle = theme.textTheme.bodyMedium?.copyWith(color: Colors.grey);

    // CommentLoader から“性格一覧”を取得（未ロードでも安全に空配列→後で有効化）
    final personalities = CommentLoader.instance.allowedPersonalities;

    return Scaffold(
      appBar: AppBar(title: const Text('ペット設定')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            // 名前（プレースホルダは灰色で、入力で消える）
            TextField(
              controller: _nameCtrl,
              decoration: InputDecoration(
                labelText: '名前',
                hintText: '（未入力可）',
                hintStyle: hintStyle,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            // ペット選択（アイコン付き）
            Text('ペットの種類', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('（指定しない）'),
                  avatar: const Icon(Icons.remove_circle_outline),
                  selected: _species == null,
                  onSelected: (_) => setState(() => _species = null),
                ),
                ...kSpecies.map((s) => ChoiceChip(
                  label: Text(s),
                  avatar: Icon(_iconFor(s)),
                  selected: _species == s,
                  onSelected: (_) => setState(() => _species = s),
                )),
              ],
            ),
            const SizedBox(height: 24),

            // 性格選択（未ロード時でも選べるように、空なら無効化しない実装）
            Text('性格', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            DropdownButtonFormField<String?>(
              value: _personality, // null なら「指定しない」
              items: <DropdownMenuItem<String?>>[
                const DropdownMenuItem<String?>(
                  value: null, child: Text('（指定しない）'),
                ),
                ...personalities.map((p) => DropdownMenuItem<String?>(
                  value: p, child: Text(p),
                )),
              ],
              onChanged: (v) => setState(() => _personality = v),
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),

            const SizedBox(height: 32),
            // 「開始」ボタン（ここでコメントを読み込み→プレビューへ遷移）
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton(
                onPressed: () async {
                  // コメントを確実にロード（assets/comments.json 固定）
                  await CommentLoader.instance.ensureLoaded();
                  if (!context.mounted) return;

                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => PreviewPage(
                        ownerName: _nameCtrl.text.trim().isEmpty ? null : _nameCtrl.text.trim(),
                        species: _species,
                        personality: _personality,
                      ),
                    ),
                  );
                },
                child: const Text('開始'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
