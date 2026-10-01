import Flutter
import AVFoundation
import Speech
import UIKit
import Vision

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var petPresenceChannel: FlutterMethodChannel?
  private var speechChannel: FlutterMethodChannel?
  private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "ja-JP"))
  private let speechAudioEngine = AVAudioEngine()
  private var speechRequest: SFSpeechAudioBufferRecognitionRequest?
  private var speechTask: SFSpeechRecognitionTask?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    guard let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "PetPresencePlugin") else {
      return
    }
    let channel = FlutterMethodChannel(
      name: "pet_clean/pet_presence",
      binaryMessenger: registrar.messenger()
    )
    channel.setMethodCallHandler { [weak self] call, result in
      guard call.method == "recognizePet" else {
        result(FlutterMethodNotImplemented)
        return
      }
      self?.recognizePet(call: call, result: result)
    }
    petPresenceChannel = channel

    let speech = FlutterMethodChannel(
      name: "pet_clean/speech",
      binaryMessenger: registrar.messenger()
    )
    speech.setMethodCallHandler { [weak self] call, result in
      guard let self else { return }
      switch call.method {
      case "requestPermission":
        self.requestSpeechPermission(result: result)
      case "startListening":
        self.startSpeechRecognition(result: result)
      case "stopListening":
        self.stopSpeechRecognition()
        result(nil)
      case "finishListening":
        self.finishSpeechInput()
        result(nil)
      case "openSettings":
        if let url = URL(string: UIApplication.openSettingsURLString) {
          UIApplication.shared.open(url)
        }
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    speechChannel = speech
  }

  private func requestSpeechPermission(result: @escaping FlutterResult) {
    SFSpeechRecognizer.requestAuthorization { status in
      AVAudioSession.sharedInstance().requestRecordPermission { microphoneGranted in
        DispatchQueue.main.async {
          result(status == .authorized && microphoneGranted)
        }
      }
    }
  }

  private func startSpeechRecognition(result: @escaping FlutterResult) {
    guard SFSpeechRecognizer.authorizationStatus() == .authorized else {
      result(FlutterError(code: "speech_denied", message: "Speech permission is not granted", details: nil))
      return
    }
    guard let recognizer = speechRecognizer, recognizer.isAvailable else {
      result(FlutterError(code: "speech_unavailable", message: "Japanese speech recognition is unavailable", details: nil))
      return
    }

    stopSpeechRecognition()
    let request = SFSpeechAudioBufferRecognitionRequest()
    request.shouldReportPartialResults = true
    request.taskHint = .dictation
    speechRequest = request

    do {
      let session = AVAudioSession.sharedInstance()
      try session.setCategory(
        .playAndRecord,
        mode: .measurement,
        options: [.duckOthers, .defaultToSpeaker, .allowBluetooth]
      )
      try session.setActive(true, options: .notifyOthersOnDeactivation)
      let inputNode = speechAudioEngine.inputNode
      let format = inputNode.outputFormat(forBus: 0)
      guard format.sampleRate > 0 else {
        throw NSError(domain: "PetTalkSpeech", code: 1, userInfo: [NSLocalizedDescriptionKey: "Microphone input is unavailable"])
      }
      inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
        request.append(buffer)
      }
      speechAudioEngine.prepare()
      try speechAudioEngine.start()
    } catch {
      stopSpeechRecognition()
      result(FlutterError(code: "speech_start_failed", message: error.localizedDescription, details: nil))
      return
    }

    speechTask = recognizer.recognitionTask(with: request) { [weak self] recognitionResult, error in
      guard let self else { return }
      if let recognitionResult {
        let transcript = recognitionResult.bestTranscription.formattedString
        DispatchQueue.main.async {
          self.speechChannel?.invokeMethod(
            "speechResult",
            arguments: ["transcript": transcript, "isFinal": recognitionResult.isFinal]
          )
        }
        if recognitionResult.isFinal {
          self.stopSpeechRecognition()
        }
      } else if error != nil {
        let message = error?.localizedDescription ?? "Unknown speech recognition error"
        DispatchQueue.main.async {
          self.speechChannel?.invokeMethod(
            "speechResult",
            arguments: ["transcript": "", "isFinal": true, "error": message]
          )
        }
        self.stopSpeechRecognition()
      }
    }
    result(nil)
  }

  private func stopSpeechRecognition() {
    speechTask?.cancel()
    speechTask = nil
    speechRequest?.endAudio()
    speechRequest = nil
    if speechAudioEngine.isRunning {
      speechAudioEngine.stop()
      speechAudioEngine.inputNode.removeTap(onBus: 0)
    }
    try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
  }

  private func finishSpeechInput() {
    if speechAudioEngine.isRunning {
      speechAudioEngine.stop()
      speechAudioEngine.inputNode.removeTap(onBus: 0)
    }
    speechRequest?.endAudio()
  }

  private func recognizePet(call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard
      let args = call.arguments as? [String: Any],
      let typedData = args["bytes"] as? FlutterStandardTypedData,
      let width = args["width"] as? Int,
      let height = args["height"] as? Int,
      let bytesPerRow = args["bytesPerRow"] as? Int,
      let species = args["species"] as? String,
      width > 0,
      height > 0,
      bytesPerRow >= width * 4,
      typedData.data.count >= bytesPerRow * height,
      let provider = CGDataProvider(data: typedData.data as CFData),
      let image = CGImage(
        width: width,
        height: height,
        bitsPerComponent: 8,
        bitsPerPixel: 32,
        bytesPerRow: bytesPerRow,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGBitmapInfo.byteOrder32Little.union(
          CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedFirst.rawValue)
        ),
        provider: provider,
        decode: nil,
        shouldInterpolate: false,
        intent: .defaultIntent
      )
    else {
      result(FlutterError(code: "invalid_frame", message: "Invalid camera frame", details: nil))
      return
    }

    DispatchQueue.global(qos: .userInitiated).async {
      let aliases = self.speciesAliases(species)
      let handler = VNImageRequestHandler(cgImage: image, orientation: .right)

      if species == "犬" || species == "猫" {
        let request = VNRecognizeAnimalsRequest()
        do {
          try handler.perform([request])
          let labels = (request.results ?? []).flatMap(\.labels)
          let confidence = labels
            .filter { aliases.contains($0.identifier.lowercased()) }
            .map(\.confidence)
            .max() ?? 0
          DispatchQueue.main.async {
            result(["present": confidence >= 0.22, "confidence": confidence])
          }
        } catch {
          DispatchQueue.main.async {
            result(FlutterError(code: "vision_failed", message: error.localizedDescription, details: nil))
          }
        }
        return
      }

      let request = VNClassifyImageRequest()
      do {
        try handler.perform([request])
        let confidence = (request.results ?? [])
          .filter { observation in
            let identifier = observation.identifier.lowercased()
            return aliases.contains { identifier.contains($0) }
          }
          .map(\.confidence)
          .max() ?? 0
        DispatchQueue.main.async {
          result(["present": confidence >= 0.25, "confidence": confidence])
        }
      } catch {
        DispatchQueue.main.async {
          result(FlutterError(code: "vision_failed", message: error.localizedDescription, details: nil))
        }
      }
    }
  }

  private func speciesAliases(_ species: String) -> Set<String> {
    switch species {
    case "犬": return ["dog", "canine", "puppy"]
    case "猫": return ["cat", "feline", "kitten"]
    case "ウサギ": return ["rabbit", "hare", "bunny"]
    case "ハムスター": return ["hamster"]
    case "鳥": return ["bird", "parrot", "finch", "sparrow"]
    case "フクロモモンガ": return ["sugar glider"]
    case "フェレット": return ["ferret"]
    case "ウーパールーパー": return ["axolotl"]
    case "馬": return ["horse", "pony"]
    case "象": return ["elephant"]
    case "パンダ": return ["panda"]
    case "牛": return ["cow", "cattle"]
    case "猿": return ["monkey", "ape"]
    default: return []
    }
  }
}
