package com.gridglance.app

import android.content.SharedPreferences
import android.text.SpannableStringBuilder
import android.text.Spanned
import android.text.style.ForegroundColorSpan
import android.text.style.StyleSpan
import android.graphics.Typeface

/** Shared helpers for the driver/team podium widgets. */
object PodiumBinding {
    /**
     * "437 pts" for the leader, "374 pts  −63" (gap tinted red) for the rest,
     * so the podium shows the title fight at a glance without extra rows.
     */
    fun pointsWithGap(prefs: SharedPreferences, keyPrefix: String, position: Int): CharSequence {
        val points = prefs.getString("${keyPrefix}_${position}_pts", "0") ?: "0"
        val base = "$points pts"
        if (position == 1) return base
        val gap = WidgetInteractions.gapLabel(prefs.getString("${keyPrefix}_1_pts", null), points)
        if (gap.isEmpty() || gap == "LEADER") return base
        val builder = SpannableStringBuilder(base).append("  ")
        val start = builder.length
        builder.append(gap)
        builder.setSpan(
            ForegroundColorSpan(WidgetInteractions.COLOR_ACCENT),
            start,
            builder.length,
            Spanned.SPAN_EXCLUSIVE_EXCLUSIVE,
        )
        builder.setSpan(StyleSpan(Typeface.BOLD), start, builder.length, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
        return builder
    }
}
