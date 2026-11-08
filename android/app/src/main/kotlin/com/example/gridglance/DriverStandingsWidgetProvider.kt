package com.gridglance.app

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.graphics.BitmapFactory
import android.util.Log
import android.widget.RemoteViews
import java.io.File
import java.util.Calendar

class DriverStandingsWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        Log.d("DriverStandingsWidget", "onUpdate widgetIds=${appWidgetIds.joinToString()}")
        val prefs = WidgetPreferences.get(context)
        val defaultSeason = Calendar.getInstance().get(Calendar.YEAR).toString()
        val title = prefs.getString("driver_widget_title", "Driver Standings") ?: "Driver Standings"
        val season = prefs.getString("driver_widget_season", defaultSeason) ?: defaultSeason
        val isTransparent = prefs.getString("driver_widget_transparent", "false") == "true"

        for (appWidgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.driver_standings_widget)
            val background = if (isTransparent) {
                R.drawable.widget_background_glass
            } else {
                R.drawable.widget_background
            }
            views.setInt(R.id.widget_root, "setBackgroundResource", background)
            views.setTextViewText(R.id.widget_title, title)
            views.setTextViewText(R.id.widget_season, season)

            // Podium driver names and points.
            views.setTextViewText(
                R.id.driver_one_name,
                prefs.getString("driver_1_last_name", "P1") ?: "P1",
            )
            views.setTextViewText(R.id.driver_one_pts, PodiumBinding.pointsWithGap(prefs, "driver", 1))
            views.setTextViewText(
                R.id.driver_two_name,
                prefs.getString("driver_2_last_name", "P2") ?: "P2",
            )
            views.setTextViewText(R.id.driver_two_pts, PodiumBinding.pointsWithGap(prefs, "driver", 2))
            views.setTextViewText(
                R.id.driver_three_name,
                prefs.getString("driver_3_last_name", "P3") ?: "P3",
            )
            views.setTextViewText(R.id.driver_three_pts, PodiumBinding.pointsWithGap(prefs, "driver", 3))

            // Load driver headshot images.
            val photoIds = arrayOf(R.id.driver_one_photo, R.id.driver_two_photo, R.id.driver_three_photo)
            for (i in 1..3) {
                val imagePath = prefs.getString("driver_${i}_image", null)
                if (imagePath != null) {
                    val file = File(imagePath)
                    if (file.exists()) {
                        val bitmap = BitmapFactory.decodeFile(imagePath)
                        if (bitmap != null) {
                            views.setImageViewBitmap(photoIds[i - 1], bitmap)
                        }
                    }
                }
            }

            // Tap the podium step → that driver's detail; anywhere else → full standings.
            views.setOnClickPendingIntent(
                R.id.widget_root,
                WidgetInteractions.openApp(context, "driver_standings", appWidgetId),
            )
            val colIds = arrayOf(R.id.driver_one_col, R.id.driver_two_col, R.id.driver_three_col)
            for (i in 1..3) {
                val id = prefs.getString("driver_${i}_id", null)
                if (!id.isNullOrEmpty()) {
                    views.setOnClickPendingIntent(
                        colIds[i - 1],
                        WidgetInteractions.openApp(context, "driver_standings", appWidgetId, "p$i", id),
                    )
                }
            }

            if (isTransparent) {
                WidgetInteractions.applyGlassContrast(
                    views,
                    mutedTextIds = intArrayOf(
                        R.id.widget_season, R.id.driver_two_pts,
                        R.id.driver_standings_label_1, R.id.driver_three_pts,
                    ),
                    pillIds = intArrayOf(R.id.widget_season),
                )
            }
            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}
