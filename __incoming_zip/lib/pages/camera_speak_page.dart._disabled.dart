// lib/pages/camera_speak_page.dart
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../services/comment_loader.dart';

class CameraSpeakPage extends StatefulWidget {
  final String ownerName;
  final String petName;
  final String? species;
  final String? personality;

  const CameraSpeakPage({
    super.key,
    required this.ownerName,
    required this.petName,
    this.species,
    this.personality,
  });

  @override
  State<CameraSpeakPage> createState() => _CameraSpeakPageState();
}

class _CameraSpeakPageState extends State<CameraSpeakPage> {
  CameraController? _controller;
  final _tts = FlutterTts();
  bool _ready = false;
  List<String> _pool = const [];

  @override
  void initState() {
    super.initState();
    _initCamera();
    _buildCommentPool();
  }

  Future<void> _initCamera() async {
    try {
      final cams = await availableCameras();
      final back = cams.firstWhere((c) => c.lensDirection == CameraLensDirection.back,
          orElse: () => cams.first);
      _controller = CameraController(back, ResolutionPreset.medium, enableAudio: false);
      await _controller!.initialize();
      if (mounted) setState(() => _ready = true);
    } catch (_) {
      // カメラ不調でも画面は生かす
      if (mounted) setState(() => _ready = false);
    }
  }

  void _buildCommentPool() {
    // ★ 7:3 の配合で、重複なし
    final loader = CommentLoader.instance;
    final fav = loader.pick(personality: widget.personality, species: widget.species);
    final other = loader.pick(personality: null, species: widget.species);

    final favUnique = <String>{...fav};
    final otherUnique = <String>{...other}..removeAll(favUnique);

    final favCount = (favUnique.length * 0.7).round(); // 7割
    final otherCount = (otherUnique.length * 0.3).round();

    final favList = favUnique.take(favCount).toList();
    final otherList = otherUnique.take(otherCount).toList();

    _pool = [...favList, ...otherList];
  }

  Future<void> _speak() async {
    if (_pool.isEmpty) _buildCommentPool();
    if (_pool.isEmpty) return;
    final text = _pool.removeAt(0)
        .replaceAll('{owner}', widget.ownerName.isEmpty ? '飼い主さん' : widget.ownerName)
        .replaceAll('{pet}', widget.petName.isEmpty ? 'ペット' : widget.petName);

    await _tts.setLanguage('ja-JP');
    await _tts.speak(text);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
      setState(() {});
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    _tts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (_ready && _controller != null) CameraPreview(_controller!)
          else Image.asset('assets/images/camera_background.jpg', fit: BoxFit.cover),
          SafeArea(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(64),
                    shape: const StadiumBorder(),
                  ),
                  onPressed: _speak,
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('しゃべって', style: TextStyle(fontSize: 20)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
