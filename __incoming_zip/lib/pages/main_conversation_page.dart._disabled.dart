import 'dart:io';
import 'dart:math'; // ★★★ この一行を追加しました ★★★
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'dart:ui' as ui;
import 'package:pet_talker_v2/pages/diary_album_page.dart';
import 'package:pet_talker_v2/pages/settings_page.dart';
import 'package:pet_talker_v2/utils/achievement_service.dart';
import 'package:pet_talker_v2/utils/comment_service.dart';
import 'package:pet_talker_v2/utils/diary_service.dart';
import 'package:pet_talker_v2/utils/user_data_service.dart';
import 'package:camera/camera.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:confetti/confetti.dart';

class MainConversationPage extends StatefulWidget {
  final String petType;
  final String personality;
  final String petName;
  final String ownerName;

  const MainConversationPage({
    super.key,
    required this.petType,
    required this.personality,
    required this.petName,
    required this.ownerName,
  });

  @override
  State<MainConversationPage> createState() => _MainConversationPageState();
}

class _MainConversationPageState extends State<MainConversationPage> {
  final _screenshotKey = GlobalKey();
  late ConfettiController _confettiController;

  late String _petType, _personality, _petName, _ownerName;
  String _currentComment = '（下のボタンで話しかけてみてね！）';
  String _currentMood = 'いつも通り';
  
  CameraController? _cameraController;
  bool _isCameraInitialized = false;

  BannerAd? _bannerAd;
  bool _isBannerAdLoaded = false;
  InterstitialAd? _interstitialAd;
  int _commentCount = 0;

  final String _bannerAdUnitId = Platform.isAndroid ? 'ca-app-pub-3940256099942544/6300978111' : 'ca-app-pub-3940256099942544/2934735716';
  final String _interstitialAdUnitId = Platform.isAndroid ? 'ca-app-pub-3940256099942544/1033173712' : 'ca-app-pub-3940256099942544/4411468910';

