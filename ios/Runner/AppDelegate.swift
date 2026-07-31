import Flutter
import UIKit
import workmanager

@main
@objc class AppDelegate: FlutterAppDelegate {
  private let widgetIntentChannelName = "gridglance/widget_intent"
  private let backgroundTaskIdentifier = "com.gridglance.app.favorite-result-sync"

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
