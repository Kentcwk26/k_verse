package com.example.k_verse

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.view.View
import android.widget.RemoteViews
import java.io.File

open class KVerseWidgetProviderBase(
    private val layoutId: Int
) : AppWidgetProvider() {

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)

        if (intent.action == "UPDATE_SINGLE_WIDGET") {
            val widgetId = intent.getIntExtra("widgetId", -1)
            val image = intent.getStringExtra("image")
            val text = intent.getStringExtra("text")
            val wallpaperId = intent.getStringExtra("wallpaperId")

            if (widgetId == -1) return
            val prefs = context.getSharedPreferences("kverse_widgets", Context.MODE_PRIVATE).edit()

            if (image != null) prefs.putString("image_$widgetId", image)
            if (text != null) prefs.putString("text_$widgetId", text)
            if (wallpaperId != null) prefs.putString("wp_$widgetId", wallpaperId)
            prefs.apply()

            val manager = AppWidgetManager.getInstance(context)
            updateWidget(context, manager, widgetId)
        }
    }

    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        for (id in ids) updateWidget(context, manager, id)
    }

    private fun decodeScaledBitmap(path: String, maxSize: Int = 1080): Bitmap? {
        val opts = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        BitmapFactory.decodeFile(path, opts)

        var scale = 1
        while (opts.outWidth / scale > maxSize || opts.outHeight / scale > maxSize) {
            scale *= 2
        }

        val finalOpts = BitmapFactory.Options().apply { inSampleSize = scale }
        return BitmapFactory.decodeFile(path, finalOpts)
    }

    private fun updateWidget(context: Context, manager: AppWidgetManager, widgetId: Int) {

        val prefs = context.getSharedPreferences("kverse_widgets", Context.MODE_PRIVATE)
        val imagePath = prefs.getString("image_$widgetId", null)
        val text = prefs.getString("text_$widgetId", "Tap to Setup")
        val views = RemoteViews(context.packageName, layoutId)

        if (imagePath != null) {
            val file = File(imagePath)
            if (file.exists()) {
                val bmp = decodeScaledBitmap(file.absolutePath)
                if (bmp != null) {
                    views.setImageViewBitmap(R.id.widget_image, bmp)
                    views.setViewVisibility(R.id.widget_image, View.VISIBLE)
                    views.setViewVisibility(R.id.widget_placeholder, View.GONE)
                }
            }
        } else {
            views.setViewVisibility(R.id.widget_image, View.GONE)
            views.setViewVisibility(R.id.widget_placeholder, View.VISIBLE)
        }

        views.setTextViewText(R.id.widget_text, text)

        val launchIntent = Intent(context, MainActivity::class.java).apply {
            putExtra("route", "/")
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }

        val pending = PendingIntent.getActivity(
            context,
            widgetId,
            launchIntent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )

        views.setOnClickPendingIntent(R.id.widget_root, pending)
        views.setOnClickPendingIntent(R.id.widget_placeholder, pending)

        manager.updateAppWidget(widgetId, views)
    }
}