package com.weijx.fzu_assistant

import android.app.Activity
import android.content.Intent
import android.content.pm.ShortcutInfo
import android.content.pm.ShortcutManager
import android.graphics.drawable.Icon
import android.os.Build
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

/** Launch intents wait for Dart, where the normal login flow guards navigation. */
class AppShortcutBridge(private val activity: Activity, messenger: BinaryMessenger) {
    private val channel = MethodChannel(messenger, "com.weijx.fzu_assistant/shortcuts")
    private var ready = false
    private var pendingAction: String? = consumeIntent(activity.intent)

    init {
        registerShortcut(activity.getString(R.string.shortcut_campus_code))
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "takePendingAction" -> {
                    ready = true
                    val pending = pendingAction
                    pendingAction = null
                    result.success(pending)
                }
                "setLabels" -> {
                    registerShortcut(call.argument<String>("campusCode")
                        ?: activity.getString(R.string.shortcut_campus_code))
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    fun onNewIntent(intent: Intent) {
        val action = consumeIntent(intent) ?: return
        if (ready) channel.invokeMethod("action", action) else pendingAction = action
    }

    private fun consumeIntent(intent: Intent?): String? {
        val value = when (intent?.action) {
            OPEN_CAMPUS_CODE -> "campusCode"
            OPEN_SCHEDULE -> "schedule"
            else -> null
        }
        // A restored Activity must not deliver the same already-consumed intent.
        if (value != null) intent?.action = Intent.ACTION_MAIN
        return value
    }

    private fun registerShortcut(title: String) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.N_MR1) return
        try {
            val manager = activity.getSystemService(ShortcutManager::class.java) ?: return
            val intent = Intent(activity, MainActivity::class.java)
                .setAction(OPEN_CAMPUS_CODE)
                .addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP)
            manager.dynamicShortcuts = listOf(
                ShortcutInfo.Builder(activity, "campus_code")
                    .setShortLabel(title)
                    .setLongLabel(title)
                    .setIcon(Icon.createWithResource(activity, R.drawable.ic_shortcut_campus_code))
                    .setIntent(intent)
                    .build(),
            )
        } catch (_: RuntimeException) {
            // A launcher rejecting shortcuts must not block startup or login.
        }
    }

    companion object {
        const val OPEN_CAMPUS_CODE = "com.weijx.fzu_assistant.OPEN_CAMPUS_CODE"
        const val OPEN_SCHEDULE = "com.weijx.fzu_assistant.OPEN_SCHEDULE"
    }
}
