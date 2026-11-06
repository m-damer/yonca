package com.yonca.app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/** A button on the "Log call" notification: stores the chosen outcome; the app logs the call when it next opens. */
class CallActionReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val id = intent.getStringExtra("id") ?: return
        val outcome = intent.getStringExtra("outcome") ?: return
        CallLogStore.setOutcome(context, id, outcome)
        CallEnd.cancel(context, id)
        CallCard.hide()
    }
}
