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
        val deviceContext = context.createDeviceProtectedStorageContext()
        val prefs = deviceContext.getSharedPreferences("gridglance_widget", Context.MODE_PRIVATE)
        val defaultSeason = Calendar.getInstance().get(Calendar.YEAR).toString()
        val title = prefs.getString("driver_widget_title", "Driver Standings") ?: "Driver Standings"
        val season = prefs.getString("driver_widget_season", defaultSeason) ?: defaultSeason
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
            views.setTextViewText(R.id.widget_season, season)

            // Podium driver names and points.
            views.setTextViewText(
                R.id.driver_one_name,
                prefs.getString("driver_1_last_name", "P1") ?: "P1",
            )
            views.setTextViewText(
                R.id.driver_one_pts,
                "${prefs.getString("driver_1_pts", "0") ?: "0"} pts",
            )
            views.setTextViewText(
                R.id.driver_two_name,
                prefs.getString("driver_2_last_name", "P2") ?: "P2",
            )
            views.setTextViewText(
                R.id.driver_two_pts,
                "${prefs.getString("driver_2_pts", "0") ?: "0"} pts",
            )
            views.setTextViewText(
                R.id.driver_three_name,
                prefs.getString("driver_3_last_name", "P3") ?: "P3",
            )
            views.setTextViewText(
                R.id.driver_three_pts,
                "${prefs.getString("driver_3_pts", "0") ?: "0"} pts",
            )

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

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}
