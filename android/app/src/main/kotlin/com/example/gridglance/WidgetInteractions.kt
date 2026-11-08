package com.gridglance.app

import android.app.AlarmManager
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.BroadcastReceiver
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.net.Uri
import android.os.Build
import android.text.format.DateFormat
import android.util.Log
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetBackgroundReceiver
import java.util.Calendar
import java.util.Locale

/**
 * Shared click, refresh and formatting helpers for every GridGlance widget.
 *
 * Refresh flow: the ↻ button hits [WidgetRefreshReceiver], which marks the
 * request time and re-renders all widgets immediately ("Updating…"), then
 * forwards to home_widget's background receiver so Dart fetches fresh data
 * and reloads the widgets. A safety re-render clears the busy state if the
 * Dart side never answers (e.g. the app hasn't been opened since install).
 */
object WidgetInteractions {
    private const val TAG = "WidgetInteractions"

    const val ACTION_WIDGET_CLICK = "com.gridglance.app.WIDGET_CLICK"
    const val EXTRA_WIDGET_TYPE = "widget_type"
    const val EXTRA_TARGET_ID = "target_id"

    private const val KEY_REQUESTED = "widgets_refresh_requested_ms"
    private const val KEY_UPDATED = "widgets_last_updated_ms"
    private const val KEY_ATTEMPT = "widgets_last_attempt_ms"
    private const val KEY_ATTEMPT_OK = "widgets_last_attempt_ok"
    private const val REFRESH_TIMEOUT_MS = 60_000L

    const val DAY_MS = 24L * 60L * 60L * 1000L

    val ALL_PROVIDERS: List<Class<out AppWidgetProvider>> = listOf(
        DriverStandingsWidgetProvider::class.java,
        TeamStandingsWidgetProvider::class.java,
        FavoriteDriverWidgetProvider::class.java,
        FavoriteTeamWidgetProvider::class.java,
        NextSessionWidgetProvider::class.java,
        RaceWeekendWidgetProvider::class.java,
    )

    // region Click intents

