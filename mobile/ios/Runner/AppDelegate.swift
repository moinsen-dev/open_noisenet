import AVFoundation
import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private let backgroundChannelName = "com.opennoisenet.mobile/ios_background"
  private var backgroundChannel: FlutterMethodChannel?
  private var backgroundTasks: [String: UIBackgroundTaskIdentifier] = [:]

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(handleAudioInterruption(_:)),
      name: AVAudioSession.interruptionNotification,
      object: nil
    )
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(handleDidEnterBackground),
      name: UIApplication.didEnterBackgroundNotification,
      object: nil
    )
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(handleDidBecomeActive),
      name: UIApplication.didBecomeActiveNotification,
      object: nil
    )

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    let pluginRegistry = engineBridge.pluginRegistry
    GeneratedPluginRegistrant.register(with: pluginRegistry)

    guard let registrar = pluginRegistry.registrar(forPlugin: "OpenNoiseNetIOSBackground") else {
      return
    }
    backgroundChannel = FlutterMethodChannel(
      name: backgroundChannelName,
      binaryMessenger: registrar.messenger()
    )

    backgroundChannel?.setMethodCallHandler { [weak self] call, result in
      self?.handleBackgroundMethodCall(call: call, result: result)
    }
  }

  deinit {
    NotificationCenter.default.removeObserver(self)
  }

  private func handleBackgroundMethodCall(call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "configureAudioSession":
      configureAudioSession(result: result)
    case "deactivateAudioSession":
      deactivateAudioSession(result: result)
    case "beginBackgroundTask":
      beginBackgroundTask(arguments: call.arguments, result: result)
    case "endBackgroundTask":
      endBackgroundTask(arguments: call.arguments, result: result)
    case "requestBackgroundAppRefresh":
      result(UIApplication.shared.backgroundRefreshStatus != .denied)
    case "getBackgroundAppRefreshStatus":
      result(backgroundRefreshStatusString())
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func configureAudioSession(result: @escaping FlutterResult) {
    do {
      let session = AVAudioSession.sharedInstance()
      try session.setCategory(.playAndRecord, mode: .measurement, options: [.mixWithOthers, .allowBluetooth])
      try session.setActive(true)
      result(true)
    } catch {
      result(
        FlutterError(
          code: "audio_session_config_failed",
          message: "Failed to configure AVAudioSession",
          details: error.localizedDescription
        )
      )
    }
  }

  private func deactivateAudioSession(result: @escaping FlutterResult) {
    do {
      try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
      result(nil)
    } catch {
      result(
        FlutterError(
          code: "audio_session_deactivate_failed",
          message: "Failed to deactivate AVAudioSession",
          details: error.localizedDescription
        )
      )
    }
  }

  private func beginBackgroundTask(arguments: Any?, result: @escaping FlutterResult) {
    let payload = arguments as? [String: Any]
    let taskName = payload?["name"] as? String ?? "OpenNoiseNetSensor"
    let taskId = UUID().uuidString

    var taskIdentifier: UIBackgroundTaskIdentifier = .invalid
    taskIdentifier = UIApplication.shared.beginBackgroundTask(withName: taskName) { [weak self] in
      DispatchQueue.main.async {
        self?.backgroundChannel?.invokeMethod("backgroundTaskExpiring", arguments: ["taskId": taskId])
      }

      if taskIdentifier != .invalid {
        UIApplication.shared.endBackgroundTask(taskIdentifier)
      }
      self?.backgroundTasks.removeValue(forKey: taskId)
    }

    guard taskIdentifier != .invalid else {
      result(
        FlutterError(
          code: "background_task_start_failed",
          message: "Unable to start background task",
          details: taskName
        )
      )
      return
    }

    backgroundTasks[taskId] = taskIdentifier
    result(taskId)
  }

  private func endBackgroundTask(arguments: Any?, result: @escaping FlutterResult) {
    guard
      let payload = arguments as? [String: Any],
      let taskId = payload["taskId"] as? String
    else {
      result(nil)
      return
    }

    if let taskIdentifier = backgroundTasks.removeValue(forKey: taskId) {
      UIApplication.shared.endBackgroundTask(taskIdentifier)
    }

    result(nil)
  }

  private func backgroundRefreshStatusString() -> String {
    switch UIApplication.shared.backgroundRefreshStatus {
    case .available:
      return "available"
    case .denied:
      return "denied"
    case .restricted:
      return "restricted"
    @unknown default:
      return "unknown"
    }
  }

  @objc private func handleAudioInterruption(_ notification: Notification) {
    guard
      let userInfo = notification.userInfo,
      let rawType = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
      let interruptionType = AVAudioSession.InterruptionType(rawValue: rawType)
    else {
      return
    }

    var arguments: [String: Any] = [
      "type": interruptionType == .began ? "began" : "ended"
    ]

    if interruptionType == .ended,
       let rawOptions = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt {
      let options = AVAudioSession.InterruptionOptions(rawValue: rawOptions)
      arguments["shouldResume"] = options.contains(.shouldResume)
    }

    DispatchQueue.main.async { [weak self] in
      self?.backgroundChannel?.invokeMethod("audioSessionInterrupted", arguments: arguments)
    }
  }

  @objc private func handleDidEnterBackground() {
    DispatchQueue.main.async { [weak self] in
      self?.backgroundChannel?.invokeMethod("appWillEnterBackground", arguments: nil)
    }
  }

  @objc private func handleDidBecomeActive() {
    DispatchQueue.main.async { [weak self] in
      self?.backgroundChannel?.invokeMethod("appDidBecomeActive", arguments: nil)
    }
  }
}
