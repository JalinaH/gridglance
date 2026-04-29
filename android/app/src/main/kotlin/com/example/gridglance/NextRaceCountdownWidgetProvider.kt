package com.gridglance.app

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.SharedPreferences
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
        val raceName = prefs.getString("next_race_widget_name", "Race weekend") ?: "Race weekend"
        val raceLocation = prefs.getString("next_race_widget_location", "Location TBA") ?: "Location TBA"
        val raceStart = prefs.getString("next_race_widget_start", "Time TBA") ?: "Time TBA"
        val round = prefs.getString("next_race_widget_round", "") ?: ""
        val isTransparent = prefs.getString("next_race_widget_transparent", "false") == "true"
        val (days, hours, mins) = computeCountdownSegments(prefs)

        for (appWidgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.next_race_countdown_widget)
            val background = if (isTransparent) {
                android.R.color.transparent
            } else {
                R.drawable.widget_background
            }
            views.setInt(R.id.widget_root, "setBackgroundResource", background)
            views.setTextViewText(R.id.widget_title, title)
            views.setTextViewText(R.id.race_round, round)
            views.setTextViewText(R.id.race_name, raceName)
            views.setTextViewText(R.id.race_location, raceLocation)
            views.setTextViewText(R.id.race_start, raceStart)
            views.setTextViewText(R.id.countdown_days, days)
            views.setTextViewText(R.id.countdown_hours, hours)
            views.setTextViewText(R.id.countdown_mins, mins)
            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }

    // Recomputes days/hours/minutes locally from the persisted target so the
    // values stay fresh even when the BG refresh hasn't run since the last
    // app open. Falls back to the values Flutter last wrote if no timestamp.
    private fun computeCountdownSegments(prefs: SharedPreferences): Triple<String, String, String> {
        val targetMs = prefs.getString("next_race_widget_target_ms", "")?.toLongOrNull()
        if (targetMs == null) {
            val days = prefs.getString("next_race_widget_days", "--") ?: "--"
            val hours = prefs.getString("next_race_widget_hours", "--") ?: "--"
            val mins = prefs.getString("next_race_widget_mins", "--") ?: "--"
            return Triple(days, hours, mins)
        }
        val remainingMs = targetMs - System.currentTimeMillis()
        if (remainingMs <= 0L) {
            return Triple("0", "0", "0")
        }
        val totalMinutes = remainingMs / 60_000L
        val days = totalMinutes / (60L * 24L)
        val hours = (totalMinutes / 60L) % 24L
        val minutes = totalMinutes % 60L
        return Triple(days.toString(), hours.toString(), minutes.toString())
    }
}
