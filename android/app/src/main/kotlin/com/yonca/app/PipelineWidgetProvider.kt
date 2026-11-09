package com.yonca.app

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider

/** Home-screen widget: open pipeline value, deal count and a stacked stage bar. */
class PipelineWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        val bars = intArrayOf(R.id.pw_bar1, R.id.pw_bar2, R.id.pw_bar3, R.id.pw_bar4)
        val legs = intArrayOf(R.id.pw_leg1, R.id.pw_leg2, R.id.pw_leg3)
        appWidgetIds.forEach { id ->
            val v = RemoteViews(context.packageName, R.layout.pipeline_widget)
            WidgetUtil.rtl(v, R.id.pw_root, widgetData)
            val has = widgetData.getBoolean("pw_has", false)
            v.setTextViewText(R.id.pw_title, widgetData.getString("pw_title", "Pipeline"))
            v.setTextViewText(R.id.pw_deals, widgetData.getString("pw_deals", ""))
            v.setTextViewText(R.id.pw_value, widgetData.getString("pw_value", ""))
            v.setViewVisibility(R.id.pw_value, if (has) View.VISIBLE else View.GONE)
            v.setViewVisibility(R.id.pw_bars, if (has) View.VISIBLE else View.GONE)
            v.setViewVisibility(R.id.pw_empty, if (has) View.GONE else View.VISIBLE)
            v.setTextViewText(R.id.pw_empty, widgetData.getString("pw_empty", ""))
            bars.forEachIndexed { i, b ->
                v.setProgressBar(b, 100, widgetData.getInt("pw_b${i + 1}", 0), false)
            }
            legs.forEachIndexed { i, l ->
                val t = widgetData.getString("pw_leg${i + 1}", "") ?: ""
                v.setViewVisibility(l, if (has && t.isNotEmpty()) View.VISIBLE else View.GONE)
                v.setTextViewText(l, t)
            }
            v.setOnClickPendingIntent(R.id.pw_root, WidgetUtil.open(context, "yonca://deals"))
            appWidgetManager.updateAppWidget(id, v)
        }
    }
}
