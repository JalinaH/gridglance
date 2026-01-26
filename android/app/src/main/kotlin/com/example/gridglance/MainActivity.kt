package com.example.gridglance

import android.content.Context
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val dpsChannelName = "gridglance/dps"
    private val dpsPrefsName = "gridglance_widget"

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
                    else -> result.notImplemented()
                }
            }
    }
}
