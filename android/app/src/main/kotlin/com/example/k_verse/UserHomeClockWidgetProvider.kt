package com.example.k_verse

import android.content.ComponentName
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import java.net.URL
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetPlugin

class UserHomeClockWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        super.onUpdate(context, manager, ids)

        ids.forEach { widgetId ->
            updateClockWidget(context, manager, widgetId)
        }

        // Start service only once
        context.startService(Intent(context, ClockUpdateService::class.java))
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)

        if (intent.action == "CLOCK_WIDGET_UPDATE") {

            val widgetId = intent.getIntExtra("widgetId", -1)
            val time = intent.getStringExtra("time")
            val date = intent.getStringExtra("date")

            if (widgetId == -1 || time == null || date == null) return

            val views = RemoteViews(context.packageName, R.layout.user_clock_widget_layout)

            // Set date/time
            views.setTextViewText(R.id.clock_date, date)
            views.setTextViewText(R.id.clock_time, time)

            // Load saved background
            val prefs = HomeWidgetPlugin.getData(context)
            val bgColor = prefs.getString("bgColor", "#303030")!!
            val imageUrl = prefs.getString("imageUrl", null)

            try {
                views.setInt(R.id.clock_widget_root, "setBackgroundColor", Color.parseColor(bgColor))
            } catch (_: Exception) {}

            if (!imageUrl.isNullOrEmpty()) {
                val bmp = loadImage(imageUrl)
                if (bmp != null) {
                    views.setViewVisibility(R.id.clock_bg_image, android.view.View.VISIBLE)
                    views.setImageViewBitmap(R.id.clock_bg_image, bmp)
                }
            } else {
                views.setViewVisibility(R.id.clock_bg_image, android.view.View.GONE)
            }

            AppWidgetManager.getInstance(context).updateAppWidget(widgetId, views)
        }
    }

    companion object {

        fun loadImage(url: String?): Bitmap? {
            if (url.isNullOrEmpty()) return null
            return try {
                val conn = URL(url).openConnection()
                conn.connect()
                BitmapFactory.decodeStream(conn.getInputStream())
            } catch (e: Exception) {
                null
            }
        }

        fun updateClockWidget(
            context: Context,
            manager: AppWidgetManager,
            widgetId: Int
        ) {

            val prefs = HomeWidgetPlugin.getData(context)

            val bgColor = prefs.getString("bgColor", "#303030")!!
            val imageUrl = prefs.getString("imageUrl", null)

            val views = RemoteViews(context.packageName, R.layout.user_clock_widget_layout)

            // Background
            try {
                views.setInt(R.id.clock_widget_root, "setBackgroundColor", Color.parseColor(bgColor))
            } catch (_: Exception) {}

            // Background image
            if (!imageUrl.isNullOrEmpty()) {
                val bmp = loadImage(imageUrl)
                if (bmp != null) {
                    views.setViewVisibility(R.id.clock_bg_image, android.view.View.VISIBLE)
                    views.setImageViewBitmap(R.id.clock_bg_image, bmp)
                }
            } else {
                views.setViewVisibility(R.id.clock_bg_image, android.view.View.GONE)
            }

            // Placeholder time until service updates
            views.setTextViewText(R.id.clock_time, "--:--:--")

            // Open app on click
            val pendingIntent = PendingIntent.getActivity(
                context,
                widgetId,
                Intent(context, MainActivity::class.java),
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.clock_widget_root, pendingIntent)

            manager.updateAppWidget(widgetId, views)
        }
    }
}