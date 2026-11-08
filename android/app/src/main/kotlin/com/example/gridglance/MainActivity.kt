package com.gridglance.app

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val widgetIntentChannelName = "gridglance/widget_intent"
    private var pendingWidgetClick: HashMap<String, String>? = null

    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        super.onCreate(savedInstanceState)
        handleWidgetIntent(intent)
    }

    override fun onNewIntent(intent: android.content.Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleWidgetIntent(intent)
    }

    private fun handleWidgetIntent(intent: android.content.Intent?) {
        if (intent?.action != WidgetInteractions.ACTION_WIDGET_CLICK) {
            return
        }
        val type = intent.getStringExtra("widget_type")
        val widgetId = intent.getIntExtra(
            android.appwidget.AppWidgetManager.EXTRA_APPWIDGET_ID,
            android.appwidget.AppWidgetManager.INVALID_APPWIDGET_ID,
        )
        if (type.isNullOrBlank() || widgetId == android.appwidget.AppWidgetManager.INVALID_APPWIDGET_ID) {
            return
        }
        pendingWidgetClick = hashMapOf(
            "type" to type,
            "widgetId" to widgetId.toString(),
            "targetId" to (intent.getStringExtra(WidgetInteractions.EXTRA_TARGET_ID) ?: ""),
        )
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, widgetIntentChannelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "consumeWidgetClick" -> {
                        val payload = pendingWidgetClick
                        pendingWidgetClick = null
                        result.success(payload)
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
