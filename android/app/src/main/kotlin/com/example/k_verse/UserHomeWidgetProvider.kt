package com.example.k_verse

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.os.SystemClock
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider
import java.text.SimpleDateFormat
import java.util.*

class UserHomeWidgetProvider : HomeWidgetProvider() {

    override fun onUpdate(
        context: Context,
        manager: AppWidgetManager,
        ids: IntArray,
        prefs: android.content.SharedPreferences
    ) {
        ids.forEach { widgetId ->

            val views = RemoteViews(context.packageName, R.layout.user_widget_layout)

            val type = prefs.getString("type", "clock")
            val text = prefs.getString("text", "")
            val countdownDate = prefs.getString("countdownDate", "")
            val bgColor = prefs.getString("bgColor", "#303030")
            val title = prefs.getString("name", "My Widget")

            // Set Title
            views.setTextViewText(R.id.user_widget_title, title)

            // Clock (real-time)
            if (type == "clock") {
                val now = Calendar.getInstance().time
                val format = SimpleDateFormat("hh:mm a", Locale.getDefault())
                views.setTextViewText(R.id.user_widget_content, format.format(now))
            } else {
                val finalText = when (type) {
                    "quote" -> if (!text.isNullOrEmpty()) text else "Your Quote..."
                    "countdown" -> if (!countdownDate.isNullOrEmpty())
                        "Countdown to $countdownDate"
                    else "Countdown Date"
                    "calendar" -> SimpleDateFormat("dd/MM/yyyy", Locale.getDefault()).format(Date())
                    else -> text ?: ""
                }
                views.setTextViewText(R.id.user_widget_content, finalText)
            }

            // Background color
            try {
                val colorInt = android.graphics.Color.parseColor(bgColor)
                views.setInt(R.id.user_widget_root, "setBackgroundColor", colorInt)
            } catch (_: Exception) {}

            // Tap → open app
            val pendingIntent = HomeWidgetLaunchIntent.getActivity(
                context,
                MainActivity::class.java
            )
            views.setOnClickPendingIntent(R.id.user_widget_root, pendingIntent)

            manager.updateAppWidget(widgetId, views)
        }

        // ⏱️ Schedule clock update every minute
        scheduleNextUpdate(context)
    }

    private fun scheduleNextUpdate(context: Context) {
        val intent = Intent(context, javaClass).apply {
            action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
        }

        val pendingIntent = PendingIntent.getBroadcast(
            context,
            0,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as android.app.AlarmManager

        val triggerTime = SystemClock.elapsedRealtime() + 60 * 1000 // 1 minute

        alarmManager.setExact(
            android.app.AlarmManager.ELAPSED_REALTIME_WAKEUP,
            triggerTime,
            pendingIntent
        )
    }
}
