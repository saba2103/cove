package com.app.cove.widgets

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.content.res.Configuration
import android.graphics.BitmapFactory
import android.net.Uri
import android.view.View
import android.widget.RemoteViews
import com.app.cove.MainActivity
import com.app.cove.R
import es.antonborri.home_widget.HomeWidgetBackgroundIntent
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

        for (widgetId in appWidgetIds) {
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

            // Bind each line row: tasks tick via 4.4c background intent;
            // events and routines open in the app (`design/specs/18-widgets.md` §4).
            for (index in rowViews.indices) {
                val viewId = rowViews[index]
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

            // Bind habit dots: only viewer's own habits (`owned == true`) are tappable.
            // Partner habit dots are drawn in the bitmap but their hit target is hidden
            // (`View.GONE`) so they are not tappable (`design/specs/18-widgets.md` §4).
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
