package com.example.gridglance

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.util.Log
import android.widget.RemoteViews
import java.util.Calendar

class FavoriteDriverWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        Log.d("FavoriteDriverWidget", "onUpdate widgetIds=${appWidgetIds.joinToString()}")
        val deviceContext = context.createDeviceProtectedStorageContext()
        val prefs = deviceContext.getSharedPreferences("gridglance_widget", Context.MODE_PRIVATE)
        val defaultSeason = Calendar.getInstance().get(Calendar.YEAR).toString()

        for (appWidgetId in appWidgetIds) {
            val prefix = "favorite_driver_widget_${appWidgetId}_"
            val fallbackPrefix = "favorite_driver_default_"
            val name = prefs.getString("${prefix}name",
                prefs.getString("${fallbackPrefix}name", "Tap to configure")
            ) ?: "Tap to configure"
            val team = prefs.getString("${prefix}team",
                prefs.getString("${fallbackPrefix}team", "")
            ) ?: ""
            val position = prefs.getString("${prefix}position",
                prefs.getString("${fallbackPrefix}position", "--")
            ) ?: "--"
            val points = prefs.getString("${prefix}points",
                prefs.getString("${fallbackPrefix}points", "-- pts")
            ) ?: "-- pts"
            val season = prefs.getString("${prefix}season",
                prefs.getString("${fallbackPrefix}season", defaultSeason)
            ) ?: defaultSeason
            val isTransparent = prefs.getString("${prefix}transparent", "false") == "true"

            val intent = Intent(context, MainActivity::class.java).apply {
                action = "com.example.gridglance.WIDGET_CLICK"
                putExtra("widget_type", "favorite_driver")
                putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
            }
            val pendingIntent = PendingIntent.getActivity(
                context,
                appWidgetId,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )

            val views = RemoteViews(context.packageName, R.layout.favorite_driver_widget)
            val background = if (isTransparent) {
                android.R.color.transparent
            } else {
                R.drawable.widget_background
            }
            views.setInt(R.id.widget_root, "setBackgroundResource", background)
            views.setTextViewText(R.id.widget_season, season)
            views.setTextViewText(R.id.driver_name, name)
            views.setTextViewText(R.id.driver_team, team)
            views.setTextViewText(R.id.driver_position, position)
            views.setTextViewText(R.id.driver_points, points)
            views.setOnClickPendingIntent(R.id.widget_root, pendingIntent)
            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}
