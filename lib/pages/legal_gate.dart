// lib/pages/legal_gate.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

/// アプリ本体 [child] の上に「同意レイヤー」を被せるだけのゲート。
/// 同意が済んでいれば何も出さず、未同意なら全画面の同意 UI を表示。
class LegalGate extends StatefulWidget {
  final Widget child;

  const LegalGate({super.key, required this.child});

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
    setState(() {
      _needConsent = !(accepted && ver == _kLegalVersion);
      _loading = false;
    });
  }

  Future<void> _accept() async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kAcceptedKey, true);
    await p.setInt(_kVersionKey, _kLegalVersion);
    await p.setInt(_kAcceptedAtKey, DateTime.now().millisecondsSinceEpoch);
    if (!mounted) return;
    // ここがポイント：Navigator で遷移せず、ただレイヤーを消すだけ
    setState(() => _needConsent = false);
  }

  @override
  Widget build(BuildContext context) {
    // child（TopPage等）は常に描画。上から必要なら同意レイヤーを重ねる。
    return Stack(
      children: [
        widget.child,
        if (!_loading && _needConsent) const _ConsentOverlay(),
        if (_loading)
          const ColoredBox(
            color: Colors.black54,
            child: Center(child: CircularProgressIndicator()),
          ),
      ],
    );
  }
}

/// 全画面の同意 UI（会社名・リンク・チェック → ボタン有効）
/// ※ _accept は上位 State にあるので、簡易的に InheritedWidget で渡すより
///   コールバックを使わず、Overlay 自体で SharedPreferences を触って完結させる実装にしています。
class _ConsentOverlay extends StatefulWidget {
  const _ConsentOverlay();

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
      final p = await SharedPreferences.getInstance();
      await p.setBool('legal.accepted', true);
      await p.setInt('legal.version', 1);
      await p.setInt('legal.acceptedAt', DateTime.now().millisecondsSinceEpoch);
      if (!mounted) return;
      // 自分自身を消すには、上位 Stack の再ビルドが必要 → 簡易的に
      // 「拒否→表示」「同意→非表示」のフラグを LocalHistory 用に使う代わりに
      // Navigator を触らず、親を再描画させるために setState で透明化 → その後 pop も不要。
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          opaque: false,
          pageBuilder: (_, __, ___) => const _AcceptedPing(),
          transitionDuration: Duration.zero,
          reverseTransitionDuration: Duration.zero,
        ),
      );
    } finally {
      if (mounted) setState(() => _accepting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final maxW = 560.0;

    return ColoredBox(
      color: Colors.black.withOpacity(0.55),
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
                      onPressed: (_checked && !_accepting) ? _doAccept : null,
                      child: _accepting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
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
    );
  }
}

/// 同意直後に親の Stack を再描画させ、ConsentOverlay を消すための“瞬間ページ”
/// （透明・即リプレース戻り）
class _AcceptedPing extends StatefulWidget {
  const _AcceptedPing();

  @override
  State<_AcceptedPing> createState() => _AcceptedPingState();
}

class _AcceptedPingState extends State<_AcceptedPing> {
  @override
  void initState() {
    super.initState();
    // 1フレーム後に戻る（結果として親が再ビルドされ、_needConsent=false の状態で描画）
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Navigator.of(context).pop();
    });
  }

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink(); // 何も描画しない透明ページ
  }
}
