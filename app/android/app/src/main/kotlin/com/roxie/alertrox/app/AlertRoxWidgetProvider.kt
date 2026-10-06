package com.roxie.alertrox.app

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.content.res.Configuration
import android.graphics.*
import android.os.Bundle
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

                    // Widget appearance settings from Flutter
                    val widgetMode = widgetData.getString("widget_mode", "dark") ?: "dark"
                    val widgetGlass = widgetData.getBoolean("widget_glass", true)
                    val widgetOpacity = try {
                        widgetData.getInt("widget_opacity", 85)
                    } catch (_: Exception) {
                        try { widgetData.getLong("widget_opacity", 85L).toInt() } catch (_: Exception) { 85 }
                    }
                    val accentColorLong = try {
                        widgetData.getLong("widget_accent", 0xFF00F0FFL)
                    } catch (_: Exception) {
                        try { widgetData.getInt("widget_accent", 0xFF00F0FF.toInt()).toLong() } catch (_: Exception) { 0xFF00F0FFL }
                    }
                    val secondaryColorLong = try {
                        widgetData.getLong("widget_secondary", 0xFF10B981L)
                    } catch (_: Exception) {
                        try { widgetData.getInt("widget_secondary", 0xFF10B981.toInt()).toLong() } catch (_: Exception) { 0xFF10B981L }
                    }

                    val accentColor = accentColorLong.toInt()
                    val secondaryColor = secondaryColorLong.toInt()

                    // Determine effective light/dark mode
                    val isSystemDark = (context.resources.configuration.uiMode and Configuration.UI_MODE_NIGHT_MASK) == Configuration.UI_MODE_NIGHT_YES
                    val isLight = when (widgetMode) {
                        "light" -> true
                        "system" -> !isSystemDark
                        else -> false
                    }

                    // Status indicator color
                    val statusColor = if (isOnline) {
                        if (widgetGlass) accentColor else 0xFF10B981.toInt()
                    } else {
                        0xFFEF4444.toInt()
                    }
                    setTextColor(R.id.widget_status, statusColor)

                    // Text colors based on mode
                    if (isLight) {
                        setTextColor(R.id.widget_device_name, 0xFF0F172A.toInt())
                        setTextColor(R.id.widget_brand, 0xFF475569.toInt())
                        setTextColor(R.id.widget_last_seen, 0xFF64748B.toInt())
                        setInt(R.id.widget_divider, "setBackgroundColor", 0x33000000)
                    } else {
                        setTextColor(R.id.widget_device_name, 0xFFF8FAFC.toInt())
                        setTextColor(R.id.widget_brand, 0xFF94A3B8.toInt())
                        setTextColor(R.id.widget_last_seen, 0xFF94A3B8.toInt())
                        setInt(R.id.widget_divider, "setBackgroundColor", 0x33FFFFFF)
                    }

                    // Get widget dimensions from AppWidgetOptions
                    val options: Bundle? = appWidgetManager.getAppWidgetOptions(widgetId)
                    val minWidthDp = options?.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH) ?: 200
                    val minHeightDp = options?.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT) ?: 100

                    val density = context.resources.displayMetrics.density
                    val widthPx = (minWidthDp * density).toInt().coerceIn(300, 800)
                    val heightPx = (minHeightDp * density).toInt().coerceIn(150, 450)

                    // Draw dynamic rounded bitmap background with glass/gradient
                    val bgBitmap = createWidgetBackgroundBitmap(
                        width = widthPx,
                        height = heightPx,
                        isLight = isLight,
                        isGlass = widgetGlass,
                        opacityPercent = widgetOpacity,
                        accentColor = accentColor,
                        secondaryColor = secondaryColor,
                        density = density
                    )
                    setImageViewBitmap(R.id.widget_background_image, bgBitmap)

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
                    setOnClickPendingIntent(R.id.widget_container, pendingIntent)
                }
                appWidgetManager.updateAppWidget(widgetId, views)
            } catch (e: Exception) {
                Log.e("AlertRoxWidget", "Error updating widget ID $widgetId: ${e.message}", e)
            }
        }
    }

    private fun createWidgetBackgroundBitmap(
        width: Int,
        height: Int,
        isLight: Boolean,
        isGlass: Boolean,
        opacityPercent: Int,
        accentColor: Int,
        secondaryColor: Int,
        density: Float
    ): Bitmap {
        val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        val cornerRadius = 24f * density
        val rect = RectF(2f, 2f, width - 2f, height - 2f)

        val alphaFactor = (opacityPercent.coerceIn(0, 100) / 100f)

        val paint = Paint(Paint.ANTI_ALIAS_FLAG)

        if (isGlass) {
            // Base fill with frosted tint. At 100% opacity, alpha is 255 (fully solid, no transparency). At 0%, alpha is 0.
            val baseAlpha = (255 * alphaFactor).toInt().coerceIn(0, 255)
            val baseColor = if (isLight) {
                Color.argb(baseAlpha, 255, 255, 255)
            } else {
                Color.argb(baseAlpha, 15, 23, 42)
            }
            paint.style = Paint.Style.FILL
            paint.color = baseColor
            canvas.drawRoundRect(rect, cornerRadius, cornerRadius, paint)

            if (alphaFactor > 0.02f) {
                // Subtle gradient from accent / secondary colors on top
                val accentAlpha = ((if (isLight) 40 else 50) * alphaFactor).toInt().coerceIn(0, 255)
                val secondaryAlpha = ((if (isLight) 30 else 40) * alphaFactor).toInt().coerceIn(0, 255)
                val topColor = Color.argb(
                    accentAlpha,
                    Color.red(accentColor),
                    Color.green(accentColor),
                    Color.blue(accentColor)
                )
                val bottomColor = Color.argb(
                    secondaryAlpha,
                    Color.red(secondaryColor),
                    Color.green(secondaryColor),
                    Color.blue(secondaryColor)
                )

                val gradient = LinearGradient(
                    0f, 0f, width.toFloat(), height.toFloat(),
                    topColor, bottomColor, Shader.TileMode.CLAMP
                )
                paint.shader = gradient
                canvas.drawRoundRect(rect, cornerRadius, cornerRadius, paint)
                paint.shader = null

                // Thin border
                val strokePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                    style = Paint.Style.STROKE
                    strokeWidth = 1.2f * density
                    val borderAlpha = ((if (isLight) 140 else 100) * alphaFactor).toInt().coerceIn(0, 255)
                    color = Color.argb(
                        borderAlpha,
                        if (isLight) 255 else Color.red(accentColor),
                        if (isLight) 255 else Color.green(accentColor),
                        if (isLight) 255 else Color.blue(accentColor)
                    )
                }
                canvas.drawRoundRect(rect, cornerRadius, cornerRadius, strokePaint)
            }
        } else {
            // Solid style. At 100% opacity, alpha is 255 (completely solid). At 0%, alpha is 0.
            val baseAlpha = (255 * alphaFactor).toInt().coerceIn(0, 255)
            val baseColor = if (isLight) {
                Color.argb(baseAlpha, 255, 255, 255)
            } else {
                Color.argb(baseAlpha, 17, 24, 39)
            }
            paint.style = Paint.Style.FILL
            paint.color = baseColor
            canvas.drawRoundRect(rect, cornerRadius, cornerRadius, paint)

            if (alphaFactor > 0.02f) {
                val strokePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                    style = Paint.Style.STROKE
                    strokeWidth = 1.2f * density
                    val borderAlpha = (255 * alphaFactor).toInt().coerceIn(0, 255)
                    color = if (isLight) {
                        Color.argb(borderAlpha, 0xCB, 0xD5, 0xE1)
                    } else {
                        Color.argb(borderAlpha, 0x1F, 0x29, 0x3D)
                    }
                }
                canvas.drawRoundRect(rect, cornerRadius, cornerRadius, strokePaint)
            }
        }

        return bitmap
    }
}
