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

class CoveDaySheetWidgetProvider : HomeWidgetProvider() {
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
            providerClass = CoveDaySheetWidgetProvider::class.java,
            kind = "sheet",
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
                providerClass = CoveDaySheetWidgetProvider::class.java,
                kind = "sheet",
                widgetId = widgetId,
                widgetData = widgetData,
                options = options,
                defaultWidthDp = 360,
                defaultHeightDp = 360,
            )

            val isDark = (context.resources.configuration.uiMode and Configuration.UI_MODE_NIGHT_MASK) ==
                Configuration.UI_MODE_NIGHT_YES
            val primaryKey = if (isDark) "cove_widget_sheet_dark" else "cove_widget_sheet_light"
            val fallbackKey = if (isDark) "cove_widget_sheet_light" else "cove_widget_sheet_dark"

            val path = CoveWidgetSizeHelper.resolveBitmapPathAndRequestRenderIfNeeded(
                context = context,
                kind = "sheet",
                widgetId = widgetId,
                exactSize = exactSize,
                isDark = isDark,
                widgetData = widgetData,
                fallbackKeys = listOf(primaryKey, fallbackKey),
            )

            val maxVisibleLines = when {
                exactSize.heightDp < 240 -> 1
                exactSize.heightDp < 290 -> 2
                exactSize.heightDp < 340 -> 3
                else -> 4
            }

            val openSheetIntent = HomeWidgetLaunchIntent.getActivity(
                context,
                MainActivity::class.java,
                Uri.parse("cove://widget/sheet"),
            )
            val openExpensesIntent = HomeWidgetLaunchIntent.getActivity(
                context,
                MainActivity::class.java,
                Uri.parse("cove://widget/sheet?kind=expenses"),
            )

            val rowViews = intArrayOf(
                R.id.widget_hit_row_0,
                R.id.widget_hit_row_1,
                R.id.widget_hit_row_2,
                R.id.widget_hit_row_3,
            )
            val habitViews = intArrayOf(
                R.id.widget_hit_habit_0,
                R.id.widget_hit_habit_1,
                R.id.widget_hit_habit_2,
                R.id.widget_hit_habit_3,
                R.id.widget_hit_habit_4,
                R.id.widget_hit_habit_5,
                R.id.widget_hit_habit_6,
                R.id.widget_hit_habit_7,
            )
            val checkinDate = widgetData.getString("cove_widget_sheet_checkin_date", null)

            val views = RemoteViews(context.packageName, R.layout.cove_day_sheet_widget)
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

            views.setOnClickPendingIntent(R.id.widget_hit_masthead, openSheetIntent)
            views.setOnClickPendingIntent(R.id.widget_hit_today_spend, openExpensesIntent)

            for (index in rowViews.indices) {
                val viewId = rowViews[index]
                if (index >= maxVisibleLines) {
                    views.setViewVisibility(viewId, View.GONE)
                    continue
                }
                views.setViewVisibility(viewId, View.VISIBLE)
                val rowId = widgetData.getString("cove_widget_sheet_row_${index}_id", null)
                val rowKind = widgetData.getString("cove_widget_sheet_row_${index}_kind", null)
                val rowDone = widgetData.getBoolean("cove_widget_sheet_row_${index}_done", false)

                if (rowId.isNullOrEmpty() || rowKind.isNullOrEmpty()) {
                    views.setOnClickPendingIntent(viewId, openSheetIntent)
                    continue
                }

                if (rowKind == "task") {
                    val toDone = !rowDone
                    val tickUri = Uri.parse(
                        "cove://widget/tick?kind=list_item&recordId=${Uri.encode(rowId)}&toDone=$toDone",
                    )
                    val tickIntent = HomeWidgetBackgroundIntent.getBroadcast(context, tickUri)
                    views.setOnClickPendingIntent(viewId, tickIntent)
                } else {
                    val openLineUri = Uri.parse(
                        "cove://widget/sheet?kind=${Uri.encode(rowKind)}&id=${Uri.encode(rowId)}",
                    )
                    val openLineIntent = HomeWidgetLaunchIntent.getActivity(
                        context,
                        MainActivity::class.java,
                        openLineUri,
                    )
                    views.setOnClickPendingIntent(viewId, openLineIntent)
                }
            }

            for (index in habitViews.indices) {
                val viewId = habitViews[index]
                val habitId = widgetData.getString("cove_widget_sheet_habit_${index}_id", null)
                val isOwned = widgetData.getBoolean("cove_widget_sheet_habit_${index}_owned", false)
                val isKept = widgetData.getBoolean("cove_widget_sheet_habit_${index}_kept", false)

                if (habitId.isNullOrEmpty() || !isOwned) {
                    views.setViewVisibility(viewId, View.GONE)
                    continue
                }

                views.setViewVisibility(viewId, View.VISIBLE)
                val toDone = !isKept
                val dateParam = if (!checkinDate.isNullOrEmpty()) {
                    "&checkinDate=${Uri.encode(checkinDate)}"
                } else {
                    ""
                }
                val tickUri = Uri.parse(
                    "cove://widget/tick?kind=habit_checkin&recordId=${Uri.encode(habitId)}&toDone=$toDone$dateParam",
                )
                val tickIntent = HomeWidgetBackgroundIntent.getBroadcast(context, tickUri)
                views.setOnClickPendingIntent(viewId, tickIntent)
            }

            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
