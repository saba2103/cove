package com.app.cove.widgets

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.content.res.Configuration
import android.graphics.BitmapFactory
import android.net.Uri
import android.os.Bundle
import android.widget.RemoteViews
import com.app.cove.MainActivity
import com.app.cove.R
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetPlugin
import es.antonborri.home_widget.HomeWidgetProvider
import java.io.File

class CoveDayArcWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        for (widgetId in appWidgetIds) {
            val options = appWidgetManager.getAppWidgetOptions(widgetId)
            bindWidget(context, appWidgetManager, widgetId, widgetData, options)
        }
    }

    override fun onAppWidgetOptionsChanged(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        newOptions: Bundle,
    ) {
        super.onAppWidgetOptionsChanged(context, appWidgetManager, appWidgetId, newOptions)
        val widgetData = HomeWidgetPlugin.getData(context)
        bindWidget(context, appWidgetManager, appWidgetId, widgetData, newOptions)
    }

    override fun onDeleted(context: Context, appWidgetIds: IntArray) {
        super.onDeleted(context, appWidgetIds)
        val appWidgetManager = AppWidgetManager.getInstance(context)
        val widgetData = HomeWidgetPlugin.getData(context)
        CoveWidgetSizeHelper.removeCachedSize(
            context = context,
            appWidgetManager = appWidgetManager,
            providerClass = CoveDayArcWidgetProvider::class.java,
            kind = "arc",
            widgetIds = appWidgetIds,
            widgetData = widgetData,
        )
    }

    companion object {
        fun bindWidget(
            context: Context,
            appWidgetManager: AppWidgetManager,
            widgetId: Int,
            widgetData: SharedPreferences,
            options: Bundle?,
        ) {
            val exactSize = CoveWidgetSizeHelper.resolveAndCacheSize(
                context = context,
                appWidgetManager = appWidgetManager,
                providerClass = CoveDayArcWidgetProvider::class.java,
                kind = "arc",
                widgetId = widgetId,
                widgetData = widgetData,
                options = options,
                defaultWidthDp = 176,
                defaultHeightDp = 176,
            )

            val isDark = (context.resources.configuration.uiMode and Configuration.UI_MODE_NIGHT_MASK) ==
                Configuration.UI_MODE_NIGHT_YES
            val primaryKey = if (isDark) "cove_widget_arc_dark" else "cove_widget_arc_light"
            val fallbackKey = if (isDark) "cove_widget_arc_light" else "cove_widget_arc_dark"

            val path = CoveWidgetSizeHelper.resolveBitmapPathAndRequestRenderIfNeeded(
                context = context,
                kind = "arc",
                widgetId = widgetId,
                exactSize = exactSize,
                isDark = isDark,
                widgetData = widgetData,
                fallbackKeys = listOf(primaryKey, fallbackKey),
            )

            val views = RemoteViews(context.packageName, R.layout.cove_widget_bitmap_container)
            if (path != null && File(path).exists()) {
                val bitmap = BitmapFactory.decodeFile(path)
                if (bitmap != null) {
                    views.setImageViewBitmap(R.id.widget_bitmap, bitmap)
                } else {
                    views.setImageViewResource(R.id.widget_bitmap, R.drawable.widget_preview_arc)
                }
            } else {
                views.setImageViewResource(R.id.widget_bitmap, R.drawable.widget_preview_arc)
            }

            val pendingIntent = HomeWidgetLaunchIntent.getActivity(
                context,
                MainActivity::class.java,
                Uri.parse("cove://widget/arc"),
            )
            views.setOnClickPendingIntent(R.id.widget_root, pendingIntent)
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
