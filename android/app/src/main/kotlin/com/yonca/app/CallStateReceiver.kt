package com.yonca.app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.telephony.TelephonyManager

/** Listens for phone calls: shows the contact card when a saved contact rings, and asks to log the call when it ends. */
class CallStateReceiver : BroadcastReceiver() {
    @Suppress("DEPRECATION")
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != TelephonyManager.ACTION_PHONE_STATE_CHANGED) return
        when (intent.getStringExtra(TelephonyManager.EXTRA_STATE)) {
            TelephonyManager.EXTRA_STATE_RINGING -> {
                CallEnd.markActive(context)
                // Android sends the ringing broadcast twice; only the second one carries the number.
                val number = intent.getStringExtra(TelephonyManager.EXTRA_INCOMING_NUMBER)
                if (number.isNullOrBlank()) return
                val pending = goAsync()
                CallCard.showFor(context.applicationContext, number) { pending.finish() }
            }
            TelephonyManager.EXTRA_STATE_OFFHOOK -> CallEnd.markActive(context)
            TelephonyManager.EXTRA_STATE_IDLE -> {
                CallCard.hide()
                val pending = goAsync()
                CallEnd.onIdle(context.applicationContext) { pending.finish() }
            }
            else -> Unit
        }
    }
}
