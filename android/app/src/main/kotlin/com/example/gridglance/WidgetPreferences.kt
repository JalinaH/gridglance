package com.gridglance.app

import android.content.Context
import android.content.SharedPreferences
import es.antonborri.home_widget.HomeWidgetPlugin

/**
 * Uses home_widget's engine-registered storage and migrates values written by
 * older GridGlance builds from DeviceProtectedStorage on first access.
 */
object WidgetPreferences {
    private const val legacyPreferencesName = "gridglance_widget"
    private const val migrationKey = "_gridglance_home_widget_migrated"

    fun get(context: Context): SharedPreferences {
        val preferences = HomeWidgetPlugin.getData(context)
        if (!preferences.getBoolean(migrationKey, false)) {
            val legacyContext = context.createDeviceProtectedStorageContext()
            val legacy = legacyContext.getSharedPreferences(
                legacyPreferencesName,
                Context.MODE_PRIVATE,
            )
            val editor = preferences.edit()
            legacy.all.forEach { (key, value) ->
                when (value) {
                    is String -> editor.putString(key, value)
                    is Boolean -> editor.putBoolean(key, value)
                    is Int -> editor.putInt(key, value)
                    is Long -> editor.putLong(key, value)
                    is Float -> editor.putFloat(key, value)
                }
            }
            editor.putBoolean(migrationKey, true)
            editor.commit()
        }
        return preferences
    }
}
