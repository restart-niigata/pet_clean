import 'package:flutter/material.dart';
import 'personality_select_page.dart';

class PetNameInputPage extends StatefulWidget {
  final String ownerName;
  final String species;

  const PetNameInputPage({
    super.key,
    required this.ownerName,
    required this.species,
  });

  @override
  State<PetNameInputPage> createState() => _PetNameInputPageState();
}

class _PetNameInputPageState extends State<PetNameInputPage> {
  final TextEditingController _petNameController = TextEditingController();

  @override
  void dispose() {
    _petNameController.dispose();
    super.dispose();
  }

  void _goNext() {
    if (_petNameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ペットの名前を入力してください')),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PersonalitySelectPage(
          ownerName: widget.ownerName,
          petName: _petNameController.text,
          species: widget.species,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.species} の名前入力'),
        centerTitle: true,
        backgroundColor: const Color(0xFF66CCFF),
      ),
      body: Container(
        color: const Color(0xFFE6F7FF),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'ペットの名前を入力してください',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _petNameController,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'ペットの名前',
                filled: true,
                fillColor: Colors.white,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF66CCFF),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onPressed: _goNext,
              child: const Text(
                '次へ',
                style: TextStyle(fontSize: 18, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
