import Flutter
import UIKit
import UserNotifications
import workmanager

@main
@objc class AppDelegate: FlutterAppDelegate {
  private let widgetIntentChannelName = "gridglance/widget_intent"
  private let backgroundTaskIdentifier = "com.gridglance.app.favorite-result-sync"

  /// Widget tap waiting for Flutter to ask for it via `consumeWidgetClick`.
  private var pendingWidgetClick: [String: Any]?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Route notification taps (and foreground presentation) through Flutter
    // so flutter_local_notifications can report them. Set before plugins
    // register, so plugins that wrap the delegate (firebase_messaging) chain
    // onto this one instead of being replaced by it.
    UNUserNotificationCenter.current().delegate = self as? UNUserNotificationCenterDelegate
    GeneratedPluginRegistrant.register(with: self)
    WorkmanagerPlugin.setPluginRegistrantCallback { registry in
      GeneratedPluginRegistrant.register(with: registry)
    }
    WorkmanagerPlugin.registerTask(withIdentifier: backgroundTaskIdentifier)
    UIApplication.shared.setMinimumBackgroundFetchInterval(TimeInterval(60 * 15))
    if let url = launchOptions?[.url] as? URL,
       let click = Self.widgetClick(from: url) {
      pendingWidgetClick = click
    }
    if let widgetIntentMessenger = resolveMessenger(
      pluginKey: "GridGlanceWidgetIntentChannel"
    ) {
      configureWidgetIntentChannel(binaryMessenger: widgetIntentMessenger)
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  override func application(
    _ app: UIApplication,
    open url: URL,
    options: [UIApplication.OpenURLOptionsKey: Any] = [:]
  ) -> Bool {
    if let click = Self.widgetClick(from: url) {
      // Flutter asks for it when the app resumes, as it does on Android.
      pendingWidgetClick = click
      return true
    }
    return super.application(app, open: url, options: options)
  }

  /// Turns `gridglance://widget?type=...&targetId=...` from a widget tap into
  /// the payload `WidgetClickTarget.fromPayload` expects. iOS widgets have no
  /// per-instance id, so `widgetId` is always 0.
  static func widgetClick(from url: URL) -> [String: Any]? {
    guard url.scheme == "gridglance", url.host == "widget",
          let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems,
          let type = items.first(where: { $0.name == "type" })?.value,
          !type.isEmpty
    else {
      return nil
    }
    var click: [String: Any] = ["type": type, "widgetId": 0]
    if let targetId = items.first(where: { $0.name == "targetId" })?.value,
       !targetId.isEmpty {
      click["targetId"] = targetId
    }
    return click
  }

  private func resolveMessenger(pluginKey: String) -> FlutterBinaryMessenger? {
    if let registrar = registrar(forPlugin: pluginKey) {
      return registrar.messenger()
    }
    if let flutterController = window?.rootViewController as? FlutterViewController {
      return flutterController.binaryMessenger
    }
    return nil
  }

  private func configureWidgetIntentChannel(binaryMessenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(
      name: widgetIntentChannelName,
      binaryMessenger: binaryMessenger
    )
    channel.setMethodCallHandler { [weak self] call, result in
      switch call.method {
      case "consumeWidgetClick":
        result(self?.pendingWidgetClick)
        self?.pendingWidgetClick = nil
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }
}
