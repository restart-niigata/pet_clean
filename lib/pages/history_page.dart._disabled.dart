import 'package:flutter/material.dart';
import '../storage/history_storage.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  List<String> history = [];

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  void _loadHistory() async {
    final data = await HistoryStorage().getHistory();
    setState(() {
      history = data.reversed.toList();
    });
  }

  void _clearHistory() async {
    await HistoryStorage().clearHistory();
    _loadHistory();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('履歴'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: _clearHistory,
          ),
        ],
      ),
      body: history.isEmpty
          ? const Center(child: Text('履歴がありません'))
          : ListView.builder(
              itemCount: history.length,
              itemBuilder: (context, index) {
                return ListTile(
                  title: Text(history[index]),
                );
              },
            ),
    );
  }
}
