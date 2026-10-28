package com.weijx.fzu_assistant

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private val channelName = "com.weijx.fzu_assistant/update"
    private var notificationPermissionResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.weijx.fzu_assistant/permissions")
            .setMethodCallHandler { call, result ->
                try {
                    when (call.method) {
                        "list" -> result.success(AppPermissions.list(this))
                        "open" -> { AppPermissions.open(this, call.argument<String>("name")); result.success(null) }
                        else -> result.notImplemented()
                    }
                } catch (error: Exception) {
                    result.error("permissions_failed", error.message, null)
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.weijx.fzu_assistant/reminders")
            .setMethodCallHandler { call, result ->
                try {
                    when (call.method) {
                        "permissions" -> result.success(mapOf(
                            "notifications" to AppPermissions.notificationsAllowed(this),
                            "exact" to AppPermissions.exactAllowed(this),
                        ))
                        "requestNotifications" -> {
                            val permissionPrefs = getSharedPreferences("course_reminders", MODE_PRIVATE)
                            if (Build.VERSION.SDK_INT >= 33 &&
                                checkSelfPermission(android.Manifest.permission.POST_NOTIFICATIONS) != android.content.pm.PackageManager.PERMISSION_GRANTED &&
                                (!permissionPrefs.getBoolean("notification_requested", false) ||
                                    shouldShowRequestPermissionRationale(android.Manifest.permission.POST_NOTIFICATIONS))) {
                                if (notificationPermissionResult != null) {
                                    result.error("permission_busy", "权限请求正在进行", null)
                                    return@setMethodCallHandler
                                }
                                permissionPrefs.edit().putBoolean("notification_requested", true).apply()
                                notificationPermissionResult = result
                                requestPermissions(arrayOf(android.Manifest.permission.POST_NOTIFICATIONS), 4201)
                                return@setMethodCallHandler
                            } else {
                                startActivity(Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS)
                                    .putExtra(Settings.EXTRA_APP_PACKAGE, packageName))
                            }
                            result.success(null)
                        }
                        "requestExact" -> {
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                                startActivity(Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM,
                                    Uri.parse("package:$packageName")))
                            }
                            result.success(null)
                        }
                        "openNotificationChannel" -> {
                            if (Build.VERSION.SDK_INT >= 26) {
                                startActivity(Intent(Settings.ACTION_CHANNEL_NOTIFICATION_SETTINGS)
                                    .putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
                                    .putExtra(Settings.EXTRA_CHANNEL_ID, "tomorrow_courses"))
                            } else {
                                AppPermissions.open(this, android.Manifest.permission.POST_NOTIFICATIONS)
                            }
                            result.success(null)
                        }
                        "cancelLegacy" -> {
                            val alarms = getSystemService(android.app.AlarmManager::class.java)
                            for ((id, action) in listOf(4201 to "COURSE_REMINDER", 4202 to "TEST_REMINDER")) {
                                val intent = Intent().setClassName(this, "com.weijx.fzu_assistant.CourseReminderReceiver")
                                    .setAction("com.weijx.fzu_assistant.$action")
                                val pending = android.app.PendingIntent.getBroadcast(this, id, intent,
                                    android.app.PendingIntent.FLAG_NO_CREATE or android.app.PendingIntent.FLAG_IMMUTABLE)
                                if (pending != null) { alarms.cancel(pending); pending.cancel() }
                            }
                            getSharedPreferences("course_reminders", MODE_PRIVATE).edit().remove("plans").apply()
                            if (Build.VERSION.SDK_INT >= 26) {
                                val manager = getSystemService(android.app.NotificationManager::class.java)
                                val channel = android.app.NotificationChannel("tomorrow_courses",
                                    getString(R.string.course_reminder_channel), android.app.NotificationManager.IMPORTANCE_HIGH)
                                channel.lockscreenVisibility = android.app.Notification.VISIBILITY_PUBLIC
                                manager.createNotificationChannel(channel)
                            }
                            result.success(null)
                        }
                        else -> result.notImplemented()
                    }
                } catch (error: Exception) {
                    result.error("reminder_failed", error.message, null)
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getSupportedAbis" -> result.success(Build.SUPPORTED_ABIS.toList())
                    "canInstallPackages" -> result.success(canInstallPackages())
                    "openInstallSettings" -> {
                        openInstallSettings()
                        result.success(null)
                    }
                    "installApk" -> {
                        val path = call.argument<String>("path")
                        result.success(if (path == null) "failed" else installApk(path))
                    }
                    else -> result.notImplemented()
                }
            }
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == 4201) {
            notificationPermissionResult?.success(null)
            notificationPermissionResult = null
        }
    }

    private fun canInstallPackages(): Boolean {
        return Build.VERSION.SDK_INT < Build.VERSION_CODES.O ||
            packageManager.canRequestPackageInstalls()
    }

    private fun openInstallSettings() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return

        val intent = Intent(
            Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
            Uri.parse("package:$packageName"),
        )
        startActivity(intent)
    }

    private fun installApk(path: String): String {
        if (!canInstallPackages()) {
            openInstallSettings()
            return "permissionRequired"
        }

        val apkFile = File(path)
        if (!apkFile.exists()) return "failed"

        return try {
            val apkUri = FileProvider.getUriForFile(
                this,
                "$packageName.fileprovider",
                apkFile,
            )
            val intent = Intent(Intent.ACTION_VIEW).apply {
                setDataAndType(apkUri, "application/vnd.android.package-archive")
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            startActivity(intent)
            "started"
        } catch (_: Exception) {
            "failed"
        }
    }
}
