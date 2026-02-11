import Flutter
import UIKit
import workmanager

@main
@objc class AppDelegate: FlutterAppDelegate {
  private let dpsChannelName = "gridglance/dps"
  private let widgetIntentChannelName = "gridglance/widget_intent"
  private let widgetAppGroupId = "group.com.example.gridglance"
  private let backgroundTaskIdentifier = "com.example.gridglance.favorite-result-sync"

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    WorkmanagerPlugin.setPluginRegistrantCallback { registry in
      GeneratedPluginRegistrant.register(with: registry)
    }
    WorkmanagerPlugin.registerTask(withIdentifier: backgroundTaskIdentifier)
    UIApplication.shared.setMinimumBackgroundFetchInterval(TimeInterval(60 * 15))
    if let dpsMessenger = resolveMessenger(pluginKey: "GridGlanceDpsChannel") {
      configureDpsChannel(binaryMessenger: dpsMessenger)
    }
    if let widgetIntentMessenger = resolveMessenger(
      pluginKey: "GridGlanceWidgetIntentChannel"
    ) {
      configureWidgetIntentChannel(binaryMessenger: widgetIntentMessenger)
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
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

  private func configureDpsChannel(binaryMessenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: dpsChannelName, binaryMessenger: binaryMessenger)
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self = self else {
        result(FlutterError(code: "APP_DEALLOCATED", message: "App delegate unavailable", details: nil))
        return
      }
      guard let args = call.arguments as? [String: Any],
            let id = args["id"] as? String else {
        result(FlutterError(code: "INVALID_ID", message: "Missing id", details: nil))
        return
      }
      let defaults = UserDefaults(suiteName: self.widgetAppGroupId) ?? UserDefaults.standard
      switch call.method {
      case "saveWidgetData":
        if let value = args["data"] as? String {
          defaults.set(value, forKey: id)
        } else {
          defaults.removeObject(forKey: id)
        }
        result(true)
      case "getWidgetData":
        let fallback = args["defaultValue"] as? String
        result(defaults.string(forKey: id) ?? fallback)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private func configureWidgetIntentChannel(binaryMessenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(
      name: widgetIntentChannelName,
      binaryMessenger: binaryMessenger
    )
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "consumeWidgetClick":
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }
}