  final List<String> _moods = [
    'いつも通り', 'ご機嫌さん', '不機嫌', '体調が悪そう', 'ぼーっとしてる', 'さみし気', '甘えん坊',
  ];

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(seconds: 2));
    _initializeData();
    _initializeCamera();
    if (Platform.isAndroid || Platform.isIOS) {
      _loadBannerAd();
      _loadInterstitialAd();
    }
  }

  @override
  void dispose() {
    _confettiController.dispose();
    _cameraController?.dispose();
    _bannerAd?.dispose();
    _interstitialAd?.dispose();
    super.dispose();
  }
  
  void _initializeData(){
    _petType = widget.petType;
    _personality = widget.personality;
    _petName = widget.petName;
    _ownerName = widget.ownerName;
    _generateComment(isInitial: true);
  }
  
  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) return;
      final firstCamera = cameras.first;
      _cameraController = CameraController(firstCamera, ResolutionPreset.high, enableAudio: false);
      await _cameraController!.initialize();
      if (mounted) setState(() => _isCameraInitialized = true);
    } catch (e) { print('カメラの初期化に失敗しました: $e'); }
  }

  void _loadBannerAd() {
    _bannerAd = BannerAd(
      adUnitId: _bannerAdUnitId,
      request: const AdRequest(),
      size: AdSize.banner,
      listener: BannerAdListener(
        onAdLoaded: (ad) { if (mounted) setState(() => _isBannerAdLoaded = true); },
        onAdFailedToLoad: (ad, err) { ad.dispose(); },
      ),
    )..load();
  }
  
  void _loadInterstitialAd() {
    InterstitialAd.load(
      adUnitId: _interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) => _interstitialAd = ad,
        onAdFailedToLoad: (err) {},
      ),
    );
  }
  
  void _showInterstitialAd() {
    if (_interstitialAd == null) return;
    _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) { ad.dispose(); _loadInterstitialAd(); },
      onAdFailedToShowFullScreenContent: (ad, err) { ad.dispose(); _loadInterstitialAd(); },
    );
    _interstitialAd!.show();
    _interstitialAd = null;
  }
  
  Future<void> _loadAndRefreshData() async {
    final userData = await UserDataService.instance.loadUserData();
    if (userData != null && mounted) {
      setState(() {
        _petType = userData.petType;
        _personality = userData.personality;
        _petName = userData.petName;
        _ownerName = userData.ownerName;
      });
    }
  }

  Future<void> _generateComment({bool isInitial = false}) async {
    if (!isInitial) {
      _commentCount++;
      if (_commentCount % 5 == 0) {
        if (Platform.isAndroid || Platform.isIOS) _showInterstitialAd();
      }
    }
    
    final history = await UserDataService.instance.getCommentHistory();
    final newComment = await CommentService.instance.getRandomComment(
      personality: _personality,
      emotion: _currentMood,
      ownerName: _ownerName,
      history: history,
    );
    if(mounted) setState(() => _currentComment = newComment);
    await UserDataService.instance.addCommentToHistory(newComment);
  }

  Future<void> _shareConversation() async {
    try {
      final bool isNewlyUnlocked = await AchievementService.instance.unlockAchievement('share_1');
      if (isNewlyUnlocked && mounted) {
        _confettiController.play();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('🏆 実績「自慢の第一歩」を解除しました！'), duration: Duration(seconds: 3)));
      }

      RenderRepaintBoundary boundary = _screenshotKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      Uint8List pngBytes = byteData!.buffer.asUint8List();

      final directory = await getTemporaryDirectory();
      final imagePath = await File('${directory.path}/pet_talker_shot.png').writeAsBytes(pngBytes);

      await Share.shareXFiles([XFile(imagePath.path)], text: '#うちの子が喋った #ペットーク');
      
    } catch(e) { print('共有に失敗しました: $e'); }
  }

  Future<void> _saveToDiary() async {
    final bool isNewlyUnlocked = await AchievementService.instance.unlockAchievement('first_diary');
    if (isNewlyUnlocked && mounted) {
      _confettiController.play();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('🏆 実績「最初の記録」を解除しました！'), duration: Duration(seconds: 3)));
    }
    
    final newEntry = DiaryEntry(comment: _currentComment, mood: _currentMood, timestamp: DateTime.now());
    await DiaryService.instance.addDiaryEntry(newEntry);
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('日記に記録しました！'), duration: Duration(seconds: 2)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      bottomNavigationBar: _isBannerAdLoaded && _bannerAd != null ? SizedBox(height: _bannerAd!.size.height.toDouble(), width: _bannerAd!.size.width.toDouble(), child: AdWidget(ad: _bannerAd!)) : const SizedBox(height: 50),
      body: Stack(
        children: [
          if (_isCameraInitialized) Positioned.fill(child: FittedBox(fit: BoxFit.cover, child: SizedBox(width: 100, child: CameraPreview(_cameraController!)))) else const Center(child: CircularProgressIndicator()),
          
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirection: pi / 2,
              particleDrag: 0.05,
              emissionFrequency: 0.05,
              numberOfParticles: 20,
              gravity: 0.1,
              shouldLoop: false,
              colors: const [Colors.pink, Colors.red, Colors.yellow, Colors.white],
              createParticlePath: (size) {
                final path = Path();
                path.moveTo(size.width / 2, size.height / 5 * 4);
                path.cubicTo(size.width / 2, size.height / 5 * 3, size.width / 5, size.height / 5 * 2, size.width / 2, size.height / 5 * 2);
                path.cubicTo(size.width / 5 * 4, size.height / 5 * 2, size.width / 2, size.height / 5 * 3, size.width / 2, size.height / 5 * 4);
                return path;
              },
            ),
          ),
          
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  color: Colors.black.withOpacity(0.4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(_petName, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                      Row(
                        children: [
                          IconButton(icon: const Icon(Icons.auto_stories, color: Colors.white), tooltip: '日記を見る', onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (context) => const DiaryAlbumPage()))),
                          IconButton(icon: const Icon(Icons.settings, color: Colors.white), tooltip: '設定', onPressed: () async {
                              final result = await Navigator.of(context).push(MaterialPageRoute(builder: (context) => const SettingsPage()));
                              if (result == true) { _loadAndRefreshData(); }
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Container(
                    alignment: Alignment.center,
                    child: RepaintBoundary(
                      key: _screenshotKey,
                      child: Container(
                        margin: const EdgeInsets.all(24),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                        decoration: BoxDecoration(color: Colors.white.withOpacity(0.9), borderRadius: BorderRadius.circular(20)),
                        child: Text(_currentComment, style: const TextStyle(fontSize: 18, color: Colors.black87), textAlign: TextAlign.center,),
                      ),
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(16.0),
                  color: Colors.black.withOpacity(0.4),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text("今日の気分: ", style: TextStyle(color: Colors.white.withOpacity(0.8))),
                          Theme(
                            data: Theme.of(context).copyWith(canvasColor: Colors.black.withOpacity(0.8)),
                            child: DropdownButton<String>(
                              value: _currentMood,
                              underline: Container(),
                              icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
                              onChanged: (String? newValue) {
                                if (newValue != null) { setState(() => _currentMood = newValue); _generateComment(); }
                              },
                              items: _moods.map<DropdownMenuItem<String>>((String value) => DropdownMenuItem<String>(value: value, child: Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)))).toList(),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          IconButton(icon: const Icon(Icons.book), onPressed: _saveToDiary, tooltip: '日記に記録する', iconSize: 32, style: IconButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white, padding: const EdgeInsets.all(14))),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.refresh),
                              label: const Text('次のセリフ'),
                              onPressed: _generateComment,
                              style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold), backgroundColor: Colors.orangeAccent, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30))),
                            ),
                          ),
                          const SizedBox(width: 12),
                          IconButton(icon: const Icon(Icons.share), onPressed: _shareConversation, tooltip: '共有する', iconSize: 32, style: IconButton.styleFrom(backgroundColor: Colors.blueAccent, foregroundColor: Colors.white, padding: const EdgeInsets.all(14))),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}