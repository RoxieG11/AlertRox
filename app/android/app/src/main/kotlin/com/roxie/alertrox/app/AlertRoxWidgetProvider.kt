package com.roxie.alertrox.app

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.util.Log
import android.view.View
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
                    val isShuttingDown = widgetData.getBoolean("is_shutting_down", false)
                    val shutdownCountdown = widgetData.getString("shutdown_countdown", "") ?: ""

                    setTextViewText(R.id.widget_device_name, deviceName)
                    setTextViewText(R.id.widget_status, status)
                    setTextViewText(R.id.widget_last_seen, lastSeen)

                    val statusColor = if (isOnline) 0xFF10B981.toInt() else 0xFFEF4444.toInt()
                    setTextColor(R.id.widget_status, statusColor)

                    val widgetTheme = widgetData.getString("widget_theme", "dark") ?: "dark"
                    val isLight = widgetTheme == "light"

                    if (isLight) {
                        setInt(R.id.widget_root, "setBackgroundResource", R.drawable.widget_bg_light)
                        setTextColor(R.id.widget_device_name, 0xFF0F172A.toInt())
                        setTextColor(R.id.widget_brand, 0xFF64748B.toInt())
                        setTextColor(R.id.widget_last_seen, 0xFF475569.toInt())
                    } else {
                        setInt(R.id.widget_root, "setBackgroundResource", R.drawable.widget_bg)
                        setTextColor(R.id.widget_device_name, 0xFFF3F4F6.toInt())
                        setTextColor(R.id.widget_brand, 0xFF9CA3AF.toInt())
                        setTextColor(R.id.widget_last_seen, 0xFF9CA3AF.toInt())
                    }

                    // Shutdown countdown alert
                    if (isShuttingDown && shutdownCountdown.isNotEmpty()) {
                        setViewVisibility(R.id.widget_shutdown_box, View.VISIBLE)
                        setTextViewText(R.id.widget_shutdown_timer, "⏳ $shutdownCountdown")
                    } else {
                        setViewVisibility(R.id.widget_shutdown_box, View.GONE)
                    }

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
