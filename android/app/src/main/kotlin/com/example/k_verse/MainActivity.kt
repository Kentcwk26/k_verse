package com.example.k_verse

import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Intent
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import com.example.k_verse.KVerseWidgetProvider

class MainActivity : FlutterActivity() {

    private val CHANNEL = "kverse/widget"
    private var startRoute: String? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        startRoute = intent.getStringExtra("route")
    }

    override fun getInitialRoute(): String? {
        return startRoute ?: "/"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {

                    "getWidgets" -> {
                        val manager = AppWidgetManager.getInstance(this)
                        val ids = manager.getAppWidgetIds(ComponentName(this, KVerseWidgetProvider::class.java))
                        result.success(ids.toList())
                    }

                    "updateWidget" -> {
                        val widgetId = call.argument<Int>("widgetId")
                        val image = call.argument<String>("image")
                        val text = call.argument<String>("text")
                        val wallpaperId = call.argument<String>("wallpaperId")

                        if (widgetId == null) {
                            result.error("NO_ID", "Missing widgetId", null)
                            return@setMethodCallHandler
                        }

                        val intent = Intent(this, KVerseWidgetProvider::class.java).apply {
                            action = "UPDATE_SINGLE_WIDGET"
                            putExtra("widgetId", widgetId)
                            putExtra("image", image)
                            putExtra("text", text)
                            putExtra("wallpaperId", wallpaperId)
                        }

                        sendBroadcast(intent)
                        result.success(true)
                    }

                    else -> result.notImplemented()
                }
            }
    }
}