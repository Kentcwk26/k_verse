package com.example.k_verse

import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {

    private var startRoute: String? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        startRoute = intent.getStringExtra("route")
    }

    override fun getInitialRoute(): String {
        return startRoute ?: "/"
    }
}