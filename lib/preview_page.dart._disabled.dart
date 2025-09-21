import 'package:flutter/material.dart';
import 'talk_page.dart';

class PreviewPage extends StatelessWidget {
  const PreviewPage({
    super.key,
    required this.ownerName,
    required this.petName,
    required this.species,
    required this.personality,
  });

  final String ownerName;
  final String petName;
  final String species;
  final String personality;

  void _goTalk(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TalkPage(
          ownerName: ownerName,
          petName: petName,
          species: species,
          personality: personality,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.lightBlue.shade50,
      appBar: AppBar(
        title: Text(petName), // タイトルはペット名のみ
        backgroundColor: Colors.lightBlue.shade200,
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 背景に top_pet.png を全画面表示
          Image.asset(
            'assets/images/top_pet.png',
            fit: BoxFit.cover,
          ),

          // 半透明のオーバーレイで文字を見やすく
          Container(
            color: Colors.black.withOpacity(0.3),
          ),

          // 中央に情報表示
          Center(
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.85),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('飼い主: $ownerName',
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold)),
                  Text('ペット: $petName',
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold)),
                  Text('種類: $species',
                      style: const TextStyle(fontSize: 14)),
                  Text('性格: $personality',
                      style: const TextStyle(fontSize: 14)),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () => _goTalk(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.lightBlue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 40, vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    child: const Text(
                      'しゃべる画面へ',
                      style: TextStyle(fontSize: 18),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
