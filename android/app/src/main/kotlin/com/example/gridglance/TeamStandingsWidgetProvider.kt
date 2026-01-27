package com.example.gridglance

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
        val subtitle = prefs.getString("team_widget_subtitle", "Top 3 teams") ?: "Top 3 teams"
        val season = prefs.getString("team_widget_season", defaultSeason) ?: defaultSeason
        val team1 = prefs.getString("team_1", "Update from app") ?: "Update from app"
        val team2 = prefs.getString("team_2", "TBD") ?: "TBD"
        val team3 = prefs.getString("team_3", "TBD") ?: "TBD"
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
            views.setTextViewText(R.id.widget_subtitle, subtitle)
            views.setTextViewText(R.id.widget_season, season)
            views.setTextViewText(R.id.team_one, team1)
            views.setTextViewText(R.id.team_two, team2)
            views.setTextViewText(R.id.team_three, team3)
            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}
