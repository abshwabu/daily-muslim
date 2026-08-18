package com.example.app

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

class DhikrWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.dhikr_widget).apply {
                val dhikrTitle = widgetData.getString("dhikr_title", "SUBHANALLAH")
                val dhikrMeaning = widgetData.getString("dhikr_meaning", "Glory be to Allah")
                val dhikrCount = widgetData.getString("dhikr_count", "0")
                val dhikrTarget = widgetData.getString("dhikr_target", "33")

                setTextViewText(R.id.tv_dhikr_arabic, dhikrTitle?.uppercase())
                setTextViewText(R.id.tv_dhikr_meaning, dhikrMeaning)
                setTextViewText(R.id.tv_dhikr_count, dhikrCount)
                setTextViewText(R.id.tv_dhikr_target, "Target: $dhikrTarget")

                val pendingIntent = HomeWidgetLaunchIntent.getActivity(
                    context,
                    MainActivity::class.java
                )
                setOnClickPendingIntent(R.id.dhikr_widget_root, pendingIntent)
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
