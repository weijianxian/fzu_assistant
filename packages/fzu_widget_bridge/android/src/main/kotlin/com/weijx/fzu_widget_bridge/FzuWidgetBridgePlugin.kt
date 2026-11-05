package com.weijx.fzu_widget_bridge

import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.os.PowerManager
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/** Engine-only plugin: the alarm plugin's headless engine auto-registers it. */
class FzuWidgetBridgePlugin : FlutterPlugin, MethodChannel.MethodCallHandler {
    private lateinit var context: Context
    private lateinit var store: WidgetSyncStore
    private var channel: MethodChannel? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        fun preferences(name: String) = AndroidWidgetPreferences(
            context.getSharedPreferences(name, Context.MODE_PRIVATE),
        )
        store = WidgetSyncStore(
            preferences(WidgetSyncStore.FLUTTER_PREFS),
            preferences(WidgetSyncStore.WIDGET_PREFS),
            preferences(WidgetSyncStore.STATE_PREFS),
        )
        channel = MethodChannel(
            binding.binaryMessenger, "com.weijx.fzu_assistant/widget_background",
        ).also { it.setMethodCallHandler(this) }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel?.setMethodCallHandler(null)
        channel = null
        // Another engine may own an active task; locks expire after 120s and
        // are explicitly released by the task or account cancellation.
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        try {
            when (call.method) {
                "getState" -> result.success(store.getState())
                "configure" -> {
                    synchronized(WidgetSyncStore.LOCK) {
                        try {
                            store.configure(
                                call.argument<Boolean>("enabled")
                                    ?: throw IllegalArgumentException("缺少同步开关"),
                                call.argument<Int>("minutes")
                                    ?: throw IllegalArgumentException("缺少同步时间"),
                                generation(call),
                            )
                        } finally {
                            releaseAllWakeLocks()
                        }
                    }
                    result.success(null)
                }
                "cancel" -> {
                    synchronized(WidgetSyncStore.LOCK) {
                        try {
                            store.cancel()
                        } finally {
                            releaseAllWakeLocks()
                        }
                    }
                    result.success(null)
                }
                "prepare" -> result.success(store.prepare(generation(call), manual(call)))
                "readInputs" -> result.success(store.readInputs())
                "writeInputs" -> result.success(store.writeInputs(mapArgument(call, "writes")))
                "writeCacheTerm" -> result.success(store.writeCacheTerm(
                    call.argument<String>("key")
                        ?: throw IllegalArgumentException("缺少缓存键名"),
                    call.argument<String>("term")
                        ?: throw IllegalArgumentException("缺少缓存学期"),
                    call.argument<String>("value")
                        ?: throw IllegalArgumentException("缺少学期缓存 JSON 字符串"),
                ))
                "publishSnapshot" -> {
                    val published = store.publishSnapshot(
                        mapArgument(call, "baseline"),
                        call.argument<String>("snapshot")
                            ?: throw IllegalArgumentException("缺少课程快照"),
                    )
                    if (published) updateWidgets()
                    result.success(published)
                }
                "commit" -> {
                    val committed = store.commit(
                        generation(call),
                        manual(call),
                        mapArgument(call, "baseline"),
                        mapArgument(call, "writes").mapValues {
                            it.value as? String
                                ?: throw IllegalArgumentException("缓存必须为 JSON 字符串")
                        },
                        call.argument<String>("snapshot")
                            ?: throw IllegalArgumentException("缺少课程快照"),
                    )
                    if (committed) updateWidgets()
                    result.success(committed)
                }
                "markFailed" -> result.success(store.markFailed(generation(call), manual(call)))
                "acquireWakeLock" -> result.success(acquireWakeLock(generation(call)))
                "releaseWakeLock" -> {
                    synchronized(WidgetSyncStore.LOCK) {
                        releaseWakeLock(generation(call))
                    }
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        } catch (error: WidgetStorageException) {
            result.error(
                "widget_storage_failed", error.message,
                mapOf("rollbackSucceeded" to error.rollbackSucceeded),
            )
        } catch (error: Exception) {
            result.error("widget_background_failed", error.message, null)
        }
    }

    private fun generation(call: MethodCall): String =
        call.argument<String>("generation")?.takeIf { it.isNotBlank() }
            ?: throw IllegalArgumentException("缺少同步代次")

    private fun manual(call: MethodCall): Boolean = call.argument<Boolean>("manual") == true

    private fun mapArgument(call: MethodCall, name: String): Map<String, Any?> {
        val raw = call.argument<Map<*, *>>(name)
            ?: throw IllegalArgumentException("缺少 $name")
        require(raw.keys.all { it is String }) { "$name 键名无效" }
        return raw.entries.associate { it.key as String to it.value }
    }

    private fun acquireWakeLock(generation: String): Boolean = synchronized(WidgetSyncStore.LOCK) {
        if (!store.isValid(generation)) return@synchronized false
        // A duplicate alarm must not start a second network refresh or release
        // the first task's lock from its finally block.
        if (wakeLocks[generation]?.isHeld == true) return@synchronized false
        val manager = context.getSystemService(Context.POWER_SERVICE) as PowerManager
        val wakeLock = manager.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "fzu_assistant:widget_sync")
        wakeLock.setReferenceCounted(false)
        wakeLock.acquire(120_000L)
        wakeLocks[generation] = wakeLock
        true
    }

    /** Rendering failures do not change a successful cache transaction. */
    private fun updateWidgets() {
        val manager = try {
            AppWidgetManager.getInstance(context)
        } catch (_: Exception) {
            return
        }
        for (provider in PROVIDERS) {
            try {
                val component = ComponentName(context.packageName, "com.weijx.fzu_assistant.$provider")
                val ids = manager.getAppWidgetIds(component)
                if (ids.isEmpty()) continue
                context.sendBroadcast(
                    Intent(AppWidgetManager.ACTION_APPWIDGET_UPDATE)
                        .setComponent(component)
                        .putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, ids),
                )
            } catch (_: Exception) {
                // The saved snapshot remains available for the next host update.
            }
        }
    }

    companion object {
        private val wakeLocks = mutableMapOf<String, PowerManager.WakeLock>()
        private val PROVIDERS = listOf(
            "NextCourseCompactWidgetProvider",
            "NextCourseSquareWidgetProvider",
            "TimetableWidgetProvider",
        )

        private fun releaseWakeLock(generation: String) {
            val wakeLock = wakeLocks.remove(generation) ?: return
            if (wakeLock.isHeld) wakeLock.release()
        }

        private fun releaseAllWakeLocks() {
            // Remove every entry even if a platform release unexpectedly fails.
            for (generation in wakeLocks.keys.toList()) {
                try {
                    releaseWakeLock(generation)
                } catch (_: RuntimeException) {
                    // Each acquired lock also has the hard platform timeout.
                }
            }
        }
    }
}

private class AndroidWidgetPreferences(private val preferences: SharedPreferences) : WidgetPreferences {
    override fun read(): Map<String, Any?> = preferences.all

    override fun commit(changes: Map<String, Any?>): Boolean {
        val editor = preferences.edit()
        for ((key, value) in changes) {
            when (value) {
                null -> editor.remove(key)
                is String -> editor.putString(key, value)
                is Boolean -> editor.putBoolean(key, value)
                is Int -> editor.putInt(key, value)
                is Long -> editor.putLong(key, value)
                is Float -> editor.putFloat(key, value)
                else -> throw IllegalArgumentException("不支持的缓存存储类型")
            }
        }
        return editor.commit()
    }
}
