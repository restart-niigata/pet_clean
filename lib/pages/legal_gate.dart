// lib/pages/legal_gate.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

/// アプリ本体 [child] の上に「同意レイヤー」を被せるだけのゲート。
/// 同意が済んでいれば何も出さず、未同意なら全画面の同意 UI を表示。
class LegalGate extends StatefulWidget {
  final Widget child;
  final Future<void> Function()? onAccepted;

  const LegalGate({super.key, required this.child, this.onAccepted});

  @override
  State<LegalGate> createState() => _LegalGateState();
}

class _LegalGateState extends State<LegalGate> {
  // バージョンは文言を更新したら上げる（同意を取り直す用）
  static const _kLegalVersion = 1;
  static const _kAcceptedKey = 'legal.accepted';
  static const _kVersionKey = 'legal.version';
  static const _kAcceptedAtKey = 'legal.acceptedAt';

  bool _loading = true;
  bool _needConsent = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    final accepted = p.getBool(_kAcceptedKey) ?? false;
    final ver = p.getInt(_kVersionKey) ?? 0;
    if (!mounted) return;
    final needConsent = !(accepted && ver == _kLegalVersion);
    setState(() {
      _needConsent = needConsent;
      _loading = false;
    });
    if (!needConsent) await widget.onAccepted?.call();
  }

  Future<void> _accept() async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kAcceptedKey, true);
    await p.setInt(_kVersionKey, _kLegalVersion);
    await p.setInt(_kAcceptedAtKey, DateTime.now().millisecondsSinceEpoch);
    if (!mounted) return;
    setState(() => _needConsent = false);
    await widget.onAccepted?.call();
  }

  @override
  Widget build(BuildContext context) {
    // child（TopPage等）は常に描画。上から必要なら同意レイヤーを重ねる。
    return Stack(
      children: [
        widget.child,
        if (!_loading && _needConsent) _ConsentOverlay(onAccepted: _accept),
        if (_loading)
          const ColoredBox(
            color: Colors.black54,
            child: Center(child: CircularProgressIndicator()),
          ),
      ],
    );
  }
}

/// 全画面の同意 UI（会社名・リンク・チェック → ボタン有効）。
class _ConsentOverlay extends StatefulWidget {
  const _ConsentOverlay({required this.onAccepted});

  final Future<void> Function() onAccepted;

  @override
  State<_ConsentOverlay> createState() => _ConsentOverlayState();
}

class _ConsentOverlayState extends State<_ConsentOverlay> {
  bool _checked = false;
  bool _accepting = false;

  static const _privacyUrl =
      'https://restart-niigata.github.io/petclean-legal/privacy.html';
  static const _termsUrl =
      'https://restart-niigata.github.io/petclean-legal/terms.html';
  static const _mail = 'info@pc-start.net';

  Future<void> _open(String url) async {
    final uri = Uri.parse(url);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _sendMail() async {
    final uri = Uri(
      scheme: 'mailto',
      path: _mail,
      queryParameters: {'subject': '【PetClean】規約・プライバシーについて'},
    );
    await launchUrl(uri);
  }

  Future<void> _doAccept() async {
    setState(() => _accepting = true);
    try {
      await widget.onAccepted();
    } finally {
      if (mounted) setState(() => _accepting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final maxW = 560.0;

    return ColoredBox(
      color: Colors.black.withValues(alpha: 0.55),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxW),
              child: Material(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
                elevation: 8,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('ご利用にあたって',
                          style: theme.textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      const Text(
                        '本アプリの提供者は「株式会社Ｒｅ，ｓｔＡｒｔ」です。\n'
                        'プライバシーポリシーと利用規約をご確認のうえ、同意してください。',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 12,
                        runSpacing: 8,
                        children: [
                          OutlinedButton(
                            onPressed: () => _open(_privacyUrl),
                            child: const Text('プライバシーポリシーを開く'),
                          ),
                          OutlinedButton(
                            onPressed: () => _open(_termsUrl),
                            child: const Text('利用規約を開く'),
                          ),
                          TextButton.icon(
                            onPressed: _sendMail,
                            icon: const Icon(Icons.mail_outline),
                            label: const Text('お問い合わせ'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      CheckboxListTile(
                        value: _checked,
                        onChanged: (v) => setState(() => _checked = v ?? false),
                        title: const Text('上記の内容を確認し、同意します'),
                        controlAffinity: ListTileControlAffinity.leading,
                      ),
                      const SizedBox(height: 4),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: FilledButton(
                          onPressed:
                              (_checked && !_accepting) ? _doAccept : null,
                          child: _accepting
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Text('同意してはじめる'),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '© 株式会社Ｒｅ，ｓｔＡｒｔ',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
