import 'package:flutter/material.dart';
import 'talk_page.dart';

class StartPage extends StatefulWidget {
  const StartPage({super.key});

  @override
  State<StartPage> createState() => _StartPageState();
}

class _StartPageState extends State<StartPage> {
  final _ownerCtl = TextEditingController();
  final _petCtl = TextEditingController();

  String? _species; // 犬/猫/うさぎ など
  String? _personality; // 性格

  final _speciesOptions = const [
    _Spec(icon: Icons.pets, label: '犬'),
    _Spec(icon: Icons.pets, label: '猫'),
    _Spec(icon: Icons.pets, label: 'うさぎ'),
  ];

  final _personalityOptions = const [
    '元気', 'おとなしい', 'やんちゃ', '甘えん坊', 'マイペース'
  ];

  bool get _canStart =>
      _ownerCtl.text.trim().isNotEmpty &&
      _petCtl.text.trim().isNotEmpty &&
      _species != null &&
      _personality != null;

  @override
  void dispose() {
    _ownerCtl.dispose();
    _petCtl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('スタート')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextField(
              controller: _ownerCtl,
              decoration: InputDecoration(
                labelText: '飼い主名',
                border: border,
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _petCtl,
              decoration: InputDecoration(
                labelText: 'ペット名',
                border: border,
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 16),
            const Text('ペット選択', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            GridView.builder(
              itemCount: _speciesOptions.length,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                childAspectRatio: 1,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
              ),
              itemBuilder: (context, i) {
                final item = _speciesOptions[i];
                final selected = _species == item.label;
                return InkWell(
                  onTap: () => setState(() => _species = item.label),
                  borderRadius: BorderRadius.circular(20),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    decoration: BoxDecoration(
                      color: selected ? Theme.of(context).colorScheme.secondaryContainer : null,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: selected
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).dividerColor,
                        width: selected ? 2 : 1,
                      ),
                    ),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(item.icon, size: 48),
                          const SizedBox(height: 8),
                          Text(item.label, style: const TextStyle(fontSize: 16)),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            const Text('性格選択', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _personalityOptions.map((p) {
                final selected = _personality == p;
                return ChoiceChip(
                  label: Text(p),
                  selected: selected,
                  onSelected: (_) => setState(() => _personality = p),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 56,
              child: FilledButton.icon(
                onPressed: _canStart
                    ? () {
                        Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => TalkPage(
                            endpoint: '', // 今回は未使用
                            ownerName: _ownerCtl.text.trim(),
                            petName: _petCtl.text.trim(),
                            speciesLabel: _species!,
                            personalityLabel: _personality!,
                          ),
                        ));
                      }
                    : null,
                icon: const Icon(Icons.play_arrow),
                label: const Text('開始'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Spec {
  final IconData icon;
  final String label;
  const _Spec({required this.icon, required this.label});
}
