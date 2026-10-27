package com.app.cove.widgets

import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.util.Log
import android.util.SizeF
import es.antonborri.home_widget.HomeWidgetBackgroundIntent
import java.io.File
import kotlin.math.roundToInt

data class WidgetExactSize(
    val widthDp: Int,
    val heightDp: Int,
    val density: Float,
) {
    val sizeToken: String
        get() = "${widthDp}x${heightDp}"
}

object CoveWidgetSizeHelper {
    private const val TAG = "CoveWidgetSize"
    private const val RESIZE_DEBOUNCE_MS = 2500L

    fun resolveAndCacheSize(
        context: Context,
        appWidgetManager: AppWidgetManager,
        providerClass: Class<*>,
        kind: String,
        widgetId: Int,
        widgetData: SharedPreferences,
        options: Bundle?,
        defaultWidthDp: Int,
        defaultHeightDp: Int,
    ): WidgetExactSize {
        val effectiveOptions = options ?: runCatching {
            appWidgetManager.getAppWidgetOptions(widgetId)
        }.getOrNull()

        val density = context.resources.displayMetrics.density
        val minW = effectiveOptions?.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH, 0) ?: 0
        val minH = effectiveOptions?.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT, 0) ?: 0
        val maxW = effectiveOptions?.getInt(AppWidgetManager.OPTION_APPWIDGET_MAX_WIDTH, 0) ?: 0
        val maxH = effectiveOptions?.getInt(AppWidgetManager.OPTION_APPWIDGET_MAX_HEIGHT, 0) ?: 0

        val reportedSizes: List<SizeF> = if (effectiveOptions != null && Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                effectiveOptions.getParcelableArrayList(
                    AppWidgetManager.OPTION_APPWIDGET_SIZES,
                    SizeF::class.java,
                ) ?: emptyList()
            } else {
                @Suppress("DEPRECATION")
                effectiveOptions.getParcelableArrayList<SizeF>(
                    AppWidgetManager.OPTION_APPWIDGET_SIZES,
                ) ?: emptyList()
            }
        } else {
            emptyList()
        }

        val cachedRaw = widgetData.getString(sizePrefKeyForWidget(widgetId), null)
        val cachedPair = parseCachedSize(cachedRaw)

        val resolvedWidthDp: Int
        val resolvedHeightDp: Int
        if (reportedSizes.isNotEmpty()) {
            val primary = reportedSizes.first()
            resolvedWidthDp = primary.width.roundToInt().coerceAtLeast(1)
            resolvedHeightDp = primary.height.roundToInt().coerceAtLeast(1)
        } else if (minW > 0 && minH > 0) {
            resolvedWidthDp = minW
            resolvedHeightDp = minH
        } else if (maxW > 0 && maxH > 0) {
            resolvedWidthDp = maxW
            resolvedHeightDp = maxH
        } else if (cachedPair != null) {
            resolvedWidthDp = cachedPair.first
            resolvedHeightDp = cachedPair.second
        } else {
            resolvedWidthDp = defaultWidthDp
            resolvedHeightDp = defaultHeightDp
        }

        val exactSize = WidgetExactSize(
            widthDp = resolvedWidthDp,
            heightDp = resolvedHeightDp,
            density = density,
        )

        val sizesDebug = reportedSizes.joinToString(",") { "${it.width}x${it.height}" }
        Log.i(
            TAG,
            "kind=$kind widgetId=$widgetId minW=$minW minH=$minH maxW=$maxW maxH=$maxH " +
                "sizes=[$sizesDebug] resolved=${exactSize.sizeToken} density=$density",
        )

        if (kind == "sheet") {
            runCatching {
                val flutterPrefs = context.getSharedPreferences(
                    "FlutterSharedPreferences",
                    Context.MODE_PRIVATE,
                )
                val snapshot = flutterPrefs.getString("flutter.cove_widget_sheet_snapshot_v1", null)
                if (!snapshot.isNullOrEmpty()) {
                    snapshot.chunked(1000).forEachIndexed { idx, part ->
                        Log.i(TAG, "sheetSnapshot[$idx]=$part")
                    }
                }
            }
        }

        // Cache per-widget size and update active sizes set for this widget kind.
        val editor = widgetData.edit()
        editor.putString(sizePrefKeyForWidget(widgetId), "$kind:${exactSize.sizeToken}:$density")
        editor.putString("cove_widget_device_density", density.toString())

        val allIds = runCatching {
            appWidgetManager.getAppWidgetIds(ComponentName(context, providerClass))
        }.getOrNull() ?: intArrayOf(widgetId)

        val activeTokens = LinkedHashSet<String>()
        activeTokens.add(exactSize.sizeToken)
        for (s in reportedSizes) {
            val sw = s.width.roundToInt().coerceAtLeast(1)
            val sh = s.height.roundToInt().coerceAtLeast(1)
            activeTokens.add("${sw}x${sh}")
        }
        for (id in allIds) {
            if (id == widgetId) continue
            val raw = widgetData.getString(sizePrefKeyForWidget(id), null)
            val parsed = parseCachedSize(raw)
            if (parsed != null) {
                activeTokens.add("${parsed.first}x${parsed.second}")
            }
        }
        editor.putString(activeSizesPrefKeyForKind(kind), activeTokens.joinToString(","))
        editor.apply()

        return exactSize
    }

    fun removeCachedSize(
        context: Context,
        appWidgetManager: AppWidgetManager,
        providerClass: Class<*>,
        kind: String,
        widgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        val editor = widgetData.edit()
        for (id in widgetIds) {
            editor.remove(sizePrefKeyForWidget(id))
        }
        val remainingIds = runCatching {
            appWidgetManager.getAppWidgetIds(ComponentName(context, providerClass))
        }.getOrNull() ?: intArrayOf()
        val deletedSet = widgetIds.toSet()
        val activeTokens = LinkedHashSet<String>()
        for (id in remainingIds) {
            if (deletedSet.contains(id)) continue
            val raw = widgetData.getString(sizePrefKeyForWidget(id), null)
            val parsed = parseCachedSize(raw)
            if (parsed != null) {
                activeTokens.add("${parsed.first}x${parsed.second}")
            }
        }
        editor.putString(activeSizesPrefKeyForKind(kind), activeTokens.joinToString(","))
        editor.apply()
    }

    fun resolveBitmapPathAndRequestRenderIfNeeded(
        context: Context,
        kind: String,
        widgetId: Int,
        exactSize: WidgetExactSize,
        isDark: Boolean,
        widgetData: SharedPreferences,
        fallbackKeys: List<String>,
    ): String? {
        val themeSuffix = if (isDark) "dark" else "light"
        val altThemeSuffix = if (isDark) "light" else "dark"
        val exactKey = bitmapKeyForSize(kind, exactSize.widthDp, exactSize.heightDp, themeSuffix)
        val exactAltKey = bitmapKeyForSize(kind, exactSize.widthDp, exactSize.heightDp, altThemeSuffix)

        val exactPath = widgetData.getString(exactKey, null)
        if (!exactPath.isNullOrEmpty() && File(exactPath).exists()) {
            return exactPath
        }

        // Exact bitmap for this size & theme is missing; trigger a background render at exact dp * density.
        requestExactSizeRender(context, kind, widgetId, exactSize, widgetData)

        val exactAltPath = widgetData.getString(exactAltKey, null)
        if (!exactAltPath.isNullOrEmpty() && File(exactAltPath).exists()) {
            return exactAltPath
        }

        for (key in fallbackKeys) {
            val candidate = widgetData.getString(key, null)
            if (!candidate.isNullOrEmpty() && File(candidate).exists()) {
                return candidate
            }
        }
        return null
    }

    private fun requestExactSizeRender(
        context: Context,
        kind: String,
        widgetId: Int,
        exactSize: WidgetExactSize,
        widgetData: SharedPreferences,
    ) {
        val nowMs = System.currentTimeMillis()
        val throttleKey = "cove_widget_resize_req_${kind}_${exactSize.sizeToken}"
        val lastReqMs = widgetData.getLong(throttleKey, 0L)
        if (nowMs - lastReqMs in 0 until RESIZE_DEBOUNCE_MS) {
            return
        }
        widgetData.edit().putLong(throttleKey, nowMs).apply()

        runCatching {
            val uri = Uri.parse(
                "cove://widget/resize?kind=$kind&widgetId=$widgetId" +
                    "&w=${exactSize.widthDp}&h=${exactSize.heightDp}&density=${exactSize.density}",
            )
            val pendingIntent = HomeWidgetBackgroundIntent.getBroadcast(context, uri)
            pendingIntent.send()
        }.onFailure { err ->
            Log.w(TAG, "Failed to request exact-size render for $kind ${exactSize.sizeToken}: $err")
        }
    }

    fun bitmapKeyForSize(kind: String, widthDp: Int, heightDp: Int, themeSuffix: String): String {
        return "cove_widget_${kind}_${widthDp}x${heightDp}_$themeSuffix"
    }

    fun sizePrefKeyForWidget(widgetId: Int): String = "cove_widget_size_$widgetId"

    fun activeSizesPrefKeyForKind(kind: String): String = "cove_widget_active_sizes_$kind"

    private fun parseCachedSize(raw: String?): Pair<Int, Int>? {
        if (raw.isNullOrEmpty()) return null
        val parts = raw.split(":")
        val sizePart = if (parts.size >= 2) parts[1] else parts[0]
        val dims = sizePart.split("x")
        if (dims.size != 2) return null
        val w = dims[0].toIntOrNull() ?: return null
        val h = dims[1].toIntOrNull() ?: return null
        if (w <= 0 || h <= 0) return null
        return Pair(w, h)
    }
}
