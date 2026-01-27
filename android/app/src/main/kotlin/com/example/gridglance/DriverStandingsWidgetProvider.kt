package com.example.gridglance

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.util.Log
import android.widget.RemoteViews
import java.util.Calendar

class DriverStandingsWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        Log.d("DriverStandingsWidget", "onUpdate widgetIds=${appWidgetIds.joinToString()}")
        val deviceContext = context.createDeviceProtectedStorageContext()
        val prefs = deviceContext.getSharedPreferences("gridglance_widget", Context.MODE_PRIVATE)
        val defaultSeason = Calendar.getInstance().get(Calendar.YEAR).toString()
        val title = prefs.getString("driver_widget_title", "Driver Standings") ?: "Driver Standings"
        val subtitle = prefs.getString("driver_widget_subtitle", "Top 3 drivers") ?: "Top 3 drivers"
        val season = prefs.getString("driver_widget_season", defaultSeason) ?: defaultSeason
        val driver1 = prefs.getString("driver_1", "Update from app") ?: "Update from app"
        val driver2 = prefs.getString("driver_2", "TBD") ?: "TBD"
        val driver3 = prefs.getString("driver_3", "TBD") ?: "TBD"
        val isTransparent = prefs.getString("driver_widget_transparent", "false") == "true"

        for (appWidgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.driver_standings_widget)
            val background = if (isTransparent) {
                android.R.color.transparent
            } else {
                R.drawable.widget_background
            }
            views.setInt(R.id.widget_root, "setBackgroundResource", background)
            views.setTextViewText(R.id.widget_title, title)
            views.setTextViewText(R.id.widget_subtitle, subtitle)
            views.setTextViewText(R.id.widget_season, season)
            views.setTextViewText(R.id.driver_one, driver1)
            views.setTextViewText(R.id.driver_two, driver2)
            views.setTextViewText(R.id.driver_three, driver3)
            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}
