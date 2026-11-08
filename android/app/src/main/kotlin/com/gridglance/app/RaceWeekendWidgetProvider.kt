package com.gridglance.app

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.SharedPreferences
import android.graphics.BitmapFactory
import android.os.Build
import android.os.SystemClock
import android.util.Log
import android.view.View
import android.widget.RemoteViews
import java.io.File
import java.util.Locale

class RaceWeekendWidgetProvider : AppWidgetProvider() {

    private enum class SessionState { DONE, LIVE, NEXT, UPCOMING }

    private data class WeekendSession(
        val name: String,
        val startMs: Long?,
        val fallbackLabel: String,
    )

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        Log.d(TAG, "onUpdate widgetIds=${appWidgetIds.joinToString()}")
        val prefs = WidgetPreferences.get(context)
        val now = System.currentTimeMillis()
        val title = prefs.getString("race_weekend_widget_title", "Race Weekend") ?: "Race Weekend"
        val raceName = prefs.getString("race_weekend_widget_name", "Race weekend") ?: "Race weekend"
        val raceLocation = prefs.getString("race_weekend_widget_location", "Location TBA") ?: "Location TBA"
        val round = prefs.getString("race_weekend_widget_round", "") ?: ""
        val isTransparent = prefs.getString("race_weekend_widget_transparent", "false") == "true"

        val sessions = readSessions(prefs)
        val states = computeStates(sessions, now)
        val liveIndex = states.indexOf(SessionState.LIVE)
        val nextIndex = states.indexOf(SessionState.NEXT)
        val doneCount = states.count { it == SessionState.DONE }
        val trackBitmap = prefs.getString("race_weekend_widget_track", null)
            ?.let { path -> if (File(path).exists()) BitmapFactory.decodeFile(path) else null }

        for (appWidgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.race_weekend_widget)
            views.setInt(
                R.id.widget_root,
                "setBackgroundResource",
                if (isTransparent) R.drawable.widget_background_glass else R.drawable.widget_background,
            )
            views.setTextViewText(R.id.widget_title, title)
            views.setTextViewText(R.id.race_round, round)
            views.setViewVisibility(R.id.race_round, if (round.isEmpty()) View.GONE else View.VISIBLE)
            views.setTextViewText(R.id.race_name, raceName)
            views.setTextViewText(R.id.race_location, raceLocation)

            if (trackBitmap != null) {
                views.setImageViewBitmap(R.id.track_image, trackBitmap)
                views.setViewVisibility(R.id.track_image, View.VISIBLE)
            } else {
                views.setViewVisibility(R.id.track_image, View.INVISIBLE)
            }

            bindHero(context, views, prefs, sessions, liveIndex, nextIndex, now)
            bindProgress(views, sessions.size, doneCount)
            bindSessionRows(context, views, sessions, states, isTransparent)

            views.setOnClickPendingIntent(
                R.id.widget_root,
                WidgetInteractions.openApp(context, "race_weekend", appWidgetId),
            )
            WidgetInteractions.bindUpdatedLabel(context, views, prefs, R.id.widget_status)

