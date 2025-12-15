package com.example.k_verse

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Color
import android.view.View
import android.widget.RemoteViews
import java.net.URL
import es.antonborri.home_widget.HomeWidgetPlugin

class UserHomeQuoteWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        manager: AppWidgetManager,
        ids: IntArray
    ) {
        ids.forEach { widgetId ->
            updateWidget(context, manager, widgetId)
        }
    }

    private fun loadImage(url: String?): Bitmap? {
        if (url.isNullOrEmpty()) return null
        return try {
            val connection = URL(url).openConnection()
            connection.connect()
            val input = connection.getInputStream()
            BitmapFactory.decodeStream(input)
        } catch (e: Exception) {
            e.printStackTrace()
            null
        }
    }

    private fun updateWidget(
        context: Context,
        manager: AppWidgetManager,
        widgetId: Int
    ) {
        val prefs = HomeWidgetPlugin.getData(context)

        val quote = prefs.getString(
            "quote_text",
            "Your quote will appear here"
        )

        val bgColor = prefs.getString(
            "quote_bg",
            "#303030"
        )

        val imageUrl = prefs.getString(
            "quote_image",
            null
        )

        val views = RemoteViews(
            context.packageName,
            R.layout.user_quote_widget_layout
        )

        // Quote text
        views.setTextViewText(R.id.quote_text, quote)

        // Background color
        try {
            views.setInt(
                R.id.quote_widget_root,
                "setBackgroundColor",
                Color.parseColor(bgColor)
            )
        } catch (_: Exception) {}

        // Background image
        val bmp = loadImage(imageUrl)
        if (bmp != null) {
            views.setViewVisibility(R.id.quote_bg_image, View.VISIBLE)
            views.setImageViewBitmap(R.id.quote_bg_image, bmp)
        } else {
            views.setViewVisibility(R.id.quote_bg_image, View.GONE)
        }

        manager.updateAppWidget(widgetId, views)
    }
}