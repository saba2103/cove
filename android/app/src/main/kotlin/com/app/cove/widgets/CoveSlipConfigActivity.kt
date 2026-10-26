package com.app.cove.widgets

import android.app.Activity
import android.app.AlertDialog
import android.appwidget.AppWidgetManager
import android.content.Intent
import android.net.Uri
import android.os.Bundle
import es.antonborri.home_widget.HomeWidgetBackgroundIntent
import es.antonborri.home_widget.HomeWidgetPlugin
import org.json.JSONArray

class CoveSlipConfigActivity : Activity() {
    private var appWidgetId: Int = AppWidgetManager.INVALID_APPWIDGET_ID

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setResult(RESULT_CANCELED)

        appWidgetId = intent?.extras?.getInt(
            AppWidgetManager.EXTRA_APPWIDGET_ID,
            AppWidgetManager.INVALID_APPWIDGET_ID,
        ) ?: AppWidgetManager.INVALID_APPWIDGET_ID

        if (appWidgetId == AppWidgetManager.INVALID_APPWIDGET_ID) {
            finish()
            return
        }

        val widgetData = HomeWidgetPlugin.getData(this)
        val rawLists = widgetData.getString("cove_widget_slip_lists_json", null)
        val options = parseOptions(rawLists)

        if (options.size <= 1) {
            val defaultId = options.firstOrNull()?.id
            commitSelection(defaultId)
            return
        }

        var selectedIndex = options.indexOfFirst { it.isMostUsed }.let { if (it >= 0) it else 0 }
        val labels = options.map { opt ->
            val suffix = if (opt.isMostUsed) " · Most used" else ""
            "${opt.name} (${opt.openCount} open)$suffix"
        }.toTypedArray()

        AlertDialog.Builder(this)
            .setTitle("The Slip · Choose a list")
            .setSingleChoiceItems(labels, selectedIndex) { _, which ->
                selectedIndex = which
            }
            .setPositiveButton("Use list") { _, _ ->
                commitSelection(options[selectedIndex].id)
            }
            .setNegativeButton("Cancel") { _, _ ->
                finish()
            }
            .setOnCancelListener {
                finish()
            }
            .show()
    }

    private fun commitSelection(listId: String?) {
        if (!listId.isNullOrEmpty()) {
            try {
                val selectUri = Uri.parse(
                    "cove://widget/slip/select?listId=${Uri.encode(listId)}",
                )
                HomeWidgetBackgroundIntent.getBroadcast(this, selectUri).send()
            } catch (_: Exception) {
            }
        }

        val appWidgetManager = AppWidgetManager.getInstance(this)
        val widgetData = HomeWidgetPlugin.getData(this)
        val options = appWidgetManager.getAppWidgetOptions(appWidgetId)
        CoveSlipWidgetProvider.bindWidget(this, appWidgetManager, appWidgetId, widgetData, options)

        val resultValue = Intent().putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
        setResult(RESULT_OK, resultValue)
        finish()
    }

    private data class ListOption(
        val id: String,
        val name: String,
        val openCount: Int,
        val isMostUsed: Boolean,
    )

    private fun parseOptions(rawJson: String?): List<ListOption> {
        if (rawJson.isNullOrEmpty()) return emptyList()
        return try {
            val arr = JSONArray(rawJson)
            val result = mutableListOf<ListOption>()
            for (i in 0 until arr.length()) {
                val obj = arr.optJSONObject(i) ?: continue
                val id = obj.optString("id", "")
                val name = obj.optString("name", "")
                if (id.isNotEmpty() && name.isNotEmpty()) {
                    result.add(
                        ListOption(
                            id = id,
                            name = name,
                            openCount = obj.optInt("openCount", 0),
                            isMostUsed = obj.optBoolean("isMostUsed", false),
                        ),
                    )
                }
            }
            result
        } catch (_: Exception) {
            emptyList()
        }
    }
}
