package com.gridglance.app

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.util.Log
import android.view.View
import android.widget.RemoteViews
import java.util.Calendar

class RaceWeekendWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        Log.d("RaceWeekendWidget", "onUpdate widgetIds=${appWidgetIds.joinToString()}")
        val deviceContext = context.createDeviceProtectedStorageContext()
        val prefs = deviceContext.getSharedPreferences("gridglance_widget", Context.MODE_PRIVATE)
        val defaultSeason = Calendar.getInstance().get(Calendar.YEAR).toString()
        val title = prefs.getString("race_weekend_widget_title", "Race Weekend") ?: "Race Weekend"
        val season = prefs.getString("race_weekend_widget_season", defaultSeason) ?: defaultSeason
        val raceName = prefs.getString("race_weekend_widget_name", "Race weekend") ?: "Race weekend"
        val raceLocation = prefs.getString("race_weekend_widget_location", "Location TBA") ?: "Location TBA"
        val countdown = prefs.getString("race_weekend_widget_countdown", "Waiting for schedule") ?: "Waiting for schedule"
        val isTransparent = prefs.getString("race_weekend_widget_transparent", "false") == "true"

        val sessionTextIds = arrayOf(
            R.id.session_1, R.id.session_2, R.id.session_3,
            R.id.session_4, R.id.session_5, R.id.session_6, R.id.session_7
        )
        val sessionRowIds = arrayOf(
            R.id.session_1_row, R.id.session_2_row, R.id.session_3_row,
            R.id.session_4_row, R.id.session_5_row, R.id.session_6_row, R.id.session_7_row
        )
        val sessionDotIds = arrayOf(
            R.id.session_1_dot, R.id.session_2_dot, R.id.session_3_dot,
            R.id.session_4_dot, R.id.session_5_dot, R.id.session_6_dot, R.id.session_7_dot
        )

        for (appWidgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.race_weekend_widget)
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
            views.setTextViewText(R.id.next_session_countdown, countdown)

            for (i in sessionTextIds.indices) {
                val key = "race_weekend_widget_session_${i + 1}"
                val text = prefs.getString(key, null)
                if (text != null && text.isNotEmpty()) {
                    views.setTextViewText(sessionTextIds[i], text)
                    views.setViewVisibility(sessionRowIds[i], View.VISIBLE)
                } else {
                    views.setViewVisibility(sessionRowIds[i], View.GONE)
                }
            }

            // Highlight the next session row with active dot and brighter text.
            val nextIndex = prefs.getString("race_weekend_widget_next_index", "-1")?.toIntOrNull() ?: -1
            for (i in sessionTextIds.indices) {
                if (i == nextIndex) {
                    views.setTextColor(sessionTextIds[i], 0xFFF7F8FA.toInt())
                    views.setInt(sessionDotIds[i], "setBackgroundResource", R.drawable.widget_timeline_dot_active)
                } else {
                    views.setTextColor(sessionTextIds[i], 0xFFDCE1EA.toInt())
                    views.setInt(sessionDotIds[i], "setBackgroundResource", R.drawable.widget_timeline_dot)
                }
            }

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}
