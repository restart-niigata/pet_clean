import 'package:flutter/material.dart';

import '../models/pet_voice_profile.dart';

class PetVoiceSettingsPage extends StatefulWidget {
  const PetVoiceSettingsPage({super.key, required this.initial});

  final PetVoiceProfile initial;

  @override
  State<PetVoiceSettingsPage> createState() => _PetVoiceSettingsPageState();
}

class _PetVoiceSettingsPageState extends State<PetVoiceSettingsPage> {
  late String _preset;
  late String _firstPerson;
  late String _ending;
  late final TextEditingController _ownerCallController;

  @override
  void initState() {
    super.initState();
    _preset = widget.initial.preset;
    _firstPerson = widget.initial.firstPerson;
    _ending = widget.initial.ending;
    _ownerCallController = TextEditingController(
      text: widget.initial.ownerCall,
    );
  }

  @override
  void dispose() {
    _ownerCallController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final ownerCall = _ownerCallController.text.trim();
    if (ownerCall.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('飼い主の呼び方を入力してください')),
      );
      return;
    }
    final profile = PetVoiceProfile(
      preset: _preset,
      firstPerson: _firstPerson,
      ending: _ending,
      ownerCall: ownerCall,
    );
    await profile.save();
    if (mounted) Navigator.pop(context, profile);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ペットの話し方')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'AIの返事・話しかけ・独り言に使う人格です。',
            style: TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 20),
          DropdownButtonFormField<String>(
            initialValue: _preset,
            decoration: const InputDecoration(
              labelText: '性格プリセット',
              border: OutlineInputBorder(),
            ),
            items: PetVoiceProfile.presetOptions
                .map((value) => DropdownMenuItem(
                      value: value,
                      child: Text(value),
                    ))
                .toList(growable: false),
            onChanged: (value) => setState(() => _preset = value ?? _preset),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _firstPerson,
            decoration: const InputDecoration(
              labelText: '一人称',
              border: OutlineInputBorder(),
            ),
            items: PetVoiceProfile.firstPersonOptions
                .map((value) => DropdownMenuItem(
                      value: value,
                      child: Text(value),
                    ))
                .toList(growable: false),
            onChanged: (value) =>
                setState(() => _firstPerson = value ?? _firstPerson),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _ending,
            decoration: const InputDecoration(
              labelText: '語尾',
              border: OutlineInputBorder(),
            ),
            items: PetVoiceProfile.endingOptions
                .map((value) => DropdownMenuItem(
                      value: value,
                      child: Text(value.isEmpty ? '指定しない' : value),
                    ))
                .toList(growable: false),
            onChanged: (value) => setState(() => _ending = value ?? ''),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _ownerCallController,
            maxLength: 16,
            decoration: const InputDecoration(
              labelText: '飼い主の呼び方',
              hintText: '例：ご主人、ママ、名前',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '気持ちの推測は、画像から想像したエンタメ表現です。病気や体調の診断には使えません。',
            style: TextStyle(fontSize: 13, color: Colors.black54),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.save_outlined),
            label: const Text('保存'),
          ),
        ],
      ),
    );
  }
}
