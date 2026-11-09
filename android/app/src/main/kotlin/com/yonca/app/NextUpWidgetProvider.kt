package com.yonca.app

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider

/** Home-screen widget (2x2): the next task, meeting or event, with call and open buttons. */
class NextUpWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        appWidgetIds.forEach { id ->
            val v = RemoteViews(context.packageName, WidgetUtil.layout(widgetData, R.layout.nextup_widget, R.layout.nextup_widget_ar))
            WidgetUtil.rtl(v, R.id.nw_root, widgetData)
            v.setTextViewText(R.id.nw_when, widgetData.getString("nw_when", ""))
            v.setTextViewText(R.id.nw_title, widgetData.getString("nw_title", ""))
            v.setTextViewText(R.id.nw_sub, widgetData.getString("nw_sub", ""))
            val link = widgetData.getString("nw_link", "") ?: ""
            val uri = if (link.isEmpty()) "yonca://open" else "yonca://$link"
            v.setOnClickPendingIntent(R.id.nw_root, WidgetUtil.open(context, uri))
            v.setOnClickPendingIntent(R.id.nw_open, WidgetUtil.open(context, uri))
            val phone = widgetData.getString("nw_phone", "") ?: ""
            if (phone.isEmpty()) {
                v.setViewVisibility(R.id.nw_call, View.GONE)
            } else {
                v.setViewVisibility(R.id.nw_call, View.VISIBLE)
                v.setOnClickPendingIntent(R.id.nw_call, WidgetUtil.dial(context, phone, 200))
            }
            appWidgetManager.updateAppWidget(id, v)
        }
    }
}
