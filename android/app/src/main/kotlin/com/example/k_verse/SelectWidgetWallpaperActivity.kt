package com.example.k_verse

import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity

class SelectWidgetWallpaperActivity : FlutterActivity() {

    override fun getInitialRoute(): String {
        val widgetId = intent?.getIntExtra("widgetId", -1) ?: -1
        return "/selectWidgetWallpaper/$widgetId"
    }
}