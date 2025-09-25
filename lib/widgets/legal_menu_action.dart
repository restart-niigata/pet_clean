// lib/widgets/legal_menu_action.dart  ← 全差し替え
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LegalMenuAction extends StatelessWidget {
  const LegalMenuAction({super.key});

  static const _privacyUrl = 'https://restart-niigata.github.io/petclean-legal/privacy.html';
  static const _termsUrl   = 'https://restart-niigata.github.io/petclean-legal/terms.html';
  static const _contact    = 'info@pc-start.net';

  Future<void> _copy(BuildContext context, String text, String label) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$label をコピーしました')));
    }
  }

  Future<void> _resetConsent(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('同意をリセット'),
        content: const Text('次回起動時に同意画面が表示されます。実行しますか？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(_, false), child: const Text('キャンセル')),
          FilledButton(onPressed: () => Navigator.pop(_, true), child: const Text('リセット')),
        ],
      ),
    );
    if (ok == true) {
      final p = await SharedPreferences.getInstance();
      await p.setBool('legal.accepted', false);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('同意をリセットしました')));
      }
    }
  }

  void _openInfoDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('ポリシー / お問い合わせ'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SelectableText('プライバシーポリシー\nhttps://restart-niigata.github.io/petclean-legal/privacy.html'),
            SizedBox(height: 12),
            SelectableText('利用規約\nhttps://restart-niigata.github.io/petclean-legal/terms.html'),
            SizedBox(height: 12),
            SelectableText('お問い合わせ\ninfo@pc-start.net'),
            SizedBox(height: 6),
            Text('※ テキストを長押しでコピーできます。'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => _copy(context, _privacyUrl, 'プライバシーURL'),
            child: const Text('プライバシーURLをコピー'),
          ),
          TextButton(
            onPressed: () => _copy(context, _termsUrl, '規約URL'),
            child: const Text('規約URLをコピー'),
          ),
          TextButton(
            onPressed: () => _copy(context, _contact, 'メールアドレス'),
            child: const Text('メールをコピー'),
          ),
          const SizedBox(width: 8),
          FilledButton(onPressed: () => Navigator.pop(context), child: const Text('閉じる')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return IconTheme(
      data: IconTheme.of(context).copyWith(opacity: 1.0), // 透過で見えない対策
      child: PopupMenuButton<String>(
        icon: const Icon(Icons.more_vert), // 明示アイコン
        tooltip: 'メニュー',
        onSelected: (value) {
          switch (value) {
            case 'privacy':
            case 'terms':
            case 'contact':
              _openInfoDialog(context);
              break;
            case 'reset':
              _resetConsent(context);
              break;
          }
        },
        itemBuilder: (context) => const [
          PopupMenuItem(value: 'privacy', child: Text('プライバシーポリシー')),
          PopupMenuItem(value: 'terms',   child: Text('利用規約')),
          PopupMenuItem(value: 'contact', child: Text('お問い合わせ')),
          PopupMenuDivider(),
          PopupMenuItem(value: 'reset',   child: Text('同意をリセット')),
        ],
      ),
    );
  }
}
