package com.example.k_verse

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Color
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetPlugin
import java.net.URL

class UserHomeClockWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        super.onUpdate(context, manager, ids)
        ids.forEach { widgetId ->
            updateClockWidget(context, manager, widgetId)
        }
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
            views.setTextViewText(R.id.clock_date, date)
            views.setTextViewText(R.id.clock_time, time)

            applyVisuals(context, views, widgetId)
            AppWidgetManager.getInstance(context).updateAppWidget(widgetId, views)
        }
    }

    companion object {
        fun updateClockWidget(context: Context, manager: AppWidgetManager, widgetId: Int) {
            val views = RemoteViews(context.packageName, R.layout.user_clock_widget_layout)
            applyVisuals(context, views, widgetId)

            val pendingIntent = PendingIntent.getActivity(
                context, widgetId, Intent(context, MainActivity::class.java),
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.clock_widget_root, pendingIntent)
            manager.updateAppWidget(widgetId, views)
        }

        private fun applyVisuals(context: Context, views: RemoteViews, widgetId: Int) {
            val prefs = HomeWidgetPlugin.getData(context)
            
            // 1. Background Color
            val bgColor = prefs.getString("bgColor_$widgetId", "#303030")!!
            try {
                views.setInt(R.id.clock_widget_root, "setBackgroundColor", Color.parseColor(bgColor))
            } catch (_: Exception) {}

            // 2. Background Image (URL)
            val bgImageUrl = prefs.getString("image_$widgetId", null)
            if (!bgImageUrl.isNullOrEmpty()) {
                val bmp = loadFromUrl(bgImageUrl)
                bmp?.let {
                    views.setViewVisibility(R.id.clock_bg_image, View.VISIBLE)
                    views.setImageViewBitmap(R.id.clock_bg_image, it)
                }
            }

            // 3. User Side Image (Now handling as URL)
            val userImageUrl = prefs.getString("user_image_path_$widgetId", null)
            if (!userImageUrl.isNullOrEmpty()) {
                val userBmp = loadFromUrl(userImageUrl) 
                if (userBmp != null) {
                    views.setViewVisibility(R.id.clock_bg_image, View.VISIBLE)
                    views.setImageViewBitmap(R.id.clock_bg_image, userBmp)
                }
            } else {
                views.setViewVisibility(R.id.clock_bg_image, View.GONE)
            }
        }

        private fun loadFromUrl(url: String): Bitmap? {
            return try {
                val conn = URL(url).openConnection()
                conn.connect()
                BitmapFactory.decodeStream(conn.getInputStream())
            } catch (e: Exception) {
                null
            }
        }
    }
}