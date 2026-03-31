package com.gridglance.app

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.util.Log
import android.widget.RemoteViews
import java.util.Calendar

class TeamStandingsWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        Log.d("TeamStandingsWidget", "onUpdate widgetIds=${appWidgetIds.joinToString()}")
        val deviceContext = context.createDeviceProtectedStorageContext()
        val prefs = deviceContext.getSharedPreferences("gridglance_widget", Context.MODE_PRIVATE)
        val defaultSeason = Calendar.getInstance().get(Calendar.YEAR).toString()
        val title = prefs.getString("team_widget_title", "Team Standings") ?: "Team Standings"
        val season = prefs.getString("team_widget_season", defaultSeason) ?: defaultSeason
        val isTransparent = prefs.getString("team_widget_transparent", "false") == "true"

        for (appWidgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.team_standings_widget)
            val background = if (isTransparent) {
                android.R.color.transparent
            } else {
                R.drawable.widget_background
            }
            views.setInt(R.id.widget_root, "setBackgroundResource", background)
            views.setTextViewText(R.id.widget_title, title)
            views.setTextViewText(R.id.widget_season, season)

            // Podium team names and points.
            views.setTextViewText(
                R.id.team_one_name,
                prefs.getString("team_1_name", "P1") ?: "P1",
            )
            views.setTextViewText(
                R.id.team_one_pts,
                "${prefs.getString("team_1_pts", "0") ?: "0"} pts",
            )
            views.setTextViewText(
                R.id.team_two_name,
                prefs.getString("team_2_name", "P2") ?: "P2",
            )
            views.setTextViewText(
                R.id.team_two_pts,
                "${prefs.getString("team_2_pts", "0") ?: "0"} pts",
            )
            views.setTextViewText(
                R.id.team_three_name,
                prefs.getString("team_3_name", "P3") ?: "P3",
            )
            views.setTextViewText(
                R.id.team_three_pts,
                "${prefs.getString("team_3_pts", "0") ?: "0"} pts",
            )

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}
