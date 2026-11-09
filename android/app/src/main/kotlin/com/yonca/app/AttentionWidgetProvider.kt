package com.yonca.app

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider

/** Home-screen widget: contacts that need attention, with a call button per row. */
class AttentionWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        val rows = listOf(
            intArrayOf(R.id.aw_row1, R.id.aw_ini1, R.id.aw_name1, R.id.aw_sub1, R.id.aw_call1, R.id.aw_info1),
            intArrayOf(R.id.aw_row2, R.id.aw_ini2, R.id.aw_name2, R.id.aw_sub2, R.id.aw_call2, R.id.aw_info2),
            intArrayOf(R.id.aw_row3, R.id.aw_ini3, R.id.aw_name3, R.id.aw_sub3, R.id.aw_call3, R.id.aw_info3)
        )
        appWidgetIds.forEach { id ->
            val v = RemoteViews(context.packageName, R.layout.attention_widget)
            WidgetUtil.rtl(v, R.id.aw_root, widgetData)
            v.setTextViewText(R.id.aw_title, widgetData.getString("aw_title", "Needs attention"))
            val count = widgetData.getInt("aw_count", 0)
            val total = widgetData.getString("aw_total", "") ?: ""
            v.setViewVisibility(R.id.aw_count, if (count > 0 && total.isNotEmpty()) View.VISIBLE else View.GONE)
            v.setTextViewText(R.id.aw_count, total)
            v.setViewVisibility(R.id.aw_empty, if (count == 0) View.VISIBLE else View.GONE)
            v.setTextViewText(R.id.aw_empty, widgetData.getString("aw_empty", ""))
            v.setOnClickPendingIntent(R.id.aw_root, WidgetUtil.open(context, "yonca://open"))
            rows.forEachIndexed { i, r ->
                val on = i < count
                v.setViewVisibility(r[0], if (on) View.VISIBLE else View.GONE)
                if (!on) return@forEachIndexed
                v.setTextViewText(r[1], widgetData.getString("aw_${i}_ini", ""))
                v.setTextViewText(r[2], widgetData.getString("aw_${i}_name", ""))
                v.setTextViewText(r[3], widgetData.getString("aw_${i}_sub", ""))
                val cid = widgetData.getString("aw_${i}_id", "") ?: ""
                v.setOnClickPendingIntent(r[5], WidgetUtil.open(context, "yonca://contact/$cid"))
                v.setOnClickPendingIntent(r[1], WidgetUtil.open(context, "yonca://contact/$cid"))
                val phone = widgetData.getString("aw_${i}_phone", "") ?: ""
                if (phone.isEmpty()) {
                    v.setViewVisibility(r[4], View.INVISIBLE)
                } else {
                    v.setViewVisibility(r[4], View.VISIBLE)
                    v.setOnClickPendingIntent(r[4], WidgetUtil.dial(context, phone, 100 + i))
                }
            }
            appWidgetManager.updateAppWidget(id, v)
        }
    }
}
