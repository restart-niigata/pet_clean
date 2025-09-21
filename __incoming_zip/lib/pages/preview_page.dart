// lib/pages/preview_page.dart  —— 全差し替え ——
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:screenshot/screenshot.dart';

import '../utils/comments_loader.dart';
import '../widgets/comment_bubble.dart';
import '../widgets/banner_ad_view.dart';
import 'package:pet_clean/utils/ad_manager.dart';

const String _defaultDialect = '標準語';
const Duration _commentVisibleDuration = Duration(seconds: 8); // 表示8秒固定

class PreviewPage extends StatefulWidget {
  // 互換（旧名）
  final String? owner;
  final String? pet;
  // 正式
  final String? ownerName;
  final String? petName;
  final String? species;
  final String? personality;
  final String? dialect;

  const PreviewPage({
    super.key,
    this.owner,
    this.pet,
    this.ownerName,
    this.petName,
    this.species,
    this.personality,
    this.dialect,
  });

  @override
  State<PreviewPage> createState() => _PreviewPageState();
}

class _PreviewPageState extends State<PreviewPage> with WidgetsBindingObserver {
  // ===== カメラ =====
  CameraController? _camera;
  bool _cameraReady = false;
  bool _reinitRequested = false;

  // ===== キャプチャ =====
  final ScreenshotController _ssController = ScreenshotController();
  Uint8List? _lastPng; // 直近撮影画像（共有で使用）
  File? _lastFile;     // 一時ファイル

  // ===== コメント表示 =====
  String _commentText = '';
  bool _showComment = false;
  bool _isLoadingComment = false;
  Timer? _commentHideTimer;   // 表示継続 8秒
  Timer? _nextCommentTimer;   // 次の表示までの間隔

  String get _owner =>
      (widget.ownerName ?? widget.owner ?? '飼い主さん').trim().isEmpty
          ? '飼い主さん'
          : (widget.ownerName ?? widget.owner!) ;

  String get _pet =>
      (widget.petName ?? widget.pet ?? 'ペット').trim().isEmpty
          ? 'ペット'
          : (widget.petName ?? widget.pet!) ;

