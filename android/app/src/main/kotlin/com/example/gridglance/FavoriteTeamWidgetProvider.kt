package com.gridglance.app

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.graphics.BitmapFactory
import android.graphics.Color
import android.util.Log
import android.widget.RemoteViews
import java.io.File
import java.util.Calendar

class FavoriteTeamWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        Log.d("FavoriteTeamWidget", "onUpdate widgetIds=${appWidgetIds.joinToString()}")
        val deviceContext = context.createDeviceProtectedStorageContext()
        val prefs = deviceContext.getSharedPreferences("gridglance_widget", Context.MODE_PRIVATE)
        val defaultSeason = Calendar.getInstance().get(Calendar.YEAR).toString()

        for (appWidgetId in appWidgetIds) {
            val prefix = "favorite_team_widget_${appWidgetId}_"
            val fallbackPrefix = "favorite_team_default_"
            val name = prefs.getString("${prefix}name",
                prefs.getString("${fallbackPrefix}name", "Tap to configure")
            ) ?: "Tap to configure"
            val position = prefs.getString("${prefix}position",
                prefs.getString("${fallbackPrefix}position", "--")
            ) ?: "--"
            val points = prefs.getString("${prefix}points",
                prefs.getString("${fallbackPrefix}points", "-- pts")
            ) ?: "-- pts"
            val season = prefs.getString("${prefix}season",
                prefs.getString("${fallbackPrefix}season", defaultSeason)
            ) ?: defaultSeason
            val isTransparent = prefs.getString(
                "${prefix}transparent",
                prefs.getString("${fallbackPrefix}transparent", "false"),
            ) == "true"

            // Team color for accent and text tinting.
            val teamColorHex = prefs.getString(
                "${prefix}team_color",
                prefs.getString("${fallbackPrefix}team_color", "#FFE10600"),
            ) ?: "#FFE10600"
            val teamColor = try {
                Color.parseColor(teamColorHex)
            } catch (_: Exception) {
                Color.parseColor("#E10600")
            }

            // Driver details.
            val d1Name = prefs.getString("${prefix}d1_name",
                prefs.getString("${fallbackPrefix}d1_name", "TBD")
            ) ?: "TBD"
            val d1Number = prefs.getString("${prefix}d1_number",
                prefs.getString("${fallbackPrefix}d1_number", "--")
            ) ?: "--"
            val d1Code = prefs.getString("${prefix}d1_code",
                prefs.getString("${fallbackPrefix}d1_code", "---")
            ) ?: "---"
            val d2Name = prefs.getString("${prefix}d2_name",
                prefs.getString("${fallbackPrefix}d2_name", "TBD")
            ) ?: "TBD"
            val d2Number = prefs.getString("${prefix}d2_number",
                prefs.getString("${fallbackPrefix}d2_number", "--")
            ) ?: "--"
            val d2Code = prefs.getString("${prefix}d2_code",
                prefs.getString("${fallbackPrefix}d2_code", "---")
            ) ?: "---"

            val intent = Intent(context, MainActivity::class.java).apply {
                action = "com.gridglance.app.WIDGET_CLICK"
                putExtra("widget_type", "favorite_team")
                putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
            }
            val pendingIntent = PendingIntent.getActivity(
                context,
                appWidgetId,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )

            val views = RemoteViews(context.packageName, R.layout.favorite_team_widget)
            val background = if (isTransparent) {
                android.R.color.transparent
            } else {
                R.drawable.widget_background
            }
            views.setInt(R.id.widget_root, "setBackgroundResource", background)
            views.setTextViewText(R.id.widget_season, season)
            views.setTextViewText(R.id.team_name, name)
            views.setTextViewText(R.id.team_position, position)
            val ptsNumber = points.replace(" pts", "").replace("pts", "")
            views.setTextViewText(R.id.team_points, ptsNumber)

            // Driver details with team-colored text.
            views.setTextViewText(R.id.driver1_number, d1Number)
            views.setTextViewText(R.id.driver1_name, d1Name)
            views.setTextViewText(R.id.driver1_code, d1Code)
            views.setTextViewText(R.id.driver2_number, d2Number)
            views.setTextViewText(R.id.driver2_name, d2Name)
            views.setTextViewText(R.id.driver2_code, d2Code)

            // Apply team color to driver names, numbers, and accent bar.
            views.setTextColor(R.id.driver1_name, teamColor)
            views.setTextColor(R.id.driver1_number, teamColor)
            views.setTextColor(R.id.driver2_name, teamColor)
            views.setTextColor(R.id.driver2_number, teamColor)
            views.setTextColor(R.id.team_name, teamColor)
            views.setInt(R.id.team_color_bar, "setBackgroundColor", teamColor)

            // Load team car image.
            val carImagePath = prefs.getString(
                "${prefix}car_image",
                prefs.getString("${fallbackPrefix}car_image", null),
            )
            if (carImagePath != null) {
                val file = File(carImagePath)
                if (file.exists()) {
                    val bitmap = BitmapFactory.decodeFile(carImagePath)
                    if (bitmap != null) {
                        views.setImageViewBitmap(R.id.team_car, bitmap)
                    }
                }
            }

            views.setOnClickPendingIntent(R.id.widget_root, pendingIntent)
            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}
