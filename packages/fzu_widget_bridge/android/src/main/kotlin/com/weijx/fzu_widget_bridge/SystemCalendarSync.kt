package com.weijx.fzu_widget_bridge

import android.Manifest
import android.content.ContentProviderOperation
import android.content.ContentUris
import android.content.ContentValues
import android.content.Context
import android.content.pm.PackageManager
import android.net.Uri
import android.provider.CalendarContract
import android.provider.CalendarContract.Calendars
import android.provider.CalendarContract.Events
import android.provider.CalendarContract.Reminders

/** All methods run under WidgetSyncStore.LOCK, including account cancellation. */
internal class SystemCalendarSync(private val context: Context) {
    private val preferences = context.getSharedPreferences("system_calendar_sync", Context.MODE_PRIVATE)
    private val resolver get() = context.contentResolver
    val enabled get() = preferences.getBoolean("enabled", false)
    private val owner get() = preferences.getString("owner", null)
    private val accountName get() = "${context.packageName}:${owner ?: "none"}"

    fun granted() = listOf(Manifest.permission.READ_CALENDAR, Manifest.permission.WRITE_CALENDAR)
        .all { context.checkSelfPermission(it) == PackageManager.PERMISSION_GRANTED }

    fun state(): Map<String, Any?> = mapOf(
        "enabled" to enabled,
        "owner" to owner,
        "includeExams" to preferences.getBoolean("includeExams", true),
        "reminder" to preferences.getInt("reminder", 15),
        "granted" to granted(),
        "failed" to preferences.getBoolean("failed", false),
        "lastSuccess" to preferences.getLong("lastSuccess", 0L).takeIf { it > 0L },
        "inserted" to preferences.getInt("inserted", 0),
        "updated" to preferences.getInt("updated", 0),
        "deleted" to preferences.getInt("deleted", 0),
        "count" to preferences.getInt("count", 0),
    )

    fun configure(arguments: Map<String, Any?>) {
        val newOwner = arguments["owner"] as? String ?: throw IllegalArgumentException("请先登录教务账号")
        require(newOwner.matches(Regex("[a-f0-9]{64}"))) { "账号标识无效" }
        val active = arguments["enabled"] == true
        require(!active || granted()) { "请先授予日历权限" }
        val reminder = (arguments["reminder"] as? Number)?.toInt() ?: 15
        require(reminder in 0..1440)
        val editor = preferences.edit()
            .putString("owner", newOwner).putBoolean("enabled", active)
            .putBoolean("includeExams", arguments["includeExams"] != false)
            .putInt("reminder", reminder).putBoolean("failed", false)
        if (owner != newOwner) {
            editor.remove("lastSuccess").putInt("count", 0)
                .putInt("inserted", 0).putInt("updated", 0).putInt("deleted", 0)
        }
        check(editor.commit()) { "无法保存日历同步设置" }
    }

    /** Keep written events when paused or logged out; they belong to this local calendar. */
    fun disconnect() {
        check(preferences.edit().putBoolean("enabled", false).commit()) { "无法停止日历同步" }
    }

    fun markFailed() {
        if (enabled) preferences.edit().putBoolean("failed", true).commit()
    }

    /** Stops syncing before removal, including when a provider failure requires retry. */
    fun clearAll() {
        disconnect()
        check(granted()) { "请先授予日历权限" }
        val calendars = mutableListOf<Pair<Long, String>>()
        resolver.query(
            Calendars.CONTENT_URI, arrayOf(Calendars._ID, Calendars.ACCOUNT_NAME),
            "${Calendars.ACCOUNT_TYPE}=? AND ${Calendars.NAME}=?",
            arrayOf(CalendarContract.ACCOUNT_TYPE_LOCAL, "fzu-schedule-v1"), null,
        )?.use { cursor ->
            while (cursor.moveToNext()) {
                val account = cursor.getString(1) ?: continue
                if (account.startsWith("${context.packageName}:") &&
                    account.removePrefix("${context.packageName}:").matches(Regex("[a-f0-9]{64}"))) {
                    calendars += cursor.getLong(0) to account
                }
            }
        } ?: throw IllegalStateException("无法读取课表日历")
        val events = mutableListOf<Triple<Long, Boolean, String>>()
        for ((calendar, account) in calendars) {
            resolver.query(
                syncUri(Events.CONTENT_URI, account), arrayOf(Events._ID, Events._SYNC_ID, Events.ORIGINAL_ID),
                "${Events.CALENDAR_ID}=?", arrayOf("$calendar"), null,
            )?.use { cursor ->
                while (cursor.moveToNext()) {
                    val uid = cursor.getString(1) ?: continue
                    if (Regex("fzu-v[12]:\\d{6}:[^:]+").matches(uid)) {
                        events += Triple(cursor.getLong(0), !cursor.isNull(2), account)
                    }
                }
            } ?: throw IllegalStateException("无法读取课表日程")
        }
        // Remove managed exceptions first. Keep manual entries and the calendar
        // itself; other accounts' calendars outside this app are never touched.
        for (batch in events.sortedBy { if (it.second) 0 else 1 }.chunked(90)) {
            val operations = ArrayList(batch.map { (eventId, _, account) ->
                ContentProviderOperation.newDelete(
                    syncUri(ContentUris.withAppendedId(Events.CONTENT_URI, eventId), account),
                ).build()
            })
            resolver.applyBatch(CalendarContract.AUTHORITY, operations)
        }
        check(preferences.edit().remove("lastSuccess").putBoolean("failed", false)
            .putInt("count", 0).putInt("inserted", 0).putInt("updated", 0).putInt("deleted", 0)
            .commit()) { "无法保存日历同步状态" }
    }

