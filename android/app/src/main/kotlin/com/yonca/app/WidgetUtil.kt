package com.yonca.app

import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.net.Uri
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent

/** Shared helpers for the home-screen widgets. */
object WidgetUtil {
    fun rtl(views: RemoteViews, root: Int, data: SharedPreferences) {
        val r = data.getBoolean("tw_rtl", false)
        views.setInt(root, "setLayoutDirection", if (r) View.LAYOUT_DIRECTION_RTL else View.LAYOUT_DIRECTION_LTR)
    }

    fun open(context: Context, uri: String) =
        HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java, Uri.parse(uri))

    fun dial(context: Context, phone: String, code: Int): PendingIntent {
        val i = Intent(Intent.ACTION_DIAL, Uri.parse("tel:" + Uri.encode(phone)))
        return PendingIntent.getActivity(
            context, code, i,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
    }
}