            if (isTransparent) {
                WidgetInteractions.applyGlassContrast(
                    views,
                    mutedTextIds = intArrayOf(
                        R.id.widget_title, R.id.widget_status, R.id.race_location,
                        R.id.hero_caption, R.id.weekend_progress_label,
                    ),
                )
                views.setInt(R.id.hero_card, "setBackgroundResource", R.drawable.widget_hero_card_glass)
            }
            appWidgetManager.updateAppWidget(appWidgetId, views)
        }

        scheduleNextTransition(context, sessions, now)
    }

    // region Binding

    private fun bindHero(
        context: Context,
        views: RemoteViews,
        prefs: SharedPreferences,
        sessions: List<WeekendSession>,
        liveIndex: Int,
        nextIndex: Int,
        now: Long,
    ) {
        views.setViewVisibility(R.id.hero_chronometer, View.GONE)
        views.setViewVisibility(R.id.next_session_countdown, View.VISIBLE)

        // Session on track right now.
        if (liveIndex >= 0) {
            val live = sessions[liveIndex]
            views.setTextViewText(R.id.hero_label, "● Live now")
            views.setTextViewText(R.id.hero_session, live.name)
            val endMs = (live.startMs ?: now) + sessionDurationMs(live.name)
            val remaining = endMs - now
            views.setTextViewText(R.id.next_session_countdown, "On track")
            views.setTextViewText(
                R.id.hero_caption,
                if (remaining > 60_000L) "~${formatDuration(remaining)} left" else "Finishing",
            )
            return
        }

        // Upcoming session: show the countdown.
        if (nextIndex >= 0) {
            val next = sessions[nextIndex]
            val startMs = next.startMs!!
            val remaining = startMs - now
            views.setTextViewText(
                R.id.hero_label,
                if (nextIndex == sessions.lastIndex) "Lights out in" else "Next up",
            )
            views.setTextViewText(R.id.hero_session, next.name)
            views.setTextViewText(R.id.hero_caption, WidgetInteractions.formatDayTime(context, startMs))

            if (remaining in 1 until DAY_MS && Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                // Ticking HH:MM:SS countdown, driven by the launcher.
                val base = SystemClock.elapsedRealtime() + remaining
                views.setChronometer(R.id.hero_chronometer, base, null, true)
                views.setChronometerCountDown(R.id.hero_chronometer, true)
                views.setViewVisibility(R.id.hero_chronometer, View.VISIBLE)
                views.setViewVisibility(R.id.next_session_countdown, View.GONE)
            } else {
                views.setTextViewText(
                    R.id.next_session_countdown,
                    if (remaining <= 60_000L) "Now" else formatDuration(remaining),
                )
            }
            return
        }

        // No timestamps (old data) or weekend finished.
        if (sessions.isNotEmpty() && sessions.all { it.startMs != null }) {
            views.setTextViewText(R.id.hero_label, "Chequered flag")
            views.setTextViewText(R.id.hero_session, "Weekend complete")
            views.setTextViewText(R.id.next_session_countdown, "🏁")
            views.setTextViewText(R.id.hero_caption, "Tap for results")
        } else {
            val fallback = prefs.getString("race_weekend_widget_countdown", "Waiting for schedule")
                ?: "Waiting for schedule"
            views.setTextViewText(R.id.hero_label, "Race weekend")
            views.setTextViewText(R.id.hero_session, fallback)
            views.setTextViewText(R.id.next_session_countdown, "")
            views.setTextViewText(R.id.hero_caption, "")
        }
    }

    private fun bindProgress(views: RemoteViews, total: Int, done: Int) {
        if (total == 0) {
            views.setProgressBar(R.id.weekend_progress, 1, 0, false)
            views.setTextViewText(R.id.weekend_progress_label, "")
            return
        }
        views.setProgressBar(R.id.weekend_progress, total, done, false)
        views.setTextViewText(R.id.weekend_progress_label, "$done / $total DONE")
    }

    private fun bindSessionRows(
        context: Context,
        views: RemoteViews,
        sessions: List<WeekendSession>,
        states: List<SessionState>,
        isGlass: Boolean,
    ) {
        // Over the glass background the regular dim gray disappears into the wallpaper.
        val dim = if (isGlass) WidgetInteractions.COLOR_GLASS_DIM else COLOR_DIM
        for (i in 0 until MAX_SESSIONS) {
            val ids = ROW_IDS[i]
            val session = sessions.getOrNull(i)
            if (session == null) {
                views.setViewVisibility(ids.row, View.GONE)
                continue
            }
            views.setViewVisibility(ids.row, View.VISIBLE)
            val state = states[i]
            val isRace = i == sessions.lastIndex

            if (session.startMs != null) {
                views.setTextViewText(ids.name, session.name)
                views.setTextViewText(ids.day, formatDay(session.startMs))
                views.setTextViewText(ids.time, WidgetInteractions.formatTime(context, session.startMs))
                views.setViewVisibility(ids.day, View.VISIBLE)
                views.setViewVisibility(ids.time, View.VISIBLE)
            } else {
                // Legacy data from before timestamps were persisted.
                views.setTextViewText(ids.name, session.fallbackLabel)
                views.setViewVisibility(ids.day, View.GONE)
                views.setViewVisibility(ids.time, View.GONE)
            }

            val (icon, rowBg, nameColor, metaColor) = when (state) {
                SessionState.DONE -> RowStyle(
                    R.drawable.ic_session_done, R.drawable.widget_session_row_idle, dim, dim,
                )
                SessionState.LIVE -> RowStyle(
                    R.drawable.ic_session_live, R.drawable.widget_session_row_live, COLOR_BRIGHT, COLOR_BRIGHT,
                )
                SessionState.NEXT -> RowStyle(
                    R.drawable.ic_session_next, R.drawable.widget_session_row_next, COLOR_BRIGHT, COLOR_BRIGHT,
                )
                SessionState.UPCOMING -> RowStyle(
                    R.drawable.ic_session_upcoming, R.drawable.widget_session_row_idle,
                    if (isRace) COLOR_BRIGHT else COLOR_NORMAL, COLOR_NORMAL,
                )
            }
            views.setImageViewResource(ids.icon, icon)
            views.setInt(ids.row, "setBackgroundResource", rowBg)
            views.setTextColor(ids.name, nameColor)
            views.setTextColor(ids.time, metaColor)
            views.setTextColor(
                ids.day,
                if (state == SessionState.NEXT || state == SessionState.LIVE) COLOR_ACCENT else dim,
            )
            views.setViewVisibility(ids.live, if (state == SessionState.LIVE) View.VISIBLE else View.GONE)
        }
    }

    // endregion

    // region State

    private fun readSessions(prefs: SharedPreferences): List<WeekendSession> {
        val result = mutableListOf<WeekendSession>()
        for (i in 1..MAX_SESSIONS) {
            val label = prefs.getString("race_weekend_widget_session_$i", null).orEmpty()
            if (label.isEmpty()) continue
            val name = prefs.getString("race_weekend_widget_session_${i}_name", null)
                .orEmpty()
                .ifEmpty { label.substringBefore(" • ") }
            val startMs = prefs.getString("race_weekend_widget_session_${i}_ms", null)?.toLongOrNull()
            result.add(WeekendSession(name, startMs, label))
        }
        return result
    }

    private fun computeStates(sessions: List<WeekendSession>, now: Long): List<SessionState> {
        var nextAssigned = false
        return sessions.map { session ->
            val start = session.startMs ?: return@map SessionState.UPCOMING
            val end = start + sessionDurationMs(session.name)
            when {
                now >= end -> SessionState.DONE
                now >= start -> SessionState.LIVE
                !nextAssigned -> {
                    nextAssigned = true
                    SessionState.NEXT
                }
                else -> SessionState.UPCOMING
            }
        }
    }

    // endregion

    // region Scheduling

    /**
     * Wakes the widget at the next session start/end (and when the next
     * start enters the 24h ticking window) so done/live/next flips on time.
     */
    private fun scheduleNextTransition(context: Context, sessions: List<WeekendSession>, now: Long) {
        val boundaries = sessions.flatMap { s ->
            val start = s.startMs ?: return@flatMap emptyList<Long>()
            listOf(start - DAY_MS, start, start + sessionDurationMs(s.name))
        }
        WidgetInteractions.scheduleRerender(
            context,
            RaceWeekendWidgetProvider::class.java,
            boundaries.filter { it > now }.minOrNull(),
        )
    }

    // endregion

    // region Formatting

    private fun sessionDurationMs(name: String) = WidgetInteractions.sessionDurationMs(name)
    private fun formatDay(ms: Long) = WidgetInteractions.formatDay(ms)
    private fun formatDuration(ms: Long) = WidgetInteractions.formatDuration(ms)

    // endregion

    private data class RowStyle(val icon: Int, val background: Int, val nameColor: Int, val metaColor: Int)

    private data class RowIds(
        val row: Int,
        val icon: Int,
        val name: Int,
        val live: Int,
        val day: Int,
        val time: Int,
    )

    companion object {
        private const val TAG = "RaceWeekendWidget"
        private const val MAX_SESSIONS = 7
        private const val DAY_MS = WidgetInteractions.DAY_MS

        private const val COLOR_BRIGHT = 0xFFF7F8FA.toInt()
        private const val COLOR_NORMAL = 0xFFC9D0DA.toInt()
        private const val COLOR_DIM = 0xFF5C6675.toInt()
        private const val COLOR_ACCENT = 0xFFFF5A4F.toInt()

        private val ROW_IDS = arrayOf(
            RowIds(R.id.session_1_row, R.id.session_1_icon, R.id.session_1_name, R.id.session_1_live, R.id.session_1_day, R.id.session_1_time),
            RowIds(R.id.session_2_row, R.id.session_2_icon, R.id.session_2_name, R.id.session_2_live, R.id.session_2_day, R.id.session_2_time),
            RowIds(R.id.session_3_row, R.id.session_3_icon, R.id.session_3_name, R.id.session_3_live, R.id.session_3_day, R.id.session_3_time),
            RowIds(R.id.session_4_row, R.id.session_4_icon, R.id.session_4_name, R.id.session_4_live, R.id.session_4_day, R.id.session_4_time),
            RowIds(R.id.session_5_row, R.id.session_5_icon, R.id.session_5_name, R.id.session_5_live, R.id.session_5_day, R.id.session_5_time),
            RowIds(R.id.session_6_row, R.id.session_6_icon, R.id.session_6_name, R.id.session_6_live, R.id.session_6_day, R.id.session_6_time),
            RowIds(R.id.session_7_row, R.id.session_7_icon, R.id.session_7_name, R.id.session_7_live, R.id.session_7_day, R.id.session_7_time),
        )
    }
}