    private fun syncUri(uri: Uri, syncAccount: String = accountName): Uri = uri.buildUpon()
        .appendQueryParameter(CalendarContract.CALLER_IS_SYNCADAPTER, "true")
        .appendQueryParameter(Calendars.ACCOUNT_NAME, syncAccount)
        .appendQueryParameter(Calendars.ACCOUNT_TYPE, CalendarContract.ACCOUNT_TYPE_LOCAL)
        .build()

    private fun calendarId(): Long {
        resolver.query(
            Calendars.CONTENT_URI, arrayOf(Calendars._ID),
            "${Calendars.ACCOUNT_NAME}=? AND ${Calendars.ACCOUNT_TYPE}=? AND ${Calendars.NAME}=?",
            arrayOf(accountName, CalendarContract.ACCOUNT_TYPE_LOCAL, "fzu-schedule-v1"), null,
        )?.use { cursor -> if (cursor.moveToFirst()) return cursor.getLong(0) }
            ?: throw IllegalStateException("无法读取系统日历")
        val locale = context.resources.configuration.locales[0].language
        val name = if (locale == "zh") "福大助手课表" else "FZU Assistant"
        val values = ContentValues().apply {
            put(Calendars.ACCOUNT_NAME, accountName)
            put(Calendars.ACCOUNT_TYPE, CalendarContract.ACCOUNT_TYPE_LOCAL)
            put(Calendars.NAME, "fzu-schedule-v1")
            put(Calendars.CALENDAR_DISPLAY_NAME, name)
            put(Calendars.CALENDAR_COLOR, 0xFF426A58.toInt())
            put(Calendars.CALENDAR_ACCESS_LEVEL, Calendars.CAL_ACCESS_OWNER)
            put(Calendars.OWNER_ACCOUNT, accountName)
            put(Calendars.CALENDAR_TIME_ZONE, "Asia/Shanghai")
            put(Calendars.VISIBLE, 1)
            put(Calendars.SYNC_EVENTS, 1)
            put(Calendars.ALLOWED_REMINDERS, "1")
            put(Calendars.ALLOWED_AVAILABILITY, "0")
            put(Calendars.ALLOWED_ATTENDEE_TYPES, "0")
            put(Calendars.MAX_REMINDERS, 1)
        }
        val created = resolver.insert(syncUri(Calendars.CONTENT_URI), values)
            ?: throw IllegalStateException("无法创建课表日历")
        return ContentUris.parseId(created)
    }

