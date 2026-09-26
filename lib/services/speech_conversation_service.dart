import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class SpeechConversationService {
  SpeechConversationService() {
    _channel.setMethodCallHandler(_handleNativeCall);
  }

  static const _channel = MethodChannel('pet_clean/speech');
  Completer<String?>? _resultCompleter;
  String _latestTranscript = '';
  String? lastError;
  Timer? _autoFinishTimer;

  Future<bool> requestPermission() async {
    try {
      return await _channel.invokeMethod<bool>('requestPermission') ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  Future<void> openSettings() async {
    try {
      await _channel.invokeMethod<void>('openSettings');
    } on Object catch (error) {
      debugPrint('Opening app settings failed: $error');
    }
  }

  Future<String?> listenOnce(
      {Duration timeout = const Duration(seconds: 12)}) async {
    await stop();
    _latestTranscript = '';
    lastError = null;
    final completer = Completer<String?>();
    _resultCompleter = completer;
    try {
      await _channel.invokeMethod<void>('startListening');
      _autoFinishTimer = Timer(
        const Duration(seconds: 6),
        () => unawaited(finishListening()),
      );
    } on Object catch (error) {
      lastError = error.toString();
      debugPrint('Starting speech recognition failed: $error');
      _resultCompleter = null;
      return null;
    }
    return completer.future.timeout(
      timeout,
      onTimeout: () {
        final latest = _latestTranscript.trim();
        _resultCompleter = null;
        unawaited(_stopNative());
        return latest.isEmpty ? null : latest;
      },
    );
  }

  Future<void> stop() async {
    _autoFinishTimer?.cancel();
    await _stopNative();
    final completer = _resultCompleter;
    _resultCompleter = null;
    if (completer != null && !completer.isCompleted) completer.complete(null);
  }

  Future<void> _stopNative() async {
    try {
      await _channel.invokeMethod<void>('stopListening');
    } on Object catch (error) {
      debugPrint('Speech recognition stop failed: $error');
    }
  }

  Future<void> finishListening() async {
    _autoFinishTimer?.cancel();
    try {
      await _channel.invokeMethod<void>('finishListening');
    } on Object catch (error) {
      lastError = error.toString();
      debugPrint('Finishing speech input failed: $error');
    }
  }

  Future<void> _handleNativeCall(MethodCall call) async {
    if (call.method != 'speechResult' || call.arguments is! Map) return;
    final args = call.arguments as Map;
    final isFinal = args['isFinal'] == true;
    final transcript = args['transcript']?.toString().trim() ?? '';
    final error = args['error']?.toString().trim() ?? '';
    if (error.isNotEmpty) lastError = error;
    if (transcript.isNotEmpty) _latestTranscript = transcript;
    if (!isFinal) return;
    _autoFinishTimer?.cancel();
    final completer = _resultCompleter;
    _resultCompleter = null;
    if (completer != null && !completer.isCompleted) {
      final latest = _latestTranscript.trim();
      completer.complete(latest.isEmpty ? null : latest);
    }
  }
}
