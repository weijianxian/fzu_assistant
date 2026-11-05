import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    if let shortcut = launchOptions?[.shortcutItem] as? UIApplicationShortcutItem {
      AppShortcutBridge.shared.accept(shortcut)
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "FzuAppShortcuts") {
      AppShortcutBridge.shared.attach(to: registrar.messenger())
    }
  }

  override func application(
    _ application: UIApplication,
    performActionFor shortcutItem: UIApplicationShortcutItem,
    completionHandler: @escaping (Bool) -> Void
  ) {
    if AppShortcutBridge.shared.accept(shortcutItem) {
      completionHandler(true)
    } else {
      super.application(
        application,
        performActionFor: shortcutItem,
        completionHandler: completionHandler
      )
    }
  }
}

/// Only forwards an action. Dart Home consumes it after academic login.
final class AppShortcutBridge {
  static let shared = AppShortcutBridge()
  static let campusCodeType = "com.weijx.fzuAssistant.campusCode"
  private var channel: FlutterMethodChannel?
  private var pending: String?
  private var ready = false

  @discardableResult
  func accept(_ item: UIApplicationShortcutItem) -> Bool {
    guard item.type == Self.campusCodeType else { return false }
    if ready, let channel = channel {
      channel.invokeMethod("action", arguments: "campusCode")
    } else {
      pending = "campusCode"
    }
    return true
  }

  func attach(to messenger: FlutterBinaryMessenger) {
    ready = false
    registerShortcut(title: Bundle.main.localizedString(
      forKey: "Campus code", value: "Campus code", table: "InfoPlist"
    ))
    let channel = FlutterMethodChannel(
      name: "com.weijx.fzu_assistant/shortcuts",
      binaryMessenger: messenger
    )
    self.channel = channel
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self = self else { result(nil); return }
      switch call.method {
      case "takePendingAction":
        self.ready = true
        let action = self.pending
        self.pending = nil
        result(action)
      case "setLabels":
        let args = call.arguments as? [String: Any]
        let label = args?["campusCode"] as? String
          ?? Bundle.main.localizedString(forKey: "Campus code", value: "Campus code", table: "InfoPlist")
        self.registerShortcut(title: label)
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private func registerShortcut(title: String) {
    let campusCode = UIApplicationShortcutItem(
      type: Self.campusCodeType,
      localizedTitle: title,
      localizedSubtitle: nil,
      icon: UIApplicationShortcutIcon(systemImageName: "qrcode"),
      userInfo: nil
    )
    let otherItems = (UIApplication.shared.shortcutItems ?? [])
      .filter { $0.type != Self.campusCodeType }
    UIApplication.shared.shortcutItems = [campusCode] + otherItems
  }
}
