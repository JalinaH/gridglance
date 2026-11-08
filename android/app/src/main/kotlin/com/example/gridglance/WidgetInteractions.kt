package com.gridglance.app

import android.app.AlarmManager
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
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
import java.util.Calendar
import java.util.Locale

/**
 * Shared click, scheduling and formatting helpers for every GridGlance
 * widget. Data refreshes automatically (Workmanager + in-app refreshes);
 * widgets only re-render locally between those.
 */
object WidgetInteractions {
    private const val TAG = "WidgetInteractions"

    const val ACTION_WIDGET_CLICK = "com.gridglance.app.WIDGET_CLICK"
    const val EXTRA_WIDGET_TYPE = "widget_type"
    const val EXTRA_TARGET_ID = "target_id"

    private const val KEY_UPDATED = "widgets_last_updated_ms"

    const val DAY_MS = 24L * 60L * 60L * 1000L


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

    // region Updated label

    /** "Updated 2:41 PM" from the last time Dart persisted widget data. */
    fun bindUpdatedLabel(context: Context, views: RemoteViews, prefs: SharedPreferences, labelId: Int) {
        val updated = prefs.getString(KEY_UPDATED, null)?.toLongOrNull()
        if (updated == null) {
            views.setViewVisibility(labelId, View.GONE)
            return
        }
        views.setTextViewText(labelId, "Updated ${formatUpdated(context, updated, System.currentTimeMillis())}")
        views.setTextColor(labelId, COLOR_DIM)
        views.setViewVisibility(labelId, View.VISIBLE)
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
}
