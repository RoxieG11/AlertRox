package com.roxie.alertrox.app

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.util.Log
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

class AlertRoxWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        appWidgetIds.forEach { widgetId ->
            try {
                val views = RemoteViews(context.packageName, R.layout.alertrox_widget).apply {
                    val deviceName = widgetData.getString("device_name", "AlertRox PC") ?: "AlertRox PC"
                    val status = widgetData.getString("device_status", "● ÇEVRİMİÇİ") ?: "● ÇEVRİMİÇİ"
                    val lastSeen = widgetData.getString("last_seen", "--:--") ?: "--:--"
                    val isOnline = widgetData.getBoolean("is_online", false)

                    setTextViewText(R.id.widget_device_name, deviceName)
                    setTextViewText(R.id.widget_status, status)
                    setTextViewText(R.id.widget_last_seen, "Son nabız: $lastSeen")

                    val statusColor = if (isOnline) 0xFF10B981.toInt() else 0xFFEF4444.toInt()
                    setTextColor(R.id.widget_status, statusColor)

                    // Clicking the widget launches the app safely via HomeWidgetLaunchIntent
                    val pendingIntent = HomeWidgetLaunchIntent.getActivity(
                        context,
                        MainActivity::class.java
                    )
                    setOnClickPendingIntent(R.id.widget_root, pendingIntent)
                }
                appWidgetManager.updateAppWidget(widgetId, views)
            } catch (e: Exception) {
                Log.e("AlertRoxWidget", "Error updating widget ID $widgetId: ${e.message}", e)
            }
        }
    }
}
