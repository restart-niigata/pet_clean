// lib/pages/preview_page.dart
// 撮影画面：コメント循環・方言変換・共有/保存・下部バナー常時表示（全差し替え）

import 'dart:async';
import 'dart:math';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/ad_service.dart';
import '../services/camera_frame_cleanup.dart';
import '../services/local_comment_service.dart';
import '../services/pet_motion_service.dart';
import '../services/pet_talk_ai_service.dart';
import '../services/pet_presence_service.dart';
import '../services/share_file.dart';
import '../services/speech_conversation_service.dart';
import '../widgets/banner_ad_view.dart';

enum _BubbleStyle { speech, thought }

enum _AmbientPace { quiet, balanced, chatty }

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
  bool _cameraAttempted = false;
  bool _cameraInitializing = false;
  String? _cameraError;

  // AI画像判定とコメント制御
  String _comment = '';
  bool _showComment = false;
  _BubbleStyle _bubbleStyle = _BubbleStyle.speech;
  List<String> _comments = const [];
  int _commentIndex = 0;
  Timer? _commentTimer;
  String _visionStatus = 'ペットを画面に入れてね';
  final PetTalkAiService _aiService = PetTalkAiService(
    visionRetryDelay: Duration.zero,
    visionMinimumRequestInterval: Duration.zero,
  );
  final LocalCommentService _localCommentService = const LocalCommentService();
  final PetMotionService _petMotionService = PetMotionService();
  final PetPresenceService _petPresenceService = const PetPresenceService();
  final SpeechConversationService _speechService = SpeechConversationService();
  final Random _random = Random.secure();
  bool _visionBusy = false;
  bool _visionConsentGranted = false;
  bool _visionConsentChecked = false;
  String? _visionClientId;
  bool _presenceCheckBusy = false;
  DateTime? _lastPresenceCheckAt;
  int _consecutivePresenceMisses = 0;
  bool _listening = false;
  bool _replyBusy = false;
  bool _conversationMode = false;
  _AmbientPace _ambientPace = _AmbientPace.balanced;
  int _chattyBurstRemaining = 0;
  bool _motionCommentPending = false;
  DateTime? _lastMotionCommentAt;
  String _observedPetState = '';
  final List<Map<String, String>> _conversationHistory = [];
  // 判定の厳しさはWorker側で調整する（不明は通す）。アプリでは信頼度で再度ふるい落とさない。
  static const double _minimumPetConfidence = 0.0;
  static const int _visionFrameCount = 3;
  static const Duration _visionFrameInterval = Duration(milliseconds: 500);
  static const double _minimumSmallPetConfidence = 0.0;
  static const Set<String> _lenientSmallPets = {
    'フクロモモンガ',
    'ハムスター',
    'フェレット',
    'ウサギ',
  };

  // スクショ/共有
  final _shot = ScreenshotController();
  bool _shareBusy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _commentTimer?.cancel();
    unawaited(_speechService.stop());
    _controller?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    if (state != AppLifecycleState.resumed) {
      _commentTimer?.cancel();
      await _stopPresenceMonitoring();
      return;
    }
    if (state == AppLifecycleState.resumed) {
      if (_controller == null || !_controller!.value.isInitialized) {
        await _initCamera();
      } else if (mounted) {
        setState(() {});
      }
    }
  }

  Future<void> _initCamera() async {
    if (_cameraInitializing) return;
    _cameraInitializing = true;
    final previousController = _controller;
    _controller = null;
    _initFuture = null;
    if (mounted) {
      setState(() {
        _cameraAttempted = false;
        _cameraError = null;
      });
    }
    await previousController?.dispose();
    try {
      final cams = await availableCameras();
      if (cams.isEmpty) {
        throw CameraException('cameraNotFound', '利用可能なカメラがありません');
      }
      final back = cams.firstWhere(
        (e) => e.lensDirection == CameraLensDirection.back,
        orElse: () => cams.first,
      );
      final ctrl = CameraController(
        back,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: defaultTargetPlatform == TargetPlatform.iOS
            ? ImageFormatGroup.bgra8888
            : ImageFormatGroup.yuv420,
      );
      _controller = ctrl;
      _initFuture = ctrl.initialize();
      await _initFuture;
      if (mounted) {
        setState(() {
          _cameraAttempted = true;
          _cameraError = null;
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          unawaited(_ensureVisionConsentAndStart());
        });
      }
    } catch (e) {
      if (!mounted) return;
      debugPrint('Camera initialization failed: $e');
      setState(() {
        _cameraAttempted = true;
        _cameraError = e.toString();
      });
    } finally {
      _cameraInitializing = false;
    }
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

  Future<void> _ensureVisionConsentAndStart({bool forcePrompt = false}) async {
    if (_visionConsentChecked && !forcePrompt) {
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final savedConsent = prefs.getBool('vision.consent.v1');
    var consent = savedConsent;
    if (forcePrompt || savedConsent == null) {
      if (!mounted) return;
      consent = await showDialog<bool>(
            context: context,
            barrierDismissible: false,
            builder: (dialogContext) => AlertDialog(
              title: const Text('AIでペットを判定します'),
              content: const Text(
                'ペットが映っているか判定するため、カメラ画像をCloudflare Workers AIへ送信します。'
                '画像は判定後に保存しません。',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('今は使わない'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  child: const Text('同意して使う'),
                ),
              ],
            ),
          ) ??
          false;
      await prefs.setBool('vision.consent.v1', consent);
    }

    if (!mounted) return;
    _visionConsentChecked = true;
    _visionConsentGranted = consent ?? false;
    setState(() {
      _showComment = false;
      _visionStatus = _visionConsentGranted ? 'ペットを画面に入れてね' : 'AI画像判定はオフです';
    });
    if (!_visionConsentGranted) return;

    _visionClientId = await _loadOrCreateVisionClientId(prefs);
  }

  Future<String> _loadOrCreateVisionClientId(
    SharedPreferences prefs,
  ) async {
    final saved = prefs.getString('vision.clientId.v1');
    if (saved != null && saved.isNotEmpty) return saved;

    final secureRandom = Random.secure();
    final bytes = List<int>.generate(16, (_) => secureRandom.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    final id = '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-'
        '${hex.substring(20)}';
    await prefs.setString('vision.clientId.v1', id);
    return id;
  }

  Future<void> _onDetectPressed() async {
    if (!_aiService.isConfigured) {
      setState(() => _visionStatus = 'AI画像判定が未設定です');
      return;
    }
    if (!_visionConsentGranted) {
      await _ensureVisionConsentAndStart(forcePrompt: true);
    }
    if (_visionConsentGranted) await _detectPet();
  }

  Future<void> _detectPet() async {
    await _stopPresenceMonitoring();
    final controller = _controller;
    final clientId = _visionClientId;
    if (_visionBusy ||
        !_visionConsentGranted ||
        clientId == null ||
        controller == null ||
        !controller.value.isInitialized ||
        controller.value.isTakingPicture) {
      return;
    }

    _visionBusy = true;
    _commentTimer?.cancel();
    _conversationMode = false;
    _motionCommentPending = false;
    _lastMotionCommentAt = null;
    _petMotionService.reset();
    _observedPetState = '';
    _conversationHistory.clear();
    final frames = <XFile>[];
    if (mounted) {
      setState(() {
        _showComment = false;
        _visionStatus = 'AIがペットを探しています…';
      });
    }
    try {
      // 姿勢や手ブレで1枚だけ外れることがあるため、0.5秒間隔で3枚送る。
      final frameBytes = <Uint8List>[];
      for (var i = 0; i < _visionFrameCount; i++) {
        if (i > 0) await Future<void>.delayed(_visionFrameInterval);
        if (!mounted) return;
        final frame = await controller.takePicture();
        frames.add(frame);
        frameBytes.add(await frame.readAsBytes());
      }
      final dialect = await _effectiveDialect();
      final result = await _aiService.analyzeImage(
        frames: frameBytes,
        species: widget.species,
        personality: widget.personality,
        dialect: dialect,
        clientId: clientId,
      );
      if (!mounted) return;

      if (result == null) {
        setState(() {
          _comments = const [];
          _showComment = false;
          _visionStatus = switch (_aiService.lastVisionFailure) {
            PetVisionFailure.retryTooSoon => '少し待ってから、もう一度判定してね',
            PetVisionFailure.rateLimited => '判定が続いています。30秒ほど待ってもう一度試してね',
            PetVisionFailure.timeout => 'AI判定に時間がかかっています。もう一度押してね',
            PetVisionFailure.invalidResponse => '画像判定をやり直します。もう一度押してね',
            PetVisionFailure.notConfigured => 'AI画像判定が未設定です',
            _ => 'AI判定に接続できません。通信を確認してもう一度押してね',
          };
        });
      } else if (result.petDetected &&
          result.confidence >=
              (_lenientSmallPets.contains(widget.species)
                  ? _minimumSmallPetConfidence
                  : _minimumPetConfidence)) {
        _observedPetState = result.observedState;
        final comments = await _localCommentService.load(
          species: widget.species,
          personality: widget.personality,
          ownerName: widget.ownerName,
          petName: widget.petName,
        );
        if (!mounted) return;
        if (comments.isEmpty) {
          setState(() {
            _showComment = false;
            _visionStatus = '選択した性格のコメントが見つかりません';
          });
        } else {
          var spokenComments = comments.take(8).toList(growable: false);
          setState(
            () => _visionStatus = dialect == '標準語'
                ? '今の様子にコメントを合わせています…'
                : '今の様子に合う自然な$dialectに整えています…',
          );
          final rewritten = await _aiService.rewriteComments(
            comments: spokenComments,
            species: widget.species,
            personality: widget.personality,
            dialect: dialect,
            observedState: _observedPetState,
            clientId: clientId,
          );
          if (!mounted) return;
          if (rewritten != null) {
            spokenComments = rewritten;
          }
          _startCommentRotation(spokenComments, result.species);
          unawaited(_startPresenceMonitoring());
        }
      } else if (result.detectedSpecies.isNotEmpty) {
        setState(() {
          _comments = const [];
          _comment = '';
          _showComment = false;
          _visionStatus =
              '${result.detectedSpecies}を検出しました。設定は${widget.species}です';
        });
      } else {
        setState(() {
          _comments = const [];
          _comment = '';
          _showComment = false;
          _visionStatus = 'ペットを確認できません。フレームに入れてもう一度判定してね';
        });
      }
    } on Object catch (error) {
      debugPrint('Pet vision detection failed: $error');
      if (mounted) {
        setState(() {
          _comments = const [];
          _showComment = false;
          _visionStatus = '画像を確認できません。もう一度押してください';
        });
      }
    } finally {
      _visionBusy = false;
      for (final frame in frames) {
        try {
          await cleanupCameraFrame(frame.path);
        } on Object catch (error) {
          debugPrint('Temporary camera frame cleanup failed: $error');
        }
      }
      if (mounted) setState(() {});
    }
  }

  Future<void> _startPresenceMonitoring() async {
    final controller = _controller;
    if (controller == null ||
        !controller.value.isInitialized ||
        controller.value.isStreamingImages) {
      return;
    }
    _consecutivePresenceMisses = 0;
    _lastPresenceCheckAt = null;
    _petMotionService.reset();
    try {
      await controller.startImageStream((image) {
        final lastCheck = _lastPresenceCheckAt;
        final now = DateTime.now();
        if (_presenceCheckBusy ||
            (lastCheck != null &&
                now.difference(lastCheck) <
                    const Duration(milliseconds: 1200))) {
          return;
        }
        _lastPresenceCheckAt = now;
        unawaited(_checkPetPresence(image));
      });
      if (mounted) {
        setState(
          () => _visionStatus = widget.species == '犬' || widget.species == '猫'
              ? '${widget.species}を端末内で見守り中'
              : '${widget.species}の動きを端末内で見守り中',
        );
      }
    } on Object catch (error) {
      debugPrint('Local pet presence monitoring failed to start: $error');
    }
  }

  Future<void> _checkPetPresence(CameraImage image) async {
    _presenceCheckBusy = true;
    try {
      if (_petMotionService.detect(image)) {
        _onPetMotionDetected();
      }
      if (widget.species != '犬' && widget.species != '猫') return;

      final present =
          await _petPresenceService.isPresent(image, widget.species);
      if (present == null || !mounted) return;
      if (present) {
        _consecutivePresenceMisses = 0;
        return;
      }

      _consecutivePresenceMisses++;
      if (_consecutivePresenceMisses < 4) return;
      _commentTimer?.cancel();
      setState(() {
        _comments = const [];
        _conversationMode = false;
        _observedPetState = '';
        _conversationHistory.clear();
        _comment = '';
        _showComment = false;
        _visionStatus = 'ペットが画面から外れました。もう一度判定してね';
      });
      unawaited(_stopPresenceMonitoring());
    } finally {
      _presenceCheckBusy = false;
    }
  }

  Future<void> _stopPresenceMonitoring() async {
    final controller = _controller;
    _consecutivePresenceMisses = 0;
    _petMotionService.reset();
    if (controller == null || !controller.value.isStreamingImages) return;
    try {
      await controller.stopImageStream();
    } on Object catch (error) {
      debugPrint('Local pet presence monitoring failed to stop: $error');
    }
  }

  void _startCommentRotation(List<String> rawComments, String species) {
    _commentTimer?.cancel();
    final owner = widget.ownerName.isNotEmpty ? widget.ownerName : '飼い主さん';
    final pet = widget.petName.isNotEmpty ? widget.petName : 'ペット';
    final comments = rawComments
        .map(
          (value) => value
              .replaceAll('{owner}', owner)
              .replaceAll('{pet}', pet)
              .trim(),
        )
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList(growable: false);
    if (comments.isEmpty) return;

    final paceRoll = _random.nextInt(100);
    _ambientPace = paceRoll < 30
        ? _AmbientPace.quiet
        : paceRoll < 72
            ? _AmbientPace.balanced
            : _AmbientPace.chatty;
    _chattyBurstRemaining = 2 + _random.nextInt(4);
    _motionCommentPending = false;

    setState(() {
      _comments = comments;
      _commentIndex = 0;
      _comment = comments.first;
      _bubbleStyle =
          _random.nextInt(4) == 0 ? _BubbleStyle.thought : _BubbleStyle.speech;
      _showComment = true;
      _visionStatus = '$speciesを検出しました';
    });
    _scheduleAmbientHide();
  }

  void _scheduleAmbientHide() {
    _commentTimer?.cancel();
    if (_comments.isEmpty || !mounted) return;
    final displayDuration = Duration(seconds: 5 + _random.nextInt(9));
    _commentTimer = Timer(displayDuration, () {
      if (!mounted) return;
      setState(() => _showComment = false);
      final pauseDuration = _motionCommentPending
          ? Duration(seconds: 2 + _random.nextInt(4))
          : _nextAmbientGap();
      _motionCommentPending = false;
      _commentTimer = Timer(pauseDuration, () {
        if (!mounted || _comments.isEmpty || _conversationMode) return;
        _showNextAmbientComment();
      });
    });
  }

  Duration _nextAmbientGap() {
    // どの話し方でも時々かなり長く黙り、機械的な周期を崩す。
    if (_random.nextInt(100) < 18) {
      return Duration(seconds: 70 + _random.nextInt(111));
    }
    switch (_ambientPace) {
      case _AmbientPace.quiet:
        return Duration(seconds: 45 + _random.nextInt(106));
      case _AmbientPace.balanced:
        return Duration(seconds: 14 + _random.nextInt(43));
      case _AmbientPace.chatty:
        if (_chattyBurstRemaining > 0) {
          _chattyBurstRemaining--;
          return Duration(seconds: 4 + _random.nextInt(10));
        }
        _chattyBurstRemaining = 2 + _random.nextInt(4);
        return Duration(seconds: 28 + _random.nextInt(49));
    }
  }

  void _showNextAmbientComment() {
    if (!mounted || _comments.isEmpty || _conversationMode) return;
    _commentTimer?.cancel();
    setState(() {
      _commentIndex = (_commentIndex + 1) % _comments.length;
      _comment = _comments[_commentIndex];
      _bubbleStyle =
          _random.nextInt(4) == 0 ? _BubbleStyle.thought : _BubbleStyle.speech;
      _showComment = true;
    });
    _scheduleAmbientHide();
  }

  void _onPetMotionDetected() {
    if (!mounted ||
        _comments.isEmpty ||
        _conversationMode ||
        _listening ||
        _replyBusy ||
        _visionBusy) {
      return;
    }
    final now = DateTime.now();
    final last = _lastMotionCommentAt;
    if (last != null && now.difference(last) < const Duration(seconds: 15)) {
      return;
    }
    _lastMotionCommentAt = now;
    if (_showComment) {
      _motionCommentPending = true;
      return;
    }
    _showNextAmbientComment();
  }

  Future<void> _onTalkPressed() async {
    if (_listening) {
      await _speechService.finishListening();
      if (mounted) {
        setState(() => _visionStatus = '音声を認識しています…');
      }
      return;
    }
    // 音声認識はiOSネイティブ実装のみ。Webでは端末設定への誘導が誤案内になる。
    if (kIsWeb) {
      setState(() => _visionStatus = '音声会話はアプリ版で利用できます');
      return;
    }
    if (_comments.isEmpty) {
      setState(() => _visionStatus = '先にペットを判定してね');
      return;
    }

    setState(() => _visionStatus = 'マイク権限を確認しています…');
    final prefs = await SharedPreferences.getInstance();
    var consent = prefs.getBool('voice.consent.v1');
    if (consent != true) {
      if (!mounted) return;
      consent = await showDialog<bool>(
            context: context,
            barrierDismissible: false,
            builder: (dialogContext) => AlertDialog(
              title: const Text('ペットに話しかけます'),
              content: const Text(
                'マイク音声を端末の音声認識機能で文字に変換し、認識した文字だけを'
                'Cloudflare AIへ送って返事を作ります。録音データは保存しません。',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('今は使わない'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  child: const Text('同意して話す'),
                ),
              ],
            ),
          ) ??
          false;
      await prefs.setBool('voice.consent.v1', consent);
    }
    if (consent != true) {
      if (mounted) setState(() => _visionStatus = '音声会話はオフです');
      return;
    }
    if (!await _speechService.requestPermission()) {
      if (!mounted) return;
      setState(() => _visionStatus = 'マイク・音声認識の許可が必要です');
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('音声の許可がオフです'),
          content: const Text(
            '端末の設定で「マイク」と「音声認識」を許可してください。',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('閉じる'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                unawaited(_speechService.openSettings());
              },
              child: const Text('設定を開く'),
            ),
          ],
        ),
      );
      return;
    }

    _commentTimer?.cancel();
    setState(() {
      _listening = true;
      _showComment = false;
      _visionStatus = '話しかけてね…';
    });
    final transcript = await _speechService.listenOnce();
    if (!mounted) return;
    setState(() => _listening = false);
    if (transcript == null || transcript.isEmpty) {
      final speechError = _speechService.lastError;
      if (speechError != null) {
        debugPrint('Speech recognition did not produce text: $speechError');
      }
      _showRetryPrompt();
      return;
    }

    final clientId = _visionClientId;
    if (clientId == null) return;
    setState(() {
      _replyBusy = true;
      _comment = 'うーん…';
      _bubbleStyle = _BubbleStyle.thought;
      _showComment = true;
      _visionStatus = '「${_shortStatusText(transcript)}」に返事を考えています…';
    });
    final reply = await _aiService.generateReply(
      message: transcript,
      species: widget.species,
      personality: widget.personality,
      dialect: await _effectiveDialect(),
      observedState: _observedPetState,
      clientId: clientId,
      history: _conversationHistory,
    );
    if (!mounted) return;
    setState(() => _replyBusy = false);
    if (reply == null) {
      _showRetryPrompt(replyUnavailable: true);
      return;
    }
    _conversationMode = true;
    _conversationHistory.addAll([
      {'role': 'owner', 'content': transcript},
      {'role': 'pet', 'content': reply},
    ]);
    while (_conversationHistory.length > 8) {
      _conversationHistory.removeAt(0);
    }
    _showConversationReply(reply);
  }

  String _shortStatusText(String value) {
    final runes = value.runes.toList(growable: false);
    if (runes.length <= 18) return value;
    return '${String.fromCharCodes(runes.take(18))}…';
  }

  void _showConversationReply(String reply) {
    _commentTimer?.cancel();
    setState(() {
      _comment = reply;
      _bubbleStyle = _BubbleStyle.speech;
      _showComment = true;
      _visionStatus = '${widget.petName.isEmpty ? 'ペット' : widget.petName}からの返事';
    });
    _commentTimer = Timer(Duration(seconds: 8 + _random.nextInt(9)), () {
      if (!mounted) return;
      setState(() {
        _showComment = false;
        _visionStatus = 'マイクを押して続きを話しかけてね';
      });
    });
  }

  void _showRetryPrompt({bool replyUnavailable = false}) {
    _commentTimer?.cancel();
    const hearingPrompts = [
      'なんて言ったの？ もう一度聞かせて',
      'ごめん、よく聞こえなかった。もう一回お願い',
      'もう少し近くで話してくれる？',
      '今の、もう一度言ってほしいな',
    ];
    const replyPrompts = [
      'うまく言葉にできなかった。もう一度話しかけて',
      'ちょっと考えがまとまらなかった。もう一回お願い',
    ];
    final prompts = replyUnavailable ? replyPrompts : hearingPrompts;
    setState(() {
      _comment = prompts[_random.nextInt(prompts.length)];
      _bubbleStyle = _BubbleStyle.speech;
      _showComment = true;
      _visionStatus = replyUnavailable ? '返事を作れませんでした' : 'マイクを押してもう一度話しかけてね';
    });
    _commentTimer = Timer(Duration(seconds: 7 + _random.nextInt(5)), () {
      if (!mounted) return;
      setState(() => _showComment = false);
      if (!_conversationMode && _comments.isNotEmpty) {
        _commentTimer = Timer(_nextAmbientGap(), _showNextAmbientComment);
      }
    });
  }

  String _normalizeDialect(String raw) {
    final s = raw.replaceAll(RegExp(r'\s|　'), '');
    if (s.isEmpty) return '標準語';
    if (RegExp(r'(関西|大阪)').hasMatch(s)) return '関西弁';
    if (RegExp(r'(名古屋|尾張|がね)').hasMatch(s)) return '名古屋弁';
    if (RegExp(r'(標準|共通語)').hasMatch(s)) return '標準語';
    return raw;
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
          child: SizedBox(
              width: previewW, height: previewH, child: CameraPreview(c)),
        ),
      ),
    );
  }

  static const Map<String, String> _speciesAssets = {
    '犬': 'assets/images/dog.png',
    '猫': 'assets/images/cat.png',
    'ウサギ': 'assets/images/rabbit.png',
    'ハムスター': 'assets/images/hamster.png',
    '鳥': 'assets/images/bird.png',
    'フクロモモンガ': 'assets/images/sugar_glider.png',
    'フェレット': 'assets/images/ferret.png',
    'ウーパールーパー': 'assets/images/axolotl.png',
    '馬': 'assets/images/horse.png',
    '象': 'assets/images/other_elephant.png',
    'パンダ': 'assets/images/other_panda.png',
    '牛': 'assets/images/other_cow.png',
    '猿': 'assets/images/other_monkey.png',
  };

  Widget _demoCover() {
    final asset = _speciesAssets[widget.species] ?? 'assets/images/top_pet.png';
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFEAF2FF), Color(0xFFC9DCFF)],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 76),
            child: Image.asset(asset, fit: BoxFit.contain),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.64),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                child: Text(
                  'カメラが使えないため、デモ画像でお試し中です',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ),
          ),
        ],
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

      final ts = DateTime.now()
          .toIso8601String()
          .replaceAll(':', '-')
          .replaceAll('.', '-');

      final prepared = await prepareShareFile(bytes, 'pet_clean_$ts.jpg');

      final ShareResult res = await SharePlus.instance.share(
        ShareParams(
          files: [prepared.file],
          fileNameOverrides: [prepared.savedName],
          downloadFallbackEnabled: true,
        ),
      );

      if (!mounted) return;

      final msg = prepared.persisted
          ? (res.status == ShareResultStatus.success
              ? '保存しました: ${prepared.savedName}'
              : '保存しました（共有はキャンセル）: ${prepared.savedName}')
          : (res.status == ShareResultStatus.success
              ? '共有しました'
              : '共有をキャンセルしました');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      if (res.status == ShareResultStatus.success) {
        unawaited(AdService.maybeShowAfterSuccessfulShare());
      }
    } on Object catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('保存または共有に失敗しました: $error')),
      );
    } finally {
      if (mounted) setState(() => _shareBusy = false);
    }
  }

  Widget _speechBubble(String text, _BubbleStyle style) {
    final bubble = Container(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.sizeOf(context).width * 0.82,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(
          style == _BubbleStyle.thought ? 28 : 18,
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.9)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.14),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: style == _BubbleStyle.thought ? 17 : 18,
          fontWeight: FontWeight.w600,
          color: const Color(0xFF24304A),
        ),
      ),
    );
    return Align(
      alignment: Alignment.topCenter,
      child: Padding(
        padding: const EdgeInsets.only(top: 82),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            bubble,
            if (style == _BubbleStyle.speech)
              Transform.translate(
                offset: const Offset(-34, -7),
                child: Transform.rotate(
                  angle: pi / 4,
                  child: Container(
                    width: 15,
                    height: 15,
                    color: Colors.white.withValues(alpha: 0.94),
                  ),
                ),
              )
            else
              Transform.translate(
                offset: const Offset(-44, -2),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _thoughtDot(12),
                    const SizedBox(width: 5),
                    _thoughtDot(8),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _thoughtDot(double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.94),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.10),
            blurRadius: 4,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final titleText = (widget.petName.isNotEmpty)
        ? '${widget.petName}を画面内に入れてね'
        : 'ペットを画面内に入れてね';
    final cameraReady = _controller?.value.isInitialized ?? false;

    return Scaffold(
      appBar: AppBar(
        title: FittedBox(
          fit: BoxFit.scaleDown, // 折り返し禁止で縮小許可
          alignment: Alignment.centerLeft,
          child: Text(titleText, maxLines: 1),
        ),
        actions: [
          if (_visionConsentChecked && !_visionConsentGranted)
            IconButton(
              tooltip: 'AI画像判定を有効にする',
              onPressed: () => unawaited(
                _ensureVisionConsentAndStart(forcePrompt: true),
              ),
              icon: const Icon(Icons.visibility_outlined),
            ),
          if (_cameraError != null)
            IconButton(
              tooltip: 'カメラを再試行',
              onPressed: _initCamera,
              icon: const Icon(Icons.cameraswitch_outlined),
            ),
        ],
      ),
      body: FutureBuilder<void>(
        future: _initFuture,
        builder: (_, snap) {
          if (!_cameraAttempted &&
              (_controller == null ||
                  snap.connectionState != ConnectionState.done)) {
            return const Center(child: CircularProgressIndicator());
          }
          return Stack(
            fit: StackFit.expand,
            children: [
              Screenshot(
                controller: _shot,
                child: Stack(
                  children: [
                    if (cameraReady) _cameraCover() else _demoCover(),
                    IgnorePointer(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 550),
                        reverseDuration: const Duration(milliseconds: 900),
                        switchInCurve: Curves.easeOutBack,
                        switchOutCurve: Curves.easeInCubic,
                        transitionBuilder: (child, animation) => FadeTransition(
                          opacity: animation,
                          child: ScaleTransition(
                            scale: Tween<double>(begin: 0.92, end: 1).animate(
                              CurvedAnimation(
                                parent: animation,
                                curve: Curves.easeOutCubic,
                              ),
                            ),
                            child: child,
                          ),
                        ),
                        child: _showComment && _comment.isNotEmpty
                            ? KeyedSubtree(
                                key: ValueKey('$_bubbleStyle:$_comment'),
                                child: _speechBubble(_comment, _bubbleStyle),
                              )
                            : const SizedBox.shrink(
                                key: ValueKey('bubble-hidden'),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                left: 16,
                right: 16,
                bottom: 16,
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.68),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 9,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (_visionBusy) ...[
                            const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],
                          Flexible(
                            child: Text(
                              _visionStatus,
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
      bottomNavigationBar: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const BannerAdView(),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed:
                          _visionBusy || !cameraReady ? null : _onDetectPressed,
                      icon: _visionBusy
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.pets),
                      label: Text(_visionBusy ? '判定中…' : 'ペットを判定'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 56,
                    height: 56,
                    child: IconButton.filled(
                      tooltip: _listening ? '聞き取りを止める' : 'ペットに話しかける',
                      onPressed: _replyBusy || _visionBusy
                          ? null
                          : () => unawaited(_onTalkPressed()),
                      icon: _replyBusy
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Icon(_listening ? Icons.stop : Icons.mic),
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 56,
                    height: 56,
                    child: IconButton.filledTonal(
                      tooltip: '写真を保存・共有',
                      onPressed: _shareBusy ? null : _onShare,
                      icon: _shareBusy
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.ios_share),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
