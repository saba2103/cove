package com.app.cove.widgets

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.content.res.Configuration
import android.graphics.BitmapFactory
import android.net.Uri
import android.widget.RemoteViews
import com.app.cove.MainActivity
import com.app.cove.R
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider
import java.io.File

class CoveDaySheetWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        val isDark = (context.resources.configuration.uiMode and Configuration.UI_MODE_NIGHT_MASK) ==
            Configuration.UI_MODE_NIGHT_YES
        val key = if (isDark) "cove_widget_sheet_dark" else "cove_widget_sheet_light"
        val fallbackKey = if (isDark) "cove_widget_sheet_light" else "cove_widget_sheet_dark"
        val path = widgetData.getString(key, null) ?: widgetData.getString(fallbackKey, null)

        for (widgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.cove_widget_bitmap_container)
            if (path != null && File(path).exists()) {
                val bitmap = BitmapFactory.decodeFile(path)
                if (bitmap != null) {
                    views.setImageViewBitmap(R.id.widget_bitmap, bitmap)
                } else {
                    views.setImageViewResource(R.id.widget_bitmap, R.drawable.widget_preview_day_sheet)
                }
            } else {
                views.setImageViewResource(R.id.widget_bitmap, R.drawable.widget_preview_day_sheet)
            }

            val pendingIntent = HomeWidgetLaunchIntent.getActivity(
                context,
                MainActivity::class.java,
                Uri.parse("cove://widget/sheet"),
            )
            views.setOnClickPendingIntent(R.id.widget_root, pendingIntent)
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
