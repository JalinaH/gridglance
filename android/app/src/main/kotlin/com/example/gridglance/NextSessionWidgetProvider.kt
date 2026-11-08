package com.gridglance.app

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.os.Build
import android.os.SystemClock
import android.util.Log
import android.view.View
import android.widget.RemoteViews
import java.util.Calendar

class NextSessionWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        Log.d("NextSessionWidget", "onUpdate widgetIds=${appWidgetIds.joinToString()}")
        val prefs = WidgetPreferences.get(context)
        val now = System.currentTimeMillis()
        val defaultSeason = Calendar.getInstance().get(Calendar.YEAR).toString()
        val title = prefs.getString("next_session_widget_title", "Next Session") ?: "Next Session"
        val season = prefs.getString("next_session_widget_season", defaultSeason) ?: defaultSeason
        val sessionName = prefs.getString("next_session_widget_name", "Session TBA") ?: "Session TBA"
        val raceName = prefs.getString("next_session_widget_race", "Race weekend") ?: "Race weekend"
        val fallbackCountdown = prefs.getString("next_session_widget_countdown", "Waiting for schedule")
            ?: "Waiting for schedule"
        val line1 = prefs.getString("next_session_widget_line1", "No additional sessions") ?: "No additional sessions"
        val line2 = prefs.getString("next_session_widget_line2", "Check again soon") ?: "Check again soon"
        val isTransparent = prefs.getString("next_session_widget_transparent", "false") == "true"
        val targetMs = prefs.getString("next_session_widget_target_ms", null)?.toLongOrNull()

        for (appWidgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.next_session_widget)
            views.setInt(
                R.id.widget_root,
                "setBackgroundResource",
                if (isTransparent) android.R.color.transparent else R.drawable.widget_background,
            )
            views.setTextViewText(R.id.widget_title, title)
            views.setTextViewText(R.id.widget_season, season)
            views.setTextViewText(R.id.session_name, sessionName)
            views.setTextViewText(R.id.session_race, raceName)

            bindHero(context, views, sessionName, targetMs, fallbackCountdown, now)
            bindLine(views, line1, R.id.session_line1, R.id.session_line1_time)
            bindLine(views, line2, R.id.session_line2, R.id.session_line2_time)

            views.setOnClickPendingIntent(
                R.id.widget_root,
                WidgetInteractions.openApp(context, "next_session", appWidgetId),
            )
            WidgetInteractions.bindUpdatedLabel(context, views, prefs, R.id.widget_status)
            appWidgetManager.updateAppWidget(appWidgetId, views)
        }

        // Flip to "ticking" 24h out, to LIVE at the start, and off LIVE at the end.
        val boundaries = targetMs?.let {
            listOf(it - WidgetInteractions.DAY_MS, it, it + WidgetInteractions.sessionDurationMs(sessionName))
        }.orEmpty()
        WidgetInteractions.scheduleRerender(
            context,
            NextSessionWidgetProvider::class.java,
            boundaries.filter { it > now }.minOrNull(),
        )
    }

    private fun bindHero(
        context: Context,
        views: RemoteViews,
        sessionName: String,
        targetMs: Long?,
        fallback: String,
        now: Long,
    ) {
        views.setViewVisibility(R.id.session_chronometer, View.GONE)
        views.setViewVisibility(R.id.session_countdown, View.VISIBLE)

        if (targetMs == null) {
            // Older data without a timestamp: show the stored text as-is.
            views.setTextViewText(R.id.session_hero_label, "Up next")
            views.setTextViewText(R.id.session_countdown, "")
            views.setTextViewText(R.id.session_caption, fallback)
            return
        }

        val remaining = targetMs - now
        val endMs = targetMs + WidgetInteractions.sessionDurationMs(sessionName)
        views.setTextViewText(R.id.session_caption, WidgetInteractions.formatDayTime(context, targetMs))

        when {
            now >= endMs -> {
                // Session over; background refresh will move on to the next one.
                views.setTextViewText(R.id.session_hero_label, "Finished")
                views.setTextViewText(R.id.session_countdown, "🏁")
            }
            remaining <= 0L -> {
                views.setTextViewText(R.id.session_hero_label, "● Live now")
                views.setTextViewText(R.id.session_countdown, "On track")
                views.setTextViewText(
                    R.id.session_caption,
                    "~${WidgetInteractions.formatDuration(endMs - now)} left",
                )
            }
            remaining < WidgetInteractions.DAY_MS && Build.VERSION.SDK_INT >= Build.VERSION_CODES.N -> {
                views.setTextViewText(R.id.session_hero_label, "Starts in")
                views.setChronometer(
                    R.id.session_chronometer,
                    SystemClock.elapsedRealtime() + remaining,
                    null,
                    true,
                )
                views.setChronometerCountDown(R.id.session_chronometer, true)
                views.setViewVisibility(R.id.session_chronometer, View.VISIBLE)
                views.setViewVisibility(R.id.session_countdown, View.GONE)
            }
            else -> {
                views.setTextViewText(R.id.session_hero_label, "Starts in")
                views.setTextViewText(R.id.session_countdown, WidgetInteractions.formatDuration(remaining))
            }
        }
    }

    /** "Race • Mar 16 • 5:00 PM" → name on the left, "Mar 16 · 5:00 PM" right. */
    private fun bindLine(views: RemoteViews, raw: String, nameId: Int, timeId: Int) {
        val parts = raw.split(" • ")
        if (parts.size >= 2) {
            views.setTextViewText(nameId, parts.first())
            views.setTextViewText(timeId, parts.drop(1).joinToString(" · "))
        } else {
            views.setTextViewText(nameId, raw)
            views.setTextViewText(timeId, "")
        }
    }
}
