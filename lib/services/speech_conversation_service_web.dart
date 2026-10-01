import 'dart:async';
import 'dart:js_interop';

@JS('petTalkSpeech.isSupported')
external bool get _speechSupported;

@JS('petTalkSpeech.start')
external void _startSpeech(JSFunction onResult, JSFunction onError);

@JS('petTalkSpeech.stop')
external void _stopSpeech();

@JS('petTalkSpeech.speak')
external void _speakText(String text);

class SpeechConversationService {
  Completer<String?>? _resultCompleter;
  String _latestTranscript = '';
  JSFunction? _resultCallback;
  JSFunction? _errorCallback;
  String? lastError;

  bool get isAvailable => _speechSupported;

  Future<bool> requestPermission() async => isAvailable;

  Future<void> openSettings() async {}

  Future<String?> listenOnce({
    Duration timeout = const Duration(seconds: 12),
  }) async {
    await stop();
    if (!isAvailable) {
      lastError = 'このブラウザは音声認識に対応していません。';
      return null;
    }
    lastError = null;
    _latestTranscript = '';
    final completer = Completer<String?>();
    _resultCompleter = completer;
    _resultCallback = ((JSString value, JSBoolean isFinal) {
      final transcript = value.toDart.trim();
      if (transcript.isNotEmpty) _latestTranscript = transcript;
      if (!isFinal.toDart) return;
      final active = _resultCompleter;
      _resultCompleter = null;
      if (active != null && !active.isCompleted) {
        active.complete(_latestTranscript.isEmpty ? null : _latestTranscript);
      }
    }).toJS;
    _errorCallback = ((JSString value) {
      lastError = value.toDart;
      final active = _resultCompleter;
      _resultCompleter = null;
      if (active != null && !active.isCompleted) active.complete(null);
    }).toJS;
    _startSpeech(_resultCallback!, _errorCallback!);
    return completer.future.timeout(
      timeout,
      onTimeout: () {
        _stopSpeech();
        _resultCompleter = null;
        return _latestTranscript.isEmpty ? null : _latestTranscript;
      },
    );
  }

  Future<void> finishListening() async => _stopSpeech();

  Future<void> stop() async {
    if (isAvailable) _stopSpeech();
    final active = _resultCompleter;
    _resultCompleter = null;
    if (active != null && !active.isCompleted) active.complete(null);
  }

  Future<void> speak(String text) async {
    if (text.trim().isNotEmpty) _speakText(text.trim());
  }
}
