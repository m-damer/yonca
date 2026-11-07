package com.yonca.app

import android.Manifest
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.provider.CallLog
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import org.json.JSONObject
import kotlin.concurrent.thread

/** After a call ends: reads it from the call log and asks to log it (a card for saved contacts, a notification for everyone). */
object CallEnd {
    private const val CHANNEL = "call_log"
    private const val MIN_SECONDS = 5
    private const val RECENT_MS = 5 * 60 * 1000L

    private fun widgetPrefs(c: Context) = c.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
    private fun state(c: Context) = c.getSharedPreferences("yonca_calls_state", Context.MODE_PRIVATE)

    fun markActive(c: Context) = state(c).edit().putBoolean("active", true).apply()

    /** Called when the phone goes idle. Does nothing unless a call was in progress. */
    fun onIdle(c: Context, done: () -> Unit) {
        val st = state(c)
        if (!st.getBoolean("active", false)) {
            done()
            return
        }
        st.edit().putBoolean("active", false).apply()
        if (!widgetPrefs(c).getBoolean("cc_after", false) ||
            c.checkSelfPermission(Manifest.permission.READ_CALL_LOG) != PackageManager.PERMISSION_GRANTED
        ) {
            done()
            return
        }
        thread {
            try {
                // The phone writes the call into the log a moment after it ends.
                Thread.sleep(2000)
                process(c)
            } catch (e: Exception) {
                // Nothing to ask about.
            } finally {
                done()
            }
        }
    }

    private fun str(c: Context, key: String, fallback: String) = widgetPrefs(c).getString(key, fallback) ?: fallback

    /** Picks the text for the count by the Arabic plural rules (other languages use one form). */
    private fun plural(c: Context, base: String, fallback: String, n: Int): String {
        val ar = widgetPrefs(c).getString("cc_lang", "en") == "ar"
        val form = if (!ar) "other" else when {
            n == 1 -> "one"
            n == 2 -> "two"
            n % 100 in 3..10 -> "few"
            n % 100 in 11..99 -> "many"
            else -> "other"
        }
        return str(c, "${base}_$form", str(c, "${base}_other", fallback)).replace("{n}", n.toString())
    }

    private fun process(c: Context) {
        val cur = c.contentResolver.query(
            CallLog.Calls.CONTENT_URI,
            arrayOf(CallLog.Calls._ID, CallLog.Calls.NUMBER, CallLog.Calls.TYPE, CallLog.Calls.DATE, CallLog.Calls.DURATION),
            null, null, "${CallLog.Calls.DATE} DESC"
        ) ?: return
        val id: String
        val number: String
        val type: Int
        val at: Long
        val sec: Int
        cur.use {
            if (!it.moveToFirst()) return
            id = it.getString(0)
            number = it.getString(1) ?: ""
            type = it.getInt(2)
            at = it.getLong(3)
            sec = it.getInt(4)
        }
        if (number.isBlank()) return
        if (System.currentTimeMillis() - at > RECENT_MS) return
        val seen = state(c)
        if (seen.getString("last", "") == id) return
        val missed = type == CallLog.Calls.MISSED_TYPE || type == CallLog.Calls.REJECTED_TYPE
        val answered = type == CallLog.Calls.INCOMING_TYPE || type == CallLog.Calls.OUTGOING_TYPE
        if (!missed && !answered) return
        if (answered && sec < MIN_SECONDS) return
        seen.edit().putString("last", id).apply()

        val data = CallCardData.find(c, number)
        val e = JSONObject()
        e.put("id", id)
        e.put("number", number)
        e.put("contactId", data?.contactId ?: -1L)
        e.put("name", data?.name ?: "")
        e.put("dir", if (type == CallLog.Calls.OUTGOING_TYPE) "out" else "in")
        e.put("missed", missed)
        e.put("sec", sec)
        e.put("at", at)
        e.put("outcome", "")
        CallLogStore.put(c, e)
        notify(c, e)
        if (data != null && CallCard.enabled(c)) CallCard.showAfter(c, data, e)
    }

    fun describe(c: Context, e: JSONObject): String {
        val kind = when {
            e.optBoolean("missed") -> str(c, "cc_dir_missed", "Missed call")
            e.optString("dir") == "out" -> str(c, "cc_dir_out", "Outgoing call")
            else -> str(c, "cc_dir_in", "Incoming call")
        }
        val sec = e.optInt("sec")
        if (e.optBoolean("missed") || sec <= 0) return kind
        val dur = if (sec < 60) plural(c, "cc_dur_sec", "{n} sec", sec) else plural(c, "cc_dur_min", "{n} min", (sec + 59) / 60)
        return "$kind · $dur"
    }

    private fun launch(c: Context, uri: String) = HomeWidgetLaunchIntent.getActivity(c, MainActivity::class.java, Uri.parse(uri))

    private fun action(c: Context, id: String, outcome: String, label: String, req: Int): NotificationCompat.Action {
        val i = Intent(c, CallActionReceiver::class.java).putExtra("id", id).putExtra("outcome", outcome)
        val pi = PendingIntent.getBroadcast(c, id.hashCode() + req, i, PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)
        return NotificationCompat.Action.Builder(0, label, pi).build()
    }

    private fun notify(c: Context, e: JSONObject) {
        val nm = c.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (nm.getNotificationChannel(CHANNEL) == null) {
            nm.createNotificationChannel(NotificationChannel(CHANNEL, str(c, "cc_channel", "Call log"), NotificationManager.IMPORTANCE_HIGH))
        }
        val id = e.getString("id")
        val saved = e.optLong("contactId", -1) > 0
        val b = NotificationCompat.Builder(c, CHANNEL)
            .setSmallIcon(c.applicationInfo.icon)
            .setAutoCancel(true)
            .setCategory(NotificationCompat.CATEGORY_STATUS)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
        if (saved) {
            b.setContentTitle(str(c, "cc_log_title", "Log call with {name}").replace("{name}", e.getString("name")))
            b.setContentText(describe(c, e))
            b.setContentIntent(launch(c, "yonca://log_call/$id"))
            if (e.optBoolean("missed")) {
                b.addAction(action(c, id, "noAnswer", str(c, "cc_o_noAnswer", "No answer"), 1))
            } else {
                b.addAction(action(c, id, "interested", str(c, "cc_o_interested", "Interested"), 1))
                b.addAction(action(c, id, "needsTime", str(c, "cc_o_needsTime", "Needs time"), 2))
                b.addAction(action(c, id, "notInterested", str(c, "cc_o_notInterested", "Not interested"), 3))
            }
        } else {
            b.setContentTitle(str(c, "cc_unsaved_title", "Unsaved number {number}").replace("{number}", e.getString("number")))
            b.setContentText(describe(c, e) + " · " + str(c, "cc_save_log", "Save and log this call"))
            b.setContentIntent(launch(c, "yonca://save_call/$id"))
            b.addAction(NotificationCompat.Action.Builder(0, str(c, "cc_save_log_btn", "Save and log"), launch(c, "yonca://save_call/$id")).build())
        }
        try {
            NotificationManagerCompat.from(c).notify(id.hashCode(), b.build())
        } catch (ex: SecurityException) {
            // Notifications are switched off for the app.
        }
    }

    fun cancel(c: Context, id: String) {
        try {
            NotificationManagerCompat.from(c).cancel(id.hashCode())
        } catch (ex: Exception) {
            // Nothing to cancel.
        }
    }
}
