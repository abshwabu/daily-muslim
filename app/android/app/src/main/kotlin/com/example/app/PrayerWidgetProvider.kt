package com.example.app

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

class PrayerWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.prayer_widget).apply {
                val nextPrayer = widgetData.getString("next_prayer_name", "DHUHR")
                val prayerTime = widgetData.getString("next_prayer_time", "12:28")
                val countdown = widgetData.getString("time_until_next", "Upcoming")
                val city = widgetData.getString("city_name", "Addis Ababa")
                val tasks = widgetData.getString("tasks_summary", "Daily Muslim • Sakinah")

                setTextViewText(R.id.tv_prayer_name, nextPrayer?.uppercase())
                setTextViewText(R.id.tv_prayer_time, prayerTime)
                setTextViewText(R.id.tv_countdown, countdown)
                setTextViewText(R.id.tv_city, city)
                setTextViewText(R.id.tv_footer_tasks, tasks)

                val pendingIntent = HomeWidgetLaunchIntent.getActivity(
                    context,
                    MainActivity::class.java
                )
                setOnClickPendingIntent(R.id.widget_root, pendingIntent)
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
