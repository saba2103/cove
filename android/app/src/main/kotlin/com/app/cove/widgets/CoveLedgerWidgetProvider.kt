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
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetPlugin
import es.antonborri.home_widget.HomeWidgetProvider
import java.io.File

class CoveLedgerWidgetProvider : HomeWidgetProvider() {
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

    private fun bindWidget(
        context: Context,
        appWidgetManager: AppWidgetManager,
        widgetId: Int,
        widgetData: SharedPreferences,
        options: Bundle?,
    ) {
        val isDark = (context.resources.configuration.uiMode and Configuration.UI_MODE_NIGHT_MASK) ==
            Configuration.UI_MODE_NIGHT_YES
        val minWidthDp = options?.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH, 250) ?: 250
        val isCompact3Cell = minWidthDp in 1..219

        val primaryKey = when {
            isCompact3Cell && isDark -> "cove_widget_ledger_compact_dark"
            isCompact3Cell && !isDark -> "cove_widget_ledger_compact_light"
            isDark -> "cove_widget_ledger_dark"
            else -> "cove_widget_ledger_light"
        }
        val secondaryKey = if (isDark) "cove_widget_ledger_dark" else "cove_widget_ledger_light"
        val fallbackKey = if (isDark) "cove_widget_ledger_light" else "cove_widget_ledger_dark"

        val path = widgetData.getString(primaryKey, null)
            ?: widgetData.getString(secondaryKey, null)
            ?: widgetData.getString(fallbackKey, null)

        val views = RemoteViews(context.packageName, R.layout.cove_ledger_widget)
        if (path != null && File(path).exists()) {
            val bitmap = BitmapFactory.decodeFile(path)
            if (bitmap != null) {
                views.setImageViewBitmap(R.id.widget_bitmap, bitmap)
            } else {
                views.setImageViewResource(R.id.widget_bitmap, R.drawable.widget_preview_ledger)
            }
        } else {
            views.setImageViewResource(R.id.widget_bitmap, R.drawable.widget_preview_ledger)
        }

        val expensesIntent = HomeWidgetLaunchIntent.getActivity(
            context,
            MainActivity::class.java,
            Uri.parse("cove://widget/ledger/expenses"),
        )
        views.setOnClickPendingIntent(R.id.widget_hit_left, expensesIntent)

        val nextCommitmentId = widgetData.getString("cove_widget_ledger_next_commitment_id", null)
        val commitmentUri = if (!nextCommitmentId.isNullOrEmpty()) {
            "cove://widget/ledger/commitment?id=${Uri.encode(nextCommitmentId)}"
        } else {
            "cove://widget/ledger/commitments"
        }
        val commitmentIntent = HomeWidgetLaunchIntent.getActivity(
            context,
            MainActivity::class.java,
            Uri.parse(commitmentUri),
        )
        views.setOnClickPendingIntent(R.id.widget_hit_right, commitmentIntent)
        views.setViewVisibility(
            R.id.widget_hit_right,
            if (isCompact3Cell) View.GONE else View.VISIBLE,
        )

        appWidgetManager.updateAppWidget(widgetId, views)
    }
}