    fun sync(payload: Map<String, Any?>) {
        check(enabled && payload["owner"] == owner) { "日历同步设置已变化" }
        check(granted()) { "日历权限已撤回" }
        val terms = (payload["terms"] as List<*>).map { it as String }.toSet()
        val protectedUids = (payload["protected"] as List<*>).map { it as String }.toSet()
        val desired = (payload["events"] as List<*>).map { raw ->
            val event = raw as Map<*, *>
            CalendarEvent(
                event["uid"] as String, event["title"] as String,
                event["location"] as String, event["description"] as String,
                (event["start"] as Number).toLong(), (event["end"] as Number).toLong(),
                (event["reminder"] as Number).toInt(),
                event["rrule"] as String?, event["exdate"] as String?,
                event["originalUid"] as String?, (event["originalStart"] as Number?)?.toLong(),
            )
        }
        val occurrenceCount = (payload["occurrenceCount"] as Number?)?.toInt() ?: desired.size
        require(occurrenceCount in 0..5000)
        // Validate the entire replacement before the first provider mutation.
        calendarPlan(emptyList(), desired, terms, protectedUids)
        val id = calendarId()
        val existing = mutableListOf<StoredCalendarEvent>()
        val originalIds = mutableMapOf<Long, Long>()
        resolver.query(
            syncUri(Events.CONTENT_URI),
            arrayOf(Events._ID, Events._SYNC_ID, Events.TITLE, Events.EVENT_LOCATION,
                Events.DESCRIPTION, Events.DTSTART, Events.DTEND, Events.DELETED,
                Events.RRULE, Events.EXDATE, Events.DURATION, Events.ORIGINAL_SYNC_ID,
                Events.ORIGINAL_INSTANCE_TIME, Events.ORIGINAL_ID, Events.STATUS),
            "${Events.CALENDAR_ID}=?", arrayOf("$id"), null,
        )?.use { cursor ->
            while (cursor.moveToNext()) {
                val eventId = cursor.getLong(0)
                val start = cursor.getLong(5)
                val rule = cursor.getString(8)?.takeIf { it.isNotBlank() }
                val end = if (rule == null) cursor.getLong(6) else start + durationMillis(cursor.getString(10))
                if (!cursor.isNull(13)) originalIds[eventId] = cursor.getLong(13)
                existing += StoredCalendarEvent(eventId, CalendarEvent(
                    cursor.getString(1) ?: "", cursor.getString(2) ?: "",
                    cursor.getString(3) ?: "", cursor.getString(4) ?: "",
                    start, end, 0, rule, cursor.getString(9)?.takeIf { it.isNotBlank() },
                    cursor.getString(11), if (cursor.isNull(12)) null else cursor.getLong(12),
                ), deleted = cursor.getInt(7) != 0 || cursor.getInt(14) == Events.STATUS_CANCELED)
            }
        } ?: throw IllegalStateException("无法读取课表日程")
        val reminders = mutableMapOf<Long, Int>()
        for (ids in existing.map { it.id }.chunked(200)) {
            resolver.query(
                Reminders.CONTENT_URI,
                arrayOf(Reminders.EVENT_ID, Reminders.MINUTES, Reminders.METHOD),
                "${Reminders.EVENT_ID} IN (${ids.joinToString(",") { "?" }})",
                ids.map { "$it" }.toTypedArray(), null,
            )?.use { cursor ->
                while (cursor.moveToNext()) {
                    val eventId = cursor.getLong(0)
                    val value = if (cursor.getInt(2) == Reminders.METHOD_ALERT) cursor.getInt(1) else -1
                    reminders[eventId] = if (reminders.containsKey(eventId)) -1 else value
                }
            } ?: throw IllegalStateException("无法读取日历提醒")
        }
        val uidsById = existing.associate { it.id to it.event.uid }
        val plan = calendarPlan(existing.map {
            it.copy(event = it.event.copy(
                reminder = reminders[it.id] ?: 0,
                originalUid = it.event.originalUid ?: originalIds[it.id]?.let(uidsById::get),
            ))
        }, desired, terms, protectedUids)
        val operations = arrayListOf<ContentProviderOperation>()
        val parentIds = mutableMapOf<String, Long>()
        existing.forEach { parentIds.putIfAbsent(it.event.uid, it.id) }
        val insertedIds = mutableMapOf<Int, String>()
        fun flush() {
            if (operations.isEmpty()) return
            val results = resolver.applyBatch(CalendarContract.AUTHORITY, operations)
            insertedIds.forEach { (index, uid) ->
                parentIds[uid] = ContentUris.parseId(checkNotNull(results[index].uri))
            }
            insertedIds.clear()
            operations.clear()
        }
        fun values(event: CalendarEvent) = ContentValues().apply {
            put(Events.CALENDAR_ID, id)
            put(Events._SYNC_ID, event.uid)
            put(Events.TITLE, event.title)
            put(Events.EVENT_LOCATION, event.location)
            put(Events.DESCRIPTION, event.description)
            put(Events.DTSTART, event.start)
            if (event.rrule == null) {
                put(Events.DTEND, event.end)
                putNull(Events.DURATION)
            } else {
                putNull(Events.DTEND)
                put(Events.DURATION, "PT${(event.end - event.start) / 1000}S")
            }
            put(Events.RRULE, event.rrule)
            put(Events.EXDATE, event.exdate)
            if (event.originalUid != null) {
                put(Events.ORIGINAL_ID, checkNotNull(parentIds[event.originalUid]))
                put(Events.ORIGINAL_SYNC_ID, event.originalUid)
                put(Events.ORIGINAL_INSTANCE_TIME, event.originalStart)
                put(Events.ORIGINAL_ALL_DAY, 0)
            } else {
                putNull(Events.ORIGINAL_ID)
                putNull(Events.ORIGINAL_SYNC_ID)
                putNull(Events.ORIGINAL_INSTANCE_TIME)
                putNull(Events.ORIGINAL_ALL_DAY)
            }
            put(Events.EVENT_TIMEZONE, "Asia/Shanghai")
            put(Events.HAS_ALARM, if (event.reminder > 0) 1 else 0)
            put(Events.STATUS, Events.STATUS_CONFIRMED)
            put(Events.DELETED, 0)
        }
        fun insert(event: CalendarEvent) {
            if (operations.size >= 90) flush()
            val reference = operations.size
            insertedIds[reference] = event.uid
            operations += ContentProviderOperation.newInsert(syncUri(Events.CONTENT_URI))
                .withValues(values(event)).build()
            if (event.reminder > 0) {
                operations += ContentProviderOperation.newInsert(syncUri(Reminders.CONTENT_URI))
                    .withValueBackReference(Reminders.EVENT_ID, reference)
                    .withValue(Reminders.MINUTES, event.reminder)
                    .withValue(Reminders.METHOD, Reminders.METHOD_ALERT).build()
            }
        }
        fun update(eventId: Long, event: CalendarEvent) {
            if (operations.size >= 90) flush()
            operations += ContentProviderOperation.newUpdate(syncUri(ContentUris.withAppendedId(Events.CONTENT_URI, eventId)))
                .withValues(values(event)).build()
            operations += ContentProviderOperation.newDelete(syncUri(Reminders.CONTENT_URI))
                .withSelection("${Reminders.EVENT_ID}=?", arrayOf("$eventId")).build()
            if (event.reminder > 0) {
                operations += ContentProviderOperation.newInsert(syncUri(Reminders.CONTENT_URI))
                    .withValue(Reminders.EVENT_ID, eventId).withValue(Reminders.MINUTES, event.reminder)
                    .withValue(Reminders.METHOD, Reminders.METHOD_ALERT).build()
            }
        }
        // Parent IDs must exist before linking a single-occurrence exception.
        plan.insert.filter { it.originalUid == null }.forEach(::insert)
        plan.update.filter { it.second.originalUid == null }.forEach { (id, event) -> update(id, event) }
        flush()
        plan.insert.filter { it.originalUid != null }.forEach(::insert)
        plan.update.filter { it.second.originalUid != null }.forEach { (id, event) -> update(id, event) }
        // Only delete obsolete managed events after all new/changed events saved.
        flush()
        val exceptions = existing.filter { it.event.originalUid != null || originalIds.containsKey(it.id) }
            .map { it.id }.toSet()
        for (eventId in plan.delete.sortedBy { if (it in exceptions) 0 else 1 }) {
            if (operations.size >= 90) flush()
            operations += ContentProviderOperation.newDelete(syncUri(ContentUris.withAppendedId(Events.CONTENT_URI, eventId))).build()
        }
        flush()
        check(preferences.edit().putLong("lastSuccess", System.currentTimeMillis())
            .putBoolean("failed", false).putInt("count", occurrenceCount)
            .putInt("inserted", plan.insert.size).putInt("updated", plan.update.size)
            .putInt("deleted", plan.delete.size).commit()) { "无法保存日历同步状态" }
    }

    private fun durationMillis(value: String?): Long {
        val parts = value?.let {
            Regex("P(?:(\\d+)W)?(?:(\\d+)D)?(?:T(?:(\\d+)H)?(?:(\\d+)M)?(?:(\\d+)S)?)?")
                .matchEntire(it)?.groupValues
        } ?: return 0
        val units = listOf(7 * 86400L, 86400L, 3600L, 60L, 1L)
        return units.indices.sumOf { index -> (parts[index + 1].toLongOrNull() ?: 0) * units[index] } * 1000
    }
}
