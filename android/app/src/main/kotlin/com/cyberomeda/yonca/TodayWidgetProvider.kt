package com.cyberomeda.yonca

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

/** Home-screen widget: today's items (written by the app) plus Quick add and Search buttons. */
class TodayWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        appWidgetIds.forEach { id ->
            val views = RemoteViews(context.packageName, R.layout.today_widget)
            views.setTextViewText(R.id.widget_title, widgetData.getString("title", "YONCA"))
            views.setTextViewText(R.id.widget_lines, widgetData.getString("lines", ""))
            views.setTextViewText(R.id.widget_add, widgetData.getString("add_label", "New contact"))
            views.setTextViewText(R.id.widget_search, widgetData.getString("search_label", "Search"))
            views.setOnClickPendingIntent(
                R.id.widget_root,
                HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java, Uri.parse("yonca://open"))
            )
            views.setOnClickPendingIntent(
                R.id.widget_add,
                HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java, Uri.parse("yonca://new_contact"))
            )
            views.setOnClickPendingIntent(
                R.id.widget_search,
                HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java, Uri.parse("yonca://search"))
            )
            appWidgetManager.updateAppWidget(id, views)
        }
    }
}
