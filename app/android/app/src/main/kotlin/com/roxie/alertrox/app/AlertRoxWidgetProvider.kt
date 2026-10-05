package com.roxie.alertrox.app

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider

class AlertRoxWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        appWidgetIds.forEach { widgetId ->
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

                // Clicking the widget launches the app
                val intent = Intent(context, MainActivity::class.java)
                val pendingIntent = PendingIntent.getActivity(
                    context,
                    0,
                    intent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
                setOnClickPendingIntent(R.id.widget_root, pendingIntent)
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
