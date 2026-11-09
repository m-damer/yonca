package com.yonca.app

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider

/** Home-screen widget (4x1): new contact, new task, search, scan QR. */
class QuickWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        val cells = listOf(
            Triple(R.id.qw_1, R.id.qw_l1, "new_contact"),
            Triple(R.id.qw_2, R.id.qw_l2, "new_task"),
            Triple(R.id.qw_3, R.id.qw_l3, "search"),
            Triple(R.id.qw_4, R.id.qw_l4, "scan")
        )
        val defaults = listOf("New contact", "New task", "Search", "Scan QR")
        appWidgetIds.forEach { id ->
            val v = RemoteViews(context.packageName, WidgetUtil.layout(widgetData, R.layout.quick_widget, R.layout.quick_widget_ar))
            WidgetUtil.rtl(v, R.id.qw_root, widgetData)
            cells.forEachIndexed { i, c ->
                v.setTextViewText(c.second, widgetData.getString("qw_l${i + 1}", defaults[i]))
                v.setOnClickPendingIntent(c.first, WidgetUtil.open(context, "yonca://${c.third}"))
            }
            appWidgetManager.updateAppWidget(id, v)
        }
    }
}
