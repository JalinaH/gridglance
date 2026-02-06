package com.example.gridglance

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.util.Log
import android.widget.RemoteViews
import java.util.Calendar

class NextRaceCountdownWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        Log.d("NextRaceCountdownWidget", "onUpdate widgetIds=${appWidgetIds.joinToString()}")
        val deviceContext = context.createDeviceProtectedStorageContext()
        val prefs = deviceContext.getSharedPreferences("gridglance_widget", Context.MODE_PRIVATE)
        val defaultSeason = Calendar.getInstance().get(Calendar.YEAR).toString()
        val title = prefs.getString("next_race_widget_title", "Next Race") ?: "Next Race"
        val season = prefs.getString("next_race_widget_season", defaultSeason) ?: defaultSeason
        val raceName = prefs.getString("next_race_widget_name", "Race weekend") ?: "Race weekend"
        val raceLocation = prefs.getString("next_race_widget_location", "Location TBA") ?: "Location TBA"
        val raceStart = prefs.getString("next_race_widget_start", "Time TBA") ?: "Time TBA"
        val raceCountdown = prefs.getString("next_race_widget_countdown", "Waiting for schedule") ?: "Waiting for schedule"
        val isTransparent = prefs.getString("next_race_widget_transparent", "false") == "true"

        for (appWidgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.next_race_countdown_widget)
            val background = if (isTransparent) {
                android.R.color.transparent
            } else {
                R.drawable.widget_background
            }
            views.setInt(R.id.widget_root, "setBackgroundResource", background)
            views.setTextViewText(R.id.widget_title, title)
            views.setTextViewText(R.id.widget_season, season)
            views.setTextViewText(R.id.race_name, raceName)
            views.setTextViewText(R.id.race_location, raceLocation)
            views.setTextViewText(R.id.race_start, raceStart)
            views.setTextViewText(R.id.race_countdown, raceCountdown)
            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}
