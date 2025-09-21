import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // ← この行が正しく機能するようになる
import 'package:pet_talker_v2/utils/diary_service.dart';

class DiaryAlbumPage extends StatefulWidget {
  const DiaryAlbumPage({super.key});

  @override
  State<DiaryAlbumPage> createState() => _DiaryAlbumPageState();
}

class _DiaryAlbumPageState extends State<DiaryAlbumPage> {
  List<DiaryEntry> _entries = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadEntries();
  }

  Future<void> _loadEntries() async {
    final entries = await DiaryService.instance.loadDiaryEntries();
    if (mounted) {
      setState(() {
        _entries = entries;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('うちの子日記'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _entries.isEmpty
              ? const Center(
                  child: Text(
                    'まだ日記はありません。\nメイン画面で会話を記録してみましょう！',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(8.0),
                  itemCount: _entries.length,
                  itemBuilder: (context, index) {
                    final entry = _entries[index];
                    final formattedDate = DateFormat('M月d日 HH:mm').format(entry.timestamp);

                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 8.0),
                      child: ListTile(
                        leading: const Icon(Icons.article_outlined, color: Colors.orangeAccent),
                        title: Text(entry.comment, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('気分: ${entry.mood}  ($formattedDate)'),
                      ),
                    );
                  },
                ),
    );
  }
}