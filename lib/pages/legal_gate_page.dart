// lib/pages/legal_gate.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

/// ポリシー改定したら +1 してください（再同意を促せます）
const int LEGAL_VERSION = 1;

/// child の前に「同意ゲート」を被せるウィジェット
class LegalGate extends StatefulWidget {
  final Widget child;
  const LegalGate({super.key, required this.child});

  @override
  State<LegalGate> createState() => _LegalGateState();
}

class _LegalGateState extends State<LegalGate> {
  bool _loading = true;
  bool _needConsent = false;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    final p = await SharedPreferences.getInstance();
    final accepted = p.getBool('legal.accepted') ?? false;
    final ver = p.getInt('legal.version') ?? 0;
    setState(() {
      _needConsent = !(accepted && ver == LEGAL_VERSION);
      _loading = false;
    });
  }

  /// 子モーダルから呼ばれる：同意保存後に親が状態を更新
  Future<void> _onAccepted() async {
    await _check(); // フラグを再読込 → _needConsent=false になりモーダルが消える
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Material(child: Center(child: CircularProgressIndicator()));
    }
    return Stack(
      children: [
        widget.child,
        if (_needConsent) _LegalFullscreenModal(onAccepted: _onAccepted),
      ],
    );
  }
}

class _LegalFullscreenModal extends StatefulWidget {
  final Future<void> Function() onAccepted;
  const _LegalFullscreenModal({required this.onAccepted});

  @override
  State<_LegalFullscreenModal> createState() => _LegalFullscreenModalState();
}

class _LegalFullscreenModalState extends State<_LegalFullscreenModal> {
  bool _agreeChecked = false;
  bool _saving = false;

  Future<void> _open(String url) async {
    final uri = Uri.parse(url);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _accept() async {
    if (_saving || !_agreeChecked) return;
    setState(() => _saving = true);
    final p = await SharedPreferences.getInstance();
    await p.setBool('legal.accepted', true);
    await p.setInt('legal.version', LEGAL_VERSION);
    await p.setString('legal.acceptedAt', DateTime.now().toIso8601String());
    // 親に「同意したよ」を通知 → 親が再チェックしてモーダルを外す
    await widget.onAccepted();
    if (!mounted) return;
    setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withOpacity(0.55), // 背景をブロック
      child: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Card(
              margin: const EdgeInsets.all(20),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'ご利用前の確認',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        '本アプリ（PetClean）は、株式会社Ｒｅ，ｓｔＡｒｔ が提供します。\n'
                        'ご利用にあたり「プライバシーポリシー」「利用規約」をご確認ください。',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),

                      // ← ここを縦並び・全幅ボタンに変更（読みやすさ改善）
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.privacy_tip_outlined),
                          label: const Text('プライバシーポリシーを開く'),
                          onPressed: () => _open(
                            'https://restart-niigata.github.io/petclean-legal/privacy.html',
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.description_outlined),
                          label: const Text('利用規約を開く'),
                          onPressed: () => _open(
                            'https://restart-niigata.github.io/petclean-legal/terms.html',
                          ),
                        ),
                      ),

                      const SizedBox(height: 8),
                      CheckboxListTile(
                        value: _agreeChecked,
                        onChanged: (v) => setState(() => _agreeChecked = v ?? false),
                        controlAffinity: ListTileControlAffinity.leading,
                        title: const Text('上記に同意します'),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: FilledButton(
                          onPressed: (_agreeChecked && !_saving) ? _accept : null,
                          child: _saving
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Text('同意してはじめる'),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (_) => AlertDialog(
                              title: const Text('同意が必要です'),
                              content: const Text('ご利用には同意が必要です。アプリを終了してください。'),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.of(context).pop(),
                                  child: const Text('閉じる'),
                                ),
                              ],
                            ),
                          );
                        },
                        child: const Text('同意しない'),
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
