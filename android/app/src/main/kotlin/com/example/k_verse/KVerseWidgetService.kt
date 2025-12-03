package com.example.k_verse

import android.widget.RemoteViewsService

class KVerseWidgetService : RemoteViewsService() {
    override fun onGetViewFactory(intent: android.content.Intent?): RemoteViewsFactory? = null
}