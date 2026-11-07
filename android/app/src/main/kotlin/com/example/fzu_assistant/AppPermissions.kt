package com.weijx.fzu_assistant

import android.Manifest
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.Settings

object AppPermissions {
    fun exactAllowed(context: Context) = Build.VERSION.SDK_INT < 31 ||
        context.getSystemService(android.app.AlarmManager::class.java).canScheduleExactAlarms()

    fun notificationsAllowed(context: Context): Boolean {
        if (!androidx.core.app.NotificationManagerCompat.from(context).areNotificationsEnabled()) return false
        if (Build.VERSION.SDK_INT < 26) return true
        val channel = context.getSystemService(android.app.NotificationManager::class.java)
            .getNotificationChannel("tomorrow_courses")
        return channel?.importance != android.app.NotificationManager.IMPORTANCE_NONE
    }
    /** 仅维护产品需要展示的权限，不扫描安装包或插件的权限声明。 */
    fun list(context: Context): List<Map<String, Any>> {
        val permissions = listOf(
            Manifest.permission.POST_NOTIFICATIONS,
            Manifest.permission.SCHEDULE_EXACT_ALARM,
            Manifest.permission.CAMERA,
            Manifest.permission.ACCESS_COARSE_LOCATION,
            Manifest.permission.ACCESS_FINE_LOCATION,
            Manifest.permission.READ_CALENDAR,
            Manifest.permission.WRITE_CALENDAR,
            Manifest.permission.REQUEST_INSTALL_PACKAGES,
            Manifest.permission.INTERNET,
            Manifest.permission.WAKE_LOCK,
            Manifest.permission.RECEIVE_BOOT_COMPLETED,
        )
        return permissions.map { name ->
            val granted = when (name) {
                Manifest.permission.POST_NOTIFICATIONS -> notificationsAllowed(context)
                Manifest.permission.SCHEDULE_EXACT_ALARM -> exactAllowed(context)
                Manifest.permission.REQUEST_INSTALL_PACKAGES -> Build.VERSION.SDK_INT < 26 || context.packageManager.canRequestPackageInstalls()
                else -> androidx.core.content.ContextCompat.checkSelfPermission(context, name) == PackageManager.PERMISSION_GRANTED
            }
            mapOf("name" to name, "granted" to granted)
        }
    }
    fun open(context: Context, name: String?) {
        val details = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:${context.packageName}"))
        val intent = when {
            name == Manifest.permission.SCHEDULE_EXACT_ALARM && Build.VERSION.SDK_INT >= 31 ->
                Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM, Uri.parse("package:${context.packageName}"))
            name == Manifest.permission.POST_NOTIFICATIONS ->
                Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).putExtra(Settings.EXTRA_APP_PACKAGE, context.packageName)
            name == Manifest.permission.REQUEST_INSTALL_PACKAGES && Build.VERSION.SDK_INT >= 26 ->
                Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES, Uri.parse("package:${context.packageName}"))
            else -> details
        }
        if (intent.resolveActivity(context.packageManager) != null) context.startActivity(intent)
        else context.startActivity(details)
    }
}
