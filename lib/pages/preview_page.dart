// lib/pages/preview_page.dart
// 撮影画面：コメント循環・方言変換・共有/保存・下部バナー常時表示（全差し替え）

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../widgets/banner_ad_view.dart';

class PreviewPage extends StatefulWidget {
  final String ownerName;
  final String petName;
  final String species;
  final String personality;
  final String dialect;

  const PreviewPage({
    super.key,
    required this.ownerName,
    required this.petName,
    required this.species,
    required this.personality,
    this.dialect = '標準語',
  });

  @override
  State<PreviewPage> createState() => _PreviewPageState();
}

class _PreviewPageState extends State<PreviewPage> with WidgetsBindingObserver {
  CameraController? _controller;
  Future<void>? _initFuture;

  // コメント制御
  final _rnd = Random();
  String _comment = '';
  bool _showComment = false;
  Timer? _commentTimer;
  Map<String, List<String>>? _commentsByKey;
  bool _commentsTried = false;
  final Set<String> _shownComments = <String>{};
  static const Duration _commentVisible = Duration(seconds: 5);

  // スクショ/共有
  final _shot = ScreenshotController();
  bool _shareBusy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initCamera();
    _startCommentCycle();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _commentTimer?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    if (state == AppLifecycleState.resumed) {
      if (_controller == null || !_controller!.value.isInitialized) {
        await _initCamera();
      } else if (mounted) {
        setState(() {});
      }
    }
  }

  Future<void> _initCamera() async {
    try {
      final cams = await availableCameras();
      final back = cams.firstWhere(
        (e) => e.lensDirection == CameraLensDirection.back,
        orElse: () => cams.first,
      );
      final ctrl = CameraController(
        back,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );
      _controller = ctrl;
      _initFuture = ctrl.initialize();
      await _initFuture;
      if (mounted) setState(() {});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('カメラ初期化エラー: $e')));
    }
  }

  // ---------- comments.json 読み込み ----------
  Future<void> _ensureCommentsLoaded() async {
    if (_commentsByKey != null || _commentsTried) return;
    _commentsTried = true;
    try {
      final raw = await rootBundle.loadString('assets/comments.json');
      final decoded = json.decode(raw);
      final out = <String, List<String>>{};
      if (decoded is Map) {
        for (final entry in decoded.entries) {
          final key = entry.key.toString();
          final list = <String>[];
          final v = entry.value;
          if (v is List) {
            for (final e in v) {
              if (e is Map && e['text'] != null) {
                list.add(e['text'].toString());
              } else if (e is String) {
                list.add(e);
              }
            }
          }
          if (list.isNotEmpty) out[key] = list;
        }
      }
      if (out.isNotEmpty) _commentsByKey = out;
    } catch (_) {/* フォールバックに任せる */}
  }

  Future<String> _effectiveDialect() async {
    var d = _normalizeDialect(widget.dialect);
    if (d != '標準語') return d;
    try {
      final p = await SharedPreferences.getInstance();
      for (final key in const ['dialect', 'selectedDialect', 'dialectName']) {
        final v = (p.getString(key) ?? '').trim();
        if (v.isNotEmpty) return _normalizeDialect(v);
      }
    } catch (_) {}
    return d;
  }

  Future<String> _pickComment() async {
    await _ensureCommentsLoaded();
    final owner = widget.ownerName.isNotEmpty ? widget.ownerName : '飼い主さん';
    final pet = widget.petName.isNotEmpty ? widget.petName : 'ペット';
    final effDialect = await _effectiveDialect();

    if (_commentsByKey != null && _commentsByKey!.isNotEmpty) {
      final keySel = '${widget.species}_${widget.personality}';
      final prefix = '${widget.species}_';
      final sel = _commentsByKey![keySel] ?? const <String>[];
      final others = _commentsByKey!.entries
          .where((e) => e.key.startsWith(prefix) && e.key != keySel)
          .expand((e) => e.value)
          .toList();

      List<String> pool;
      final r = _rnd.nextDouble();
      if (sel.isNotEmpty && (others.isEmpty || r < 0.65)) {
        pool = sel;
      } else if (others.isNotEmpty) {
        pool = others;
      } else {
        pool = _commentsByKey!.values.expand((e) => e).toList();
      }

      final raw = _pickUniqueFrom(pool);
      if (raw != null) {
        final replaced =
            raw.replaceAll('{owner}', owner).replaceAll('{pet}', pet);
        return _applyDialect(replaced, effDialect);
      }
    }
    return _applyDialect('$owner！ $pet といっしょに撮ろう！', effDialect);
  }

  String? _pickUniqueFrom(List<String> pool) {
    if (pool.isEmpty) return null;
    final candidates = pool.where((s) => !_shownComments.contains(s)).toList();
    if (candidates.isEmpty) {
      _shownComments.removeAll(pool);
      candidates.addAll(pool);
    }
    final chosen = candidates[_rnd.nextInt(candidates.length)];
    _shownComments.add(chosen);
    return chosen;
  }

  void _startCommentCycle() async {
    await _showOneComment();
  }

  Future<void> _showOneComment() async {
    _commentTimer?.cancel();
    _comment = await _pickComment();
    if (!mounted) return;
    setState(() => _showComment = true);

    _commentTimer = Timer(_commentVisible, () {
      if (!mounted) return;
      setState(() => _showComment = false);
      final wait = _pickGapAfterHide();
      _commentTimer = Timer(wait, () {
        if (!mounted) return;
        _showOneComment();
      });
    });
  }

  Duration _pickGapAfterHide() {
    final p = _rnd.nextDouble();
    if (p < 0.35) return const Duration(seconds: 5);
    if (p < 0.65) return const Duration(seconds: 10);
    if (p < 0.90) return const Duration(seconds: 15);
    if (p < 0.95) return const Duration(seconds: 2);
    return const Duration(seconds: 30);
  }

  String _normalizeDialect(String raw) {
    final s = raw.replaceAll(RegExp(r'\s|　'), '');
    if (s.isEmpty) return '標準語';
    if (RegExp(r'(関西|大阪)').hasMatch(s)) return '関西弁';
    if (RegExp(r'(名古屋|尾張|がね)').hasMatch(s)) return '名古屋弁';
    if (RegExp(r'(標準|共通語)').hasMatch(s)) return '標準語';
    return raw;
  }

  static final _endPunct = r'(?:[。！!？?]|$)';
  String _applyDialect(String text, String dialect) {
    final d = _normalizeDialect(dialect);
    if (d == '標準語') return text;
    String t = text;
    void rep(String pattern, String r) {
      t = t.replaceAll(RegExp(pattern), r);
    }
    if (d == '関西弁') {
      rep('だよ$_endPunct', 'やで');
      rep('だな$_endPunct', 'やな');
      rep('だろう$_endPunct', 'やろ');
      rep('です$_endPunct', 'やで');
      rep('だ$_endPunct', 'や');
      rep('よ$_endPunct', 'で');
      rep('ね$_endPunct', 'やね');
      rep('かな$_endPunct', 'かなぁ');
    } else if (d == '名古屋弁') {
      rep('だよ$_endPunct', 'だがね');
      rep('だな$_endPunct', 'だがね');
      rep('だろう$_endPunct', 'だがね');
      rep('です$_endPunct', 'だがね');
      rep('だ$_endPunct', 'だがね');
      rep('よ$_endPunct', 'がね');
      rep('ね$_endPunct', 'がね');
      rep('かな$_endPunct', 'かね');
    }
    return t;
  }

  Widget _cameraCover() {
    final c = _controller!;
    final size = c.value.previewSize;
    if (size == null || !c.value.isInitialized) {
      return const ColoredBox(color: Colors.black);
    }
    final double previewW = size.height.toDouble();
    final double previewH = size.width.toDouble();
    return ColoredBox(
      color: Colors.black,
      child: SizedBox.expand(
        child: FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(width: previewW, height: previewH, child: CameraPreview(c)),
        ),
      ),
    );
  }

  Future<void> _onShare() async {
    if (_shareBusy) return;
    setState(() => _shareBusy = true);
    try {
      await _initFuture;
      final Uint8List? bytes = await _shot.capture(pixelRatio: 1.5);
      if (bytes == null) throw 'スクリーンショットに失敗しました';

      final ts = DateTime.now().toIso8601String().replaceAll(':', '-').replaceAll('.', '-');

      final docs = await getApplicationDocumentsDirectory();
      await Directory(docs.path).create(recursive: true);
      final savePath = '${docs.path}/pet_clean_$ts.jpg';
      await File(savePath).writeAsBytes(bytes);

      final tmp = await getTemporaryDirectory();
      final sharePath = '${tmp.path}/pet_clean_$ts.jpg';
      await File(sharePath).writeAsBytes(bytes);

      final ShareResult res =
          await Share.shareXFiles([XFile(sharePath, mimeType: 'image/jpeg')]);

      if (!mounted) return;

      final name = File(savePath).uri.pathSegments.last;
      final msg = (res.status == ShareResultStatus.success)
          ? '保存しました: $name'
          : '保存しました（共有はキャンセル）: $name';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } finally {
      if (mounted) setState(() => _shareBusy = false);
    }
  }

  Widget _speechBubble(String text) {
    return Align(
      alignment: Alignment.topCenter,
      child: Container(
        margin: const EdgeInsets.only(top: 88),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.92),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 8)],
        ),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final titleText = (widget.petName.isNotEmpty)
        ? '${widget.petName}を画面内に入れてね'
        : 'ペットを画面内に入れてね';

    return Scaffold(
      appBar: AppBar(
        title: FittedBox(
          fit: BoxFit.scaleDown, // 折り返し禁止で縮小許可
          alignment: Alignment.centerLeft,
          child: Text(titleText, maxLines: 1),
        ),
      ),
      body: FutureBuilder<void>(
        future: _initFuture,
        builder: (_, snap) {
          if (_controller == null || snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!_controller!.value.isInitialized) {
            return const Center(child: Text('カメラを初期化できませんでした'));
          }
          return Screenshot(
            controller: _shot,
            child: Stack(
              children: [
                _cameraCover(),
                if (_showComment && _comment.isNotEmpty)
                  IgnorePointer(child: _speechBubble(_comment)),
              ],
            ),
          );
        },
      ),

      // ===== 撮影画面 下部：バナー広告 + 共有ボタン（常時表示） =====
      bottomNavigationBar: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // バナー広告（←これが無くなる問題を修正）
            BannerAdView(), // ← 非 const で配置

            const SizedBox(height: 8),

            // 共有ボタン
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: SizedBox(
                height: 56,
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _shareBusy ? null : _onShare,
                  child: _shareBusy
                      ? const SizedBox(
                          width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('共有'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