    /**
     * Opens the app and tells Flutter where to go. [slot] names the
     * clickable area so each gets its own PendingIntent.
     */
    fun openApp(
        context: Context,
        type: String,
        appWidgetId: Int,
        slot: String = "root",
        targetId: String? = null,
    ): PendingIntent {
        val intent = Intent(context, MainActivity::class.java).apply {
            action = ACTION_WIDGET_CLICK
            putExtra(EXTRA_WIDGET_TYPE, type)
            putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
            if (!targetId.isNullOrEmpty()) putExtra(EXTRA_TARGET_ID, targetId)
        }
        // No intent data here: Flutter could treat it as a deep-link route.
        // A per-slot request code keeps each area's extras separate instead.
        return PendingIntent.getActivity(
            context,
            "$type/$appWidgetId/$slot".hashCode(),
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    fun refresh(context: Context): PendingIntent {
        val intent = Intent(context, WidgetRefreshReceiver::class.java).apply {
            action = WidgetRefreshReceiver.ACTION_REFRESH
        }
        return PendingIntent.getBroadcast(
            context,
            0,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    /** Broadcast that re-renders [provider] from stored data (no network). */
    fun rerender(context: Context, provider: Class<out AppWidgetProvider>): PendingIntent {
        val intent = Intent(context, provider).apply {
            action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
            data = Uri.parse("gridglance://rerender/${provider.simpleName}")
            putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, widgetIds(context, provider))
        }
        return PendingIntent.getBroadcast(
            context,
            0,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    fun widgetIds(context: Context, provider: Class<out AppWidgetProvider>): IntArray =
        AppWidgetManager.getInstance(context).getAppWidgetIds(ComponentName(context, provider))

    fun rerenderAll(context: Context) {
        for (provider in ALL_PROVIDERS) {
            val ids = widgetIds(context, provider)
            if (ids.isEmpty()) continue
            context.sendBroadcast(
                Intent(context, provider).apply {
                    action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
                    putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, ids)
                },
            )
        }
    }

    /** Re-render [provider] at [atMs] (used for countdown/session transitions). */
    fun scheduleRerender(context: Context, provider: Class<out AppWidgetProvider>, atMs: Long?) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as? AlarmManager ?: return
        val pending = rerender(context, provider)
        if (atMs == null) {
            alarmManager.cancel(pending)
            return
        }
        try {
            val canExact = Build.VERSION.SDK_INT < Build.VERSION_CODES.S || alarmManager.canScheduleExactAlarms()
            if (canExact) {
                alarmManager.setExactAndAllowWhileIdle(AlarmManager.RTC, atMs, pending)
            } else {
                alarmManager.setAndAllowWhileIdle(AlarmManager.RTC, atMs, pending)
            }
        } catch (e: SecurityException) {
            Log.w(TAG, "Exact alarm denied, falling back to inexact", e)
            alarmManager.set(AlarmManager.RTC, atMs, pending)
        }
    }

    // endregion

    // region Refresh status

    internal fun markRefreshRequested(context: Context) {
        WidgetPreferences.get(context).edit()
            .putString(KEY_REQUESTED, System.currentTimeMillis().toString())
            .apply()
    }

    fun isRefreshing(prefs: SharedPreferences, now: Long = System.currentTimeMillis()): Boolean {
        val requested = prefs.getString(KEY_REQUESTED, null)?.toLongOrNull() ?: return false
        val updated = prefs.getString(KEY_UPDATED, null)?.toLongOrNull() ?: 0L
        val attempt = prefs.getString(KEY_ATTEMPT, null)?.toLongOrNull() ?: 0L
        return requested > maxOf(updated, attempt) && now - requested < REFRESH_TIMEOUT_MS
    }

    /**
     * Binds the "Updated 2:41 PM" / "Updating…" / "Offline" label and the
     * refresh button. With [compact] the label is hidden unless it has
     * something urgent to say (busy or failed).
     */
    fun bindStatus(
        context: Context,
        views: RemoteViews,
        prefs: SharedPreferences,
        labelId: Int,
        refreshButtonId: Int,
        compact: Boolean = false,
    ) {
        views.setOnClickPendingIntent(refreshButtonId, refresh(context))
        val now = System.currentTimeMillis()
        val updated = prefs.getString(KEY_UPDATED, null)?.toLongOrNull()
        val attempt = prefs.getString(KEY_ATTEMPT, null)?.toLongOrNull() ?: 0L
        val attemptFailed = prefs.getString(KEY_ATTEMPT_OK, "true") == "false" &&
            attempt > (updated ?: 0L)

        val (text, color, alwaysShow) = when {
            isRefreshing(prefs, now) -> Triple("Updating…", COLOR_ACCENT, true)
            attemptFailed && now - attempt < 30 * 60_000L -> Triple("Offline", COLOR_WARN, true)
            updated != null -> Triple("Updated ${formatUpdated(context, updated, now)}", COLOR_DIM, false)
            else -> Triple("", COLOR_DIM, false)
        }
        views.setTextViewText(labelId, text)
        views.setTextColor(labelId, color)
        val visible = text.isNotEmpty() && (alwaysShow || !compact)
        views.setViewVisibility(labelId, if (visible) View.VISIBLE else View.GONE)
        views.setInt(
            refreshButtonId,
            "setImageAlpha",
            if (isRefreshing(prefs, now)) 110 else 255,
        )
    }

    // endregion

    // region Formatting

    private fun calendarAt(ms: Long): Calendar = Calendar.getInstance().apply { timeInMillis = ms }

    fun formatTime(context: Context, ms: Long): String =
        DateFormat.getTimeFormat(context).format(ms)

    fun formatDay(ms: Long): String {
        val cal = calendarAt(ms)
        val dow = cal.getDisplayName(Calendar.DAY_OF_WEEK, Calendar.SHORT, Locale.getDefault()) ?: ""
        return "${dow.uppercase(Locale.getDefault())} ${cal.get(Calendar.DAY_OF_MONTH)}"
    }

    fun formatDayTime(context: Context, ms: Long): String {
        val dow = calendarAt(ms).getDisplayName(Calendar.DAY_OF_WEEK, Calendar.SHORT, Locale.getDefault()) ?: ""
        return "$dow · ${formatTime(context, ms)}"
    }

    private fun formatUpdated(context: Context, ms: Long, now: Long): String {
        val then = calendarAt(ms)
        val today = calendarAt(now)
        val sameDay = then.get(Calendar.YEAR) == today.get(Calendar.YEAR) &&
            then.get(Calendar.DAY_OF_YEAR) == today.get(Calendar.DAY_OF_YEAR)
        if (sameDay) return formatTime(context, ms)
        val month = then.getDisplayName(Calendar.MONTH, Calendar.SHORT, Locale.getDefault()) ?: ""
        return "$month ${then.get(Calendar.DAY_OF_MONTH)}"
    }

    fun formatDuration(remainingMs: Long): String {
        val totalMinutes = remainingMs / 60_000L
        val days = totalMinutes / (60L * 24L)
        val hours = (totalMinutes / 60L) % 24L
        val minutes = totalMinutes % 60L
        return when {
            days > 0L -> "${days}d ${hours}h"
            hours > 0L -> "${hours}h ${minutes}m"
            else -> "${minutes}m"
        }
    }

    /** Approximate on-track length, used to show LIVE and mark sessions done. */
    fun sessionDurationMs(name: String): Long {
        val lower = name.lowercase(Locale.US)
        val minutes = when {
            lower == "race" || lower.endsWith("grand prix") -> 120L
            lower.contains("sprint") && (lower.contains("qual") || lower.contains("shootout")) -> 45L
            else -> 60L
        }
        return minutes * 60_000L
    }

    /** Points gap label for podium widgets: "LEADER" or "−63". */
    fun gapLabel(leaderPoints: String?, points: String?): String {
        val leader = leaderPoints?.toDoubleOrNull() ?: return ""
        val mine = points?.toDoubleOrNull() ?: return ""
        val gap = leader - mine
        if (gap <= 0.0) return "LEADER"
        val text = if (gap % 1.0 == 0.0) gap.toLong().toString() else String.format(Locale.US, "%.1f", gap)
        return "−$text"
    }

    // endregion

    const val COLOR_BRIGHT = 0xFFF7F8FA.toInt()
    const val COLOR_NORMAL = 0xFFC9D0DA.toInt()
    const val COLOR_DIM = 0xFF6B7586.toInt()
    const val COLOR_ACCENT = 0xFFFF5A4F.toInt()
    const val COLOR_WARN = 0xFFF5B942.toInt()
}

/** Handles the ↻ button on every widget. */
class WidgetRefreshReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == ACTION_RERENDER_ALL) {
            WidgetInteractions.rerenderAll(context)
            return
        }
        if (intent.action != ACTION_REFRESH) return
        WidgetInteractions.markRefreshRequested(context)
        // Instant feedback: show "Updating…" on every widget.
        WidgetInteractions.rerenderAll(context)

        // Hand off to Dart (home_widget interactivity callback) for real data.
        try {
            context.sendBroadcast(
                Intent(context, HomeWidgetBackgroundReceiver::class.java).apply {
                    action = "es.antonborri.home_widget.action.BACKGROUND"
                    data = Uri.parse("gridglance://refresh")
                },
            )
        } catch (e: Exception) {
            Log.w("WidgetRefreshReceiver", "Background refresh dispatch failed", e)
        }

        // Safety net: clear the busy state even if Dart never reloads us.
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as? AlarmManager ?: return
        val clear = PendingIntent.getBroadcast(
            context,
            1,
            Intent(context, WidgetRefreshReceiver::class.java).apply { action = ACTION_RERENDER_ALL },
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        alarmManager.set(AlarmManager.RTC, System.currentTimeMillis() + 65_000L, clear)
    }

    companion object {
        const val ACTION_REFRESH = "com.gridglance.app.WIDGET_REFRESH"
        const val ACTION_RERENDER_ALL = "com.gridglance.app.WIDGET_RERENDER_ALL"
    }
}
