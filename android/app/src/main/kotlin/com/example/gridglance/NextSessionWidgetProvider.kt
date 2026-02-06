package com.example.gridglance

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.util.Log
import android.widget.RemoteViews
import java.util.Calendar

class NextSessionWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        Log.d("NextSessionWidget", "onUpdate widgetIds=${appWidgetIds.joinToString()}")
        val deviceContext = context.createDeviceProtectedStorageContext()
        val prefs = deviceContext.getSharedPreferences("gridglance_widget", Context.MODE_PRIVATE)
        val defaultSeason = Calendar.getInstance().get(Calendar.YEAR).toString()
        val title = prefs.getString("next_session_widget_title", "Next Session") ?: "Next Session"
        val season = prefs.getString("next_session_widget_season", defaultSeason) ?: defaultSeason
        val sessionName = prefs.getString("next_session_widget_name", "Session TBA") ?: "Session TBA"
        val raceName = prefs.getString("next_session_widget_race", "Race weekend") ?: "Race weekend"
        val countdown = prefs.getString("next_session_widget_countdown", "Waiting for schedule") ?: "Waiting for schedule"
        val line1 = prefs.getString("next_session_widget_line1", "No additional sessions") ?: "No additional sessions"
        val line2 = prefs.getString("next_session_widget_line2", "Check again soon") ?: "Check again soon"
        val isTransparent = prefs.getString("next_session_widget_transparent", "false") == "true"

        for (appWidgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.next_session_widget)
            val background = if (isTransparent) {
                android.R.color.transparent
            } else {
                R.drawable.widget_background
            }
            views.setInt(R.id.widget_root, "setBackgroundResource", background)
            views.setTextViewText(R.id.widget_title, title)
            views.setTextViewText(R.id.widget_season, season)
            views.setTextViewText(R.id.session_name, sessionName)
            views.setTextViewText(R.id.session_race, raceName)
            views.setTextViewText(R.id.session_countdown, countdown)
            views.setTextViewText(R.id.session_line1, line1)
            views.setTextViewText(R.id.session_line2, line2)
            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}
