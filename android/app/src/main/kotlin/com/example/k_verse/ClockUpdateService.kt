package com.example.k_verse

import android.app.Service
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Intent
import android.os.Handler
import android.os.IBinder
import java.text.SimpleDateFormat
import java.util.*

class ClockUpdateService : Service() {

    private val handler = Handler()
    private val runnable = object : Runnable {
        override fun run() {
            updateClockWidgets()
            handler.postDelayed(this, 1000)
        }
    }

    override fun onCreate() {
        super.onCreate()
        handler.post(runnable)
    }

    override fun onDestroy() {
        handler.removeCallbacks(runnable)
        super.onDestroy()
    }

    private fun updateClockWidgets() {

        val timeFormat = SimpleDateFormat("hh:mm:ss a", Locale.getDefault())
        val dateFormat = SimpleDateFormat("EEEE, dd MMM yyyy", Locale.getDefault())

        val now = Date()
        val time = timeFormat.format(now).uppercase(Locale.getDefault())
        val date = dateFormat.format(now)

        val manager = AppWidgetManager.getInstance(this)
        val ids = manager.getAppWidgetIds(
            ComponentName(this, UserHomeClockWidgetProvider::class.java)
        )

        ids.forEach { widgetId ->
            val intent = Intent(this, UserHomeClockWidgetProvider::class.java)
            intent.action = "CLOCK_WIDGET_UPDATE"
            intent.putExtra("widgetId", widgetId)
            intent.putExtra("time", time)
            intent.putExtra("date", date)
            sendBroadcast(intent)
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null
}