  String get _species => widget.species ?? '犬';
  String get _personality => widget.personality ?? '元気';
  String get _dialect => widget.dialect ?? _defaultDialect;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initCamera();
    _prepareAds();
    _kickCommentCycle();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _commentHideTimer?.cancel();
    _nextCommentTimer?.cancel();
    _disposeCamera();
    super.dispose();
  }

  // === ライフサイクル：disposeしない。pause/resume のみ ===
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    final cam = _camera;
    if (cam == null) return;

    if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
      if (cam.value.isInitialized) {
        try { await cam.pausePreview(); } catch (_) {}
      }
    } else if (state == AppLifecycleState.resumed) {
      if (cam.value.isInitialized) {
        try { await cam.resumePreview(); } catch (_) { _reinitRequested = true; }
      } else {
        _reinitRequested = true;
      }
      if (_reinitRequested) {
        _reinitRequested = false;
        await _initCamera(force: true);
      }
    }
  }

  Future<void> _disposeCamera() async {
    try { await _camera?.dispose(); } catch (_) {}
    _camera = null;
    _cameraReady = false;
  }

  Future<void> _initCamera({bool force = false}) async {
    if (!force && _camera != null && _camera!.value.isInitialized) return;
    await _disposeCamera();
    try {
      final cameras = await availableCameras();
      final back = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.isNotEmpty ? cameras.first : throw 'No cameras',
      );
      final ctrl = CameraController(
        back,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );
      await ctrl.initialize();
      if (!mounted) return;
      setState(() {
        _camera = ctrl;
        _cameraReady = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _cameraReady = false; // 権限未許可等のときは黒背景
      });
    }
  }

  Future<void> _prepareAds() async {
    // 事前ロード（未ロード時は onPressed 側で自動フォールバック）
    await AdManager.loadInterstitial();
  }

  // ===== コメント制御 =====

  // 次の表示までの間隔（8:35% / 15:30% / 20:25% / 5:5% / 30:5%）
  Duration _nextInterval() {
    final r = (DateTime.now().microsecondsSinceEpoch % 1000) / 1000.0;
    if (r < 0.35) return const Duration(seconds: 8);
    if (r < 0.65) return const Duration(seconds: 15);
    if (r < 0.90) return const Duration(seconds: 20);
    if (r < 0.95) return const Duration(seconds: 5);
    return const Duration(seconds: 30);
  }

  void _kickCommentCycle() {
    _nextCommentTimer?.cancel();
    _showAndScheduleHide(); // まず1回出す（8秒間表示）
    _scheduleNext();        // 次回までの待機
  }

  void _scheduleNext() {
    _nextCommentTimer?.cancel();
    _nextCommentTimer = Timer(_nextInterval(), () {
      _showAndScheduleHide();
      _scheduleNext();
    });
  }

  Future<void> _showAndScheduleHide() async {
    await _loadComment();     // 取得＆表示（_showComment = true）
    _commentHideTimer?.cancel();
    _commentHideTimer = Timer(_commentVisibleDuration, () {
      if (!mounted) return;
      setState(() => _showComment = false); // 8秒で隠す
    });
  }

  Future<void> _loadComment() async {
    if (!mounted) return;
    setState(() {
      _isLoadingComment = true;
      _showComment = false;
    });

    try {
      final text = await CommentsLoader().getComment(
        species: _species,
        personality: _personality,
        owner: _owner,
        pet: _pet,
        dialect: _dialect,
      );
      if (!mounted) return;
      setState(() {
        _commentText = (text.isEmpty) ? '…' : text;
        _showComment = true; // 表示開始
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _commentText = 'コメント読み込みに失敗しました';
        _showComment = true; // 失敗でも8秒表示
      });
    } finally {
      if (mounted) setState(() => _isLoadingComment = false);
    }
  }

  // ===== 一時保存/共有ユーティリティ =====

  Future<File> _writeTempPng(Uint8List data) async {
    final dir = await getTemporaryDirectory();
    final path = '${dir.path}/pet_${DateTime.now().millisecondsSinceEpoch}.png';
    final f = File(path);
    await f.writeAsBytes(data, flush: true);
    return f;
  }

  Future<Uint8List?> _capturePng() async {
    return _ssController.capture(delay: const Duration(milliseconds: 50));
  }

  // ===== ボタン動作（本処理だけ。広告は onPressed 側でラップ） =====

  Future<void> _onCapturePressed() async {
    try {
      final Uint8List? png = await _capturePng();
      if (png == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('撮影に失敗しました')),
        );
        return;
      }
      _lastPng = png;
      _lastFile = await _writeTempPng(png);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('撮影しました。共有から保存できます')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('保存中にエラーが発生しました')),
      );
    }
  }

  Future<void> _onSharePressed() async {
    try {
      File? file = _lastFile;
      if (file == null) {
        final Uint8List? png = await _capturePng(); // 直近が無ければその場で撮る
        if (png == null) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('共有用の画像作成に失敗しました')),
          );
          return;
        }
        _lastPng = png;
        file = await _writeTempPng(png);
        _lastFile = file;
      }
      await Share.shareXFiles([XFile(file.path)], text: '#PetClean');
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('共有に失敗しました')),
      );
    }
  }

  // ===== UI =====

  @override
  Widget build(BuildContext context) {
    final topHintText = '${_pet}を画面内に入れてね';

    final canPreview =
        _camera != null && _cameraReady && _camera!.value.isInitialized;

    return Screenshot(
      controller: _ssController,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Stack(
            children: [
              // 背景：カメラプレビュー（安全にガード）
              Positioned.fill(
                child: canPreview
                    ? CameraPreview(_camera!)
                    : const ColoredBox(color: Colors.black),
              ),

              // 上部ガイド
              Positioned(
                top: 10, left: 16, right: 16,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      topHintText,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),

              // 吹き出し（ガイド直下）
              if (_showComment)
                Positioned(
                  top: 60, left: 16, right: 16,
                  child: _isLoadingComment
                      ? const SizedBox(
                          height: 80,
                          child: Center(child: CircularProgressIndicator()),
                        )
                      : CommentBubble(text: _commentText),
                ),

              // 撮影/共有ボタン（ここで広告→閉じたら本処理）
              Positioned(
                right: 16,
                bottom: 24 + 52, // バナー分の余白
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FloatingActionButton(
                      heroTag: 'capture_fab',
                      onPressed: () async {
                        await AdManager.runWithInterstitial(() async {
                          await _onCapturePressed();
                        });
                      },
                      child: const Icon(Icons.photo_camera),
                    ),
                    const SizedBox(width: 12),
                    FloatingActionButton(
                      heroTag: 'share_fab',
                      onPressed: () async {
                        await AdManager.runWithInterstitial(() async {
                          await _onSharePressed();
                        });
                      },
                      child: const Icon(Icons.ios_share),
                    ),
                  ],
                ),
              ),

              // 最下部バナー
              Align(
                alignment: Alignment.bottomCenter,
                child: const SizedBox(
                  height: 52,
                  child: ColoredBox(
                    color: Colors.black,
                    child: BannerAdView(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
