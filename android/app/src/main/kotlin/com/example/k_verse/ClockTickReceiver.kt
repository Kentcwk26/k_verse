package com.example.k_verse

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

class ClockTickReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == "CLOCK_TICK") {
            val updateIntent = Intent(context, UserHomeClockWidgetProvider::class.java)
            updateIntent.action = "CLOCK_WIDGET_UPDATE"
            context.sendBroadcast(updateIntent)
        }
    }
}