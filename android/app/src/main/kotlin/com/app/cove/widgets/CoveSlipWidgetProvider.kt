package com.app.cove.widgets

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.content.res.Configuration
import android.graphics.BitmapFactory
import android.net.Uri
import android.os.Bundle
import android.view.View
import android.widget.RemoteViews
import com.app.cove.MainActivity
import com.app.cove.R
import es.antonborri.home_widget.HomeWidgetBackgroundIntent
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetPlugin
import es.antonborri.home_widget.HomeWidgetProvider
import java.io.File

class CoveSlipWidgetProvider : HomeWidgetProvider() {
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
            providerClass = CoveSlipWidgetProvider::class.java,
            kind = "slip",
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
                providerClass = CoveSlipWidgetProvider::class.java,
                kind = "slip",
                widgetId = widgetId,
                widgetData = widgetData,
                options = options,
                defaultWidthDp = 360,
                defaultHeightDp = 176,
            )

            val isDark = (context.resources.configuration.uiMode and Configuration.UI_MODE_NIGHT_MASK) ==
                Configuration.UI_MODE_NIGHT_YES
            val isCompact3Cell = exactSize.widthDp in 1..259
            val widthMaxRows = if (isCompact3Cell) 2 else 3
            val heightMaxRows = when {
                exactSize.heightDp < 125 -> 1
                exactSize.heightDp < 155 -> 2
                else -> 3
            }
            val maxRows = minOf(widthMaxRows, heightMaxRows)

            val primaryKey = when {
                isCompact3Cell && isDark -> "cove_widget_slip_compact_dark"
                isCompact3Cell && !isDark -> "cove_widget_slip_compact_light"
                isDark -> "cove_widget_slip_dark"
                else -> "cove_widget_slip_light"
            }
            val secondaryKey = if (isDark) "cove_widget_slip_dark" else "cove_widget_slip_light"
            val fallbackKey = if (isDark) "cove_widget_slip_light" else "cove_widget_slip_dark"

            val path = CoveWidgetSizeHelper.resolveBitmapPathAndRequestRenderIfNeeded(
                context = context,
                kind = "slip",
                widgetId = widgetId,
                exactSize = exactSize,
                isDark = isDark,
                widgetData = widgetData,
                fallbackKeys = listOf(primaryKey, secondaryKey, fallbackKey),
            )

            val views = RemoteViews(context.packageName, R.layout.cove_slip_widget)
            if (path != null && File(path).exists()) {
                val bitmap = BitmapFactory.decodeFile(path)
                if (bitmap != null) {
                    views.setImageViewBitmap(R.id.widget_bitmap, bitmap)
                } else {
                    views.setImageViewResource(R.id.widget_bitmap, R.drawable.widget_preview_slip)
                }
            } else {
                views.setImageViewResource(R.id.widget_bitmap, R.drawable.widget_preview_slip)
            }

            val listId = widgetData.getString("cove_widget_slip_list_id", null)
            val openUri = if (!listId.isNullOrEmpty()) {
                "cove://widget/slip?listId=${Uri.encode(listId)}"
            } else {
                "cove://widget/slip"
            }
            val openListIntent = HomeWidgetLaunchIntent.getActivity(
                context,
                MainActivity::class.java,
                Uri.parse(openUri),
            )
            views.setOnClickPendingIntent(R.id.widget_hit_header, openListIntent)
            views.setOnClickPendingIntent(R.id.widget_hit_footer, openListIntent)
            views.setViewVisibility(
                R.id.widget_hit_footer,
                if (exactSize.heightDp < 96) View.GONE else View.VISIBLE,
            )

            val rowViews = intArrayOf(
                R.id.widget_hit_row_0,
                R.id.widget_hit_row_1,
                R.id.widget_hit_row_2,
            )
            val rowKeys = arrayOf(
                "cove_widget_slip_row_0_id",
                "cove_widget_slip_row_1_id",
                "cove_widget_slip_row_2_id",
            )

            for (index in rowViews.indices) {
                val viewId = rowViews[index]
                if (index >= maxRows) {
                    views.setViewVisibility(viewId, View.GONE)
                    continue
                }
                views.setViewVisibility(viewId, View.VISIBLE)
                val rowId = widgetData.getString(rowKeys[index], null)
                if (!rowId.isNullOrEmpty()) {
                    val tickUri = Uri.parse(
                        "cove://widget/tick?kind=list_item&recordId=${Uri.encode(rowId)}",
                    )
                    val tickIntent = HomeWidgetBackgroundIntent.getBroadcast(context, tickUri)
                    views.setOnClickPendingIntent(viewId, tickIntent)
                } else {
                    views.setOnClickPendingIntent(viewId, openListIntent)
                }
            }

            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
