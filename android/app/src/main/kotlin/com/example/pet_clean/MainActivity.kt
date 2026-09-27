package com.example.pet_clean

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Bundle
import android.provider.Settings
import android.speech.RecognitionListener
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    companion object {
        private const val SPEECH_CHANNEL = "pet_clean/speech"
        private const val REQUEST_RECORD_AUDIO = 7401
    }

    private var channel: MethodChannel? = null
    private var speechRecognizer: SpeechRecognizer? = null
    private var permissionResult: MethodChannel.Result? = null
    private var latestTranscript = ""
    private var cancelling = false

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        channel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            SPEECH_CHANNEL,
        ).also { methodChannel ->
            methodChannel.setMethodCallHandler { call, result ->
                when (call.method) {
                    "requestPermission" -> requestAudioPermission(result)
                    "startListening" -> startListening(result)
                    "finishListening" -> {
                        speechRecognizer?.stopListening()
                        result.success(null)
                    }
                    "stopListening" -> {
                        cancelRecognition()
                        result.success(null)
                    }
                    "openSettings" -> {
                        openAppSettings()
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
        }
    }

    private fun requestAudioPermission(result: MethodChannel.Result) {
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.RECORD_AUDIO) ==
            PackageManager.PERMISSION_GRANTED
        ) {
            result.success(true)
            return
        }

        permissionResult?.success(false)
        permissionResult = result
        ActivityCompat.requestPermissions(
            this,
            arrayOf(Manifest.permission.RECORD_AUDIO),
            REQUEST_RECORD_AUDIO,
        )
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != REQUEST_RECORD_AUDIO) return
        val granted = grantResults.isNotEmpty() &&
            grantResults[0] == PackageManager.PERMISSION_GRANTED
        permissionResult?.success(granted)
        permissionResult = null
    }

    private fun startListening(result: MethodChannel.Result) {
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.RECORD_AUDIO) !=
            PackageManager.PERMISSION_GRANTED
        ) {
            result.error("microphone_permission", "マイクの使用が許可されていません。", null)
            return
        }
        if (!SpeechRecognizer.isRecognitionAvailable(this)) {
            result.error("speech_unavailable", "この端末では音声認識を利用できません。", null)
            return
        }

        cancelRecognition()
        cancelling = false
        latestTranscript = ""
        speechRecognizer = SpeechRecognizer.createSpeechRecognizer(this).apply {
            setRecognitionListener(createRecognitionListener())
            startListening(Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
                putExtra(
                    RecognizerIntent.EXTRA_LANGUAGE_MODEL,
                    RecognizerIntent.LANGUAGE_MODEL_FREE_FORM,
                )
                putExtra(RecognizerIntent.EXTRA_LANGUAGE, "ja-JP")
                putExtra(RecognizerIntent.EXTRA_LANGUAGE_PREFERENCE, "ja-JP")
                putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, true)
                putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 1)
            })
        }
        result.success(null)
    }

    private fun createRecognitionListener() = object : RecognitionListener {
        override fun onReadyForSpeech(params: Bundle?) = Unit
        override fun onBeginningOfSpeech() = Unit
        override fun onRmsChanged(rmsdB: Float) = Unit
        override fun onBufferReceived(buffer: ByteArray?) = Unit
        override fun onEndOfSpeech() = Unit
        override fun onEvent(eventType: Int, params: Bundle?) = Unit

        override fun onPartialResults(partialResults: Bundle?) {
            sendRecognitionResult(partialResults, false)
        }

        override fun onResults(results: Bundle?) {
            sendRecognitionResult(results, true)
            destroyRecognizer()
        }

        override fun onError(error: Int) {
            if (!cancelling) {
                channel?.invokeMethod(
                    "speechResult",
                    mapOf(
                        "transcript" to latestTranscript,
                        "isFinal" to true,
                        "error" to recognitionErrorMessage(error),
                    ),
                )
            }
            destroyRecognizer()
        }
    }

    private fun sendRecognitionResult(results: Bundle?, isFinal: Boolean) {
        val matches = results?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
        val transcript = matches?.firstOrNull()?.trim().orEmpty()
        if (transcript.isNotEmpty()) latestTranscript = transcript
        channel?.invokeMethod(
            "speechResult",
            mapOf(
                "transcript" to latestTranscript,
                "isFinal" to isFinal,
                "error" to "",
            ),
        )
    }

    private fun recognitionErrorMessage(error: Int): String = when (error) {
        SpeechRecognizer.ERROR_AUDIO -> "マイク音声を取得できませんでした。"
        SpeechRecognizer.ERROR_INSUFFICIENT_PERMISSIONS -> "マイクの使用が許可されていません。"
        SpeechRecognizer.ERROR_NETWORK,
        SpeechRecognizer.ERROR_NETWORK_TIMEOUT -> "音声認識の通信に失敗しました。"
        SpeechRecognizer.ERROR_NO_MATCH -> "言葉を聞き取れませんでした。"
        SpeechRecognizer.ERROR_RECOGNIZER_BUSY -> "音声認識を開始できませんでした。もう一度お試しください。"
        SpeechRecognizer.ERROR_SERVER -> "音声認識サービスに接続できませんでした。"
        SpeechRecognizer.ERROR_SPEECH_TIMEOUT -> "声が聞こえませんでした。"
        else -> "音声認識に失敗しました。"
    }

    private fun cancelRecognition() {
        cancelling = true
        speechRecognizer?.cancel()
        destroyRecognizer()
    }

    private fun destroyRecognizer() {
        speechRecognizer?.destroy()
        speechRecognizer = null
    }

    private fun openAppSettings() {
        startActivity(Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
            data = Uri.parse("package:$packageName")
        })
    }

    override fun onDestroy() {
        permissionResult?.success(false)
        permissionResult = null
        cancelRecognition()
        channel?.setMethodCallHandler(null)
        channel = null
        super.onDestroy()
    }
}
