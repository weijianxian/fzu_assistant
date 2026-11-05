import Flutter
import UIKit

class SceneDelegate: FlutterSceneDelegate {
  override func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    if let shortcut = connectionOptions.shortcutItem {
      AppShortcutBridge.shared.accept(shortcut)
    }
    super.scene(scene, willConnectTo: session, options: connectionOptions)
  }

  override func windowScene(
    _ windowScene: UIWindowScene,
    performActionFor shortcutItem: UIApplicationShortcutItem,
    completionHandler: @escaping (Bool) -> Void
  ) {
    if AppShortcutBridge.shared.accept(shortcutItem) {
      completionHandler(true)
    } else {
      super.windowScene(
        windowScene,
        performActionFor: shortcutItem,
        completionHandler: completionHandler
      )
    }
  }
}
