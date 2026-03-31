package com.gridglance.app

import android.content.Context
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private val dpsChannelName = "gridglance/dps"
    private val dpsPrefsName = "gridglance_widget"
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
        if (intent?.action != "com.gridglance.app.WIDGET_CLICK") {
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
        )
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, dpsChannelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "saveWidgetData" -> {
                        val id = call.argument<String>("id")
                        val data = call.argument<String>("data")
                        if (id == null) {
                            result.error("INVALID_ID", "Missing id", null)
                            return@setMethodCallHandler
                        }
                        val context = applicationContext.createDeviceProtectedStorageContext()
                        val prefs = context.getSharedPreferences(dpsPrefsName, Context.MODE_PRIVATE)
                        val editor = prefs.edit()
                        if (data == null) {
                            editor.remove(id)
                        } else {
                            editor.putString(id, data)
                        }
                        editor.apply()
                        result.success(true)
                    }
                    "getWidgetData" -> {
                        val id = call.argument<String>("id")
                        val defaultValue = call.argument<String>("defaultValue")
                        if (id == null) {
                            result.error("INVALID_ID", "Missing id", null)
                            return@setMethodCallHandler
                        }
                        val context = applicationContext.createDeviceProtectedStorageContext()
                        val prefs = context.getSharedPreferences(dpsPrefsName, Context.MODE_PRIVATE)
                        result.success(prefs.getString(id, defaultValue))
                    }
                    "saveWidgetImage" -> {
                        val id = call.argument<String>("id")
                        val bytes = call.argument<ByteArray>("bytes")
                        if (id == null || bytes == null) {
                            result.error("INVALID_ARGS", "Missing id or bytes", null)
                            return@setMethodCallHandler
                        }
                        val context = applicationContext.createDeviceProtectedStorageContext()
                        val dir = File(context.filesDir, "widget_images")
                        dir.mkdirs()
                        val file = File(dir, "$id.png")
                        file.writeBytes(bytes)
                        val prefs = context.getSharedPreferences(dpsPrefsName, Context.MODE_PRIVATE)
                        prefs.edit().putString(id, file.absolutePath).apply()
                        result.success(file.absolutePath)
                    }
                    else -> result.notImplemented()
                }
            }
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
