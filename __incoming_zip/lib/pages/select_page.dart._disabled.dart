import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final TextEditingController ownerController = TextEditingController();
  final TextEditingController petController = TextEditingController();
  String _selectedSuffix = 'さん';

  final List<String> suffixOptions = ['呼び捨て', 'さん', 'くん', 'ちゃん', 'ママ', 'パパ'];

  @override
  void initState() {
    super.initState();
    _loadCurrentSettings();
  }

  Future<void> _loadCurrentSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      ownerController.text = prefs.getString('ownerName') ?? '';
      petController.text = prefs.getString('petName') ?? '';
      _selectedSuffix = prefs.getString('ownerSuffix') ?? 'さん';
    });
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('ownerName', ownerController.text);
    await prefs.setString('petName', petController.text);
    await prefs.setString('ownerSuffix', _selectedSuffix);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('設定を保存しました')),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('設定')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            TextField(
              controller: ownerController,
              decoration: const InputDecoration(labelText: '飼い主の名前'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: petController,
              decoration: const InputDecoration(labelText: 'ペットの名前'),
            ),
            const SizedBox(height: 24),
            const Text('呼び方を選んでください'),
            Wrap(
              spacing: 8,
              children: suffixOptions.map((option) {
                return ChoiceChip(
                  label: Text(option),
                  selected: _selectedSuffix == option,
                  onSelected: (_) {
                    setState(() {
                      _selectedSuffix = option;
                    });
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _saveSettings,
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );
  }
}
