import 'package:flutter/material.dart';
import 'package:pet_clean/services/comment_loader.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late Future<void> _initF;

  // 入力値
  final _ownerCtrl = TextEditingController(text: "飼い主さん");
  final _petCtrl = TextEditingController(text: "ポチ");
  String? _species;
  String? _personality;
  bool _starting = false;

  @override
  void initState() {
    super.initState();
    // JSONは最初の1回だけロード
    _initF = CommentLoader.instance.ensureLoaded();
  }

  @override
  void dispose() {
    _ownerCtrl.dispose();
    _petCtrl.dispose();
    super.dispose();
  }

  Widget _speciesItem(String s) {
    final path = CommentLoader.speciesImage(s);
    return Row(
      children: [
        CircleAvatar(
          radius: 14,
          backgroundColor: Colors.grey.shade200,
          child: ClipOval(
            child: Image.asset(
              path,
              width: 24,
              height: 24,
              fit: BoxFit.cover,
              // 画像が無くてもアイコンを出す
              errorBuilder: (_, __, ___) => const Icon(Icons.pets, size: 18),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Flexible(child: Text(s, overflow: TextOverflow.ellipsis)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _initF,
      builder: (ctx, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final personalities = CommentLoader.personalities;
        final speciesList = CommentLoader.allowedSpecies;

        return Scaffold(
          appBar: AppBar(title: const Text("設定")),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              TextField(
                controller: _ownerCtrl,
                decoration: const InputDecoration(labelText: "飼い主名"),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _petCtrl,
                decoration: const InputDecoration(labelText: "ペットの名前"),
              ),
              const SizedBox(height: 12),

              // ペット種類
              DropdownButtonFormField<String>(
                value: _species,
                isExpanded: true,
                decoration: const InputDecoration(labelText: "ペットの種類"),
                items: speciesList
                    .map((s) => DropdownMenuItem<String>(
                          value: s,
                          child: _speciesItem(s),
                        ))
                    .toList(),
                onChanged: (v) => setState(() => _species = v),
              ),
              const SizedBox(height: 12),

              // 性格
              DropdownButtonFormField<String>(
                value: _personality,
                isExpanded: true,
                decoration: const InputDecoration(labelText: "性格"),
                items: personalities
                    .map((p) => DropdownMenuItem<String>(
                          value: p,
                          child: Text(p, overflow: TextOverflow.ellipsis),
                        ))
                    .toList(),
                onChanged: (v) => setState(() => _personality = v),
              ),
              const SizedBox(height: 20),

              // 開始ボタン（多重押下ガード）
              FilledButton(
                onPressed: _starting
                    ? null
                    : () async {
                        if ((_species ?? "").isEmpty || (_personality ?? "").isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("種類と性格を選んでください")),
                          );
                          return;
                        }
                        setState(() => _starting = true);
                        try {
                          await CommentLoader.instance.configure(
                            owner: _ownerCtrl.text.trim(),
                            pet: _petCtrl.text.trim(),
                            species: _species!,
                            personality: _personality!,
                            preferredWeight: 0.7,
                          );
                          if (!mounted) return;
                          Navigator.of(context).pushNamed("/talk"); // 例: ルート名 /talk
                        } finally {
                          if (mounted) setState(() => _starting = false);
                        }
                      },
                child: const Text("開始"),
              ),
            ],
          ),
        );
      },
    );
  }
}
