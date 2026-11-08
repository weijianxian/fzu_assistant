package com.weijx.fzu_assistant

import android.app.Activity
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Intent
import android.os.Build
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject

class NextCourseWidgetBridge(activity: Activity, messenger: BinaryMessenger) {
    init {
        MethodChannel(messenger, "com.weijx.fzu_assistant/next_course_widget")
            .setMethodCallHandler { call, result ->
                try {
                    when (call.method) {
                        "setSnapshot" -> {
                            val raw = call.arguments as? String
                                ?: throw IllegalArgumentException("缺少课程快照")
                            require(raw.toByteArray(Charsets.UTF_8).size <= 2 * 1024 * 1024)
                            val data = JSONObject(raw)
                            require(data.getInt("version") == 1)
                            require(data.getJSONArray("days").length() <= 180)
                            val saved = NextCourseWidgetProvider.preferences(activity)
                                .edit().putString("snapshot", raw).commit()
                            check(saved) { "无法保存课程快照" }
                            NextCourseWidgetProvider.updateAll(activity)
                            result.success(null)
                        }
                        "clear" -> {
                            check(NextCourseWidgetProvider.preferences(activity).edit().clear().commit())
                            NextCourseWidgetProvider.updateAll(activity)
                            result.success(null)
                        }
                        "invalidate" -> {
                            check(NextCourseWidgetProvider.preferences(activity).edit()
                                .putString("snapshot", JSONObject()
                                    .put("version", 1).put("signedIn", true).put("days", org.json.JSONArray())
                                    .toString()).commit())
                            NextCourseWidgetProvider.updateAll(activity)
                            result.success(null)
                        }
                        "requestPin" -> {
                            val arguments = call.arguments as? Map<*, *>
                            val variant = arguments?.get("variant") as? String ?: "square"
                            val provider = NextCourseWidgetProvider.providerClass(variant)
                            val manager = AppWidgetManager.getInstance(activity)
                            val supported = Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
                                manager.isRequestPinAppWidgetSupported
                            val requested = supported && manager.requestPinAppWidget(
                                ComponentName(activity, provider), null,
                                PendingIntent.getBroadcast(
                                    activity,
                                    variant.hashCode(),
                                    Intent(activity, provider).setAction(
                                        NextCourseWidgetProvider.pinSuccessAction(variant),
                                    ),
                                    PendingIntent.FLAG_UPDATE_CURRENT or
                                        PendingIntent.FLAG_IMMUTABLE,
                                ),
                            )
                            result.success(requested)
                        }
                        "openPinSettings" -> {
                            AppPermissions.open(activity, null)
                            result.success(null)
                        }
                        else -> result.notImplemented()
                    }
                } catch (error: Exception) {
                    result.error("widget_failed", error.message, null)
                }
            }
    }
}
