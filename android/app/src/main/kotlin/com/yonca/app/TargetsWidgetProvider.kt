package com.yonca.app

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

/** Home-screen widget: progress of up to three targets (written by the app). Tap a row to open that target. */
class TargetsWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        val rows = listOf(
            intArrayOf(R.id.tw_row1, R.id.tw_label1, R.id.tw_value1, R.id.tw_bar1, R.id.tw_status1),
            intArrayOf(R.id.tw_row2, R.id.tw_label2, R.id.tw_value2, R.id.tw_bar2, R.id.tw_status2),
            intArrayOf(R.id.tw_row3, R.id.tw_label3, R.id.tw_value3, R.id.tw_bar3, R.id.tw_status3)
        )
        appWidgetIds.forEach { id ->
            val views = RemoteViews(context.packageName, WidgetUtil.layout(widgetData, R.layout.targets_widget, R.layout.targets_widget_ar))
            val rtl = widgetData.getBoolean("tw_rtl", false)
            views.setInt(R.id.tw_root, "setLayoutDirection", if (rtl) View.LAYOUT_DIRECTION_RTL else View.LAYOUT_DIRECTION_LTR)
            views.setTextViewText(R.id.tw_title, widgetData.getString("tw_title", "Targets"))
            val count = widgetData.getInt("tw_count", 0)
            val empty = widgetData.getString("tw_empty", "") ?: ""
            views.setViewVisibility(R.id.tw_empty, if (count == 0) View.VISIBLE else View.GONE)
            views.setTextViewText(R.id.tw_empty, empty)
            views.setOnClickPendingIntent(
                R.id.tw_root,
                HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java, Uri.parse("yonca://stats"))
            )
            rows.forEachIndexed { i, r ->
                val on = i < count
                views.setViewVisibility(r[0], if (on) View.VISIBLE else View.GONE)
                if (!on) return@forEachIndexed
                views.setTextViewText(r[1], widgetData.getString("tw_${i}_label", ""))
                views.setTextViewText(r[2], widgetData.getString("tw_${i}_value", ""))
                views.setProgressBar(r[3], 100, widgetData.getInt("tw_${i}_pct", 0), false)
                views.setTextViewText(r[4], widgetData.getString("tw_${i}_status", ""))
                views.setOnClickPendingIntent(
                    r[0],
                    HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java, Uri.parse("yonca://target/${widgetData.getInt("tw_${i}_metric", 0)}"))
                )
            }
            appWidgetManager.updateAppWidget(id, views)
        }
    }
}
