package com.gridglance.app

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.graphics.BitmapFactory
import android.util.Log
import android.widget.RemoteViews
import java.io.File
import java.util.Calendar

class TeamStandingsWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        Log.d("TeamStandingsWidget", "onUpdate widgetIds=${appWidgetIds.joinToString()}")
        val prefs = WidgetPreferences.get(context)
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
            views.setTextViewText(R.id.team_one_pts, PodiumBinding.pointsWithGap(prefs, "team", 1))
            views.setTextViewText(
                R.id.team_two_name,
                prefs.getString("team_2_name", "P2") ?: "P2",
            )
            views.setTextViewText(R.id.team_two_pts, PodiumBinding.pointsWithGap(prefs, "team", 2))
            views.setTextViewText(
                R.id.team_three_name,
                prefs.getString("team_3_name", "P3") ?: "P3",
            )
            views.setTextViewText(R.id.team_three_pts, PodiumBinding.pointsWithGap(prefs, "team", 3))

            // Load team logos.
            val logoIds = arrayOf(R.id.team_one_logo, R.id.team_two_logo, R.id.team_three_logo)
            for (i in 1..3) {
                val logoPath = prefs.getString("team_${i}_logo", null)
                if (logoPath != null) {
                    val file = File(logoPath)
                    if (file.exists()) {
                        val bitmap = BitmapFactory.decodeFile(logoPath)
                        if (bitmap != null) {
                            views.setImageViewBitmap(logoIds[i - 1], bitmap)
                        }
                    }
                }
            }

            // Tap the podium step → that team's detail; anywhere else → full standings.
            views.setOnClickPendingIntent(
                R.id.widget_root,
                WidgetInteractions.openApp(context, "team_standings", appWidgetId),
            )
            val colIds = arrayOf(R.id.team_one_col, R.id.team_two_col, R.id.team_three_col)
            for (i in 1..3) {
                val id = prefs.getString("team_${i}_id", null)
                if (!id.isNullOrEmpty()) {
                    views.setOnClickPendingIntent(
                        colIds[i - 1],
                        WidgetInteractions.openApp(context, "team_standings", appWidgetId, "p$i", id),
                    )
                }
            }

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}
