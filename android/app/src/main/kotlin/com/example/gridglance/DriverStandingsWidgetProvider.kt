package com.example.gridglance

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.util.Log
import android.widget.RemoteViews

class DriverStandingsWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        Log.d("DriverStandingsWidget", "onUpdate widgetIds=${appWidgetIds.joinToString()}")
        val deviceContext = context.createDeviceProtectedStorageContext()
        val prefs = deviceContext.getSharedPreferences("gridglance_widget", Context.MODE_PRIVATE)
        val title = prefs.getString("driver_widget_title", "Driver Standings") ?: "Driver Standings"
        val subtitle = prefs.getString("driver_widget_subtitle", "Top 3 drivers") ?: "Top 3 drivers"
        val driver1 = prefs.getString("driver_1", "1. Update from app") ?: "1. Update from app"
        val driver2 = prefs.getString("driver_2", "2. ---") ?: "2. ---"
        val driver3 = prefs.getString("driver_3", "3. ---") ?: "3. ---"

        val intent = Intent(context, MainActivity::class.java)
        val pendingIntent = PendingIntent.getActivity(
            context,
            0,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

        for (appWidgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.driver_standings_widget)
            views.setTextViewText(R.id.widget_title, title)
            views.setTextViewText(R.id.widget_subtitle, subtitle)
            views.setTextViewText(R.id.driver_one, driver1)
            views.setTextViewText(R.id.driver_two, driver2)
            views.setTextViewText(R.id.driver_three, driver3)
            views.setOnClickPendingIntent(R.id.widget_root, pendingIntent)
            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}
