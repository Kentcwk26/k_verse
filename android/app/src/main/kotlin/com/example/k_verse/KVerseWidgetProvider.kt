package com.example.k_verse

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.graphics.BitmapFactory
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetPlugin
import java.io.File

class KVerseWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        val prefs = HomeWidgetPlugin.getData(context)

        val imagePath = prefs.getString("wallpaper_image", null)
        val text = prefs.getString("wallpaper_text", "Tap to setup")

        for (widgetId in appWidgetIds) {
            val views = RemoteViews(
                context.packageName,
                R.layout.kverse_widget_layout
            )

            val imageFile = imagePath?.let { File(it) }

            if (imageFile != null && imageFile.exists()) {
                val bitmap = BitmapFactory.decodeFile(imageFile.absolutePath)
                if (bitmap != null) {
                    views.setImageViewBitmap(R.id.widget_image, bitmap)
                    views.setViewVisibility(R.id.widget_placeholder, android.view.View.GONE)
                }
            } else {
                views.setViewVisibility(R.id.widget_placeholder, android.view.View.VISIBLE)
            }

            views.setTextViewText(R.id.widget_text, text)

            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}