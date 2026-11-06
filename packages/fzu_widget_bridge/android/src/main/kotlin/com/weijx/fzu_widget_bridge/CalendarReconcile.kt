package com.weijx.fzu_widget_bridge

import java.text.SimpleDateFormat
import java.util.TimeZone

internal fun managedCalendarUid(uid: String, terms: Set<String>) =
    terms.any { uid.startsWith("fzu-v1:$it:") || uid.startsWith("fzu-v2:$it:") }

/** Provider-independent plan: never delete unmanaged events or other terms. */
internal data class CalendarEvent(
    val uid: String,
    val title: String,
    val location: String,
    val description: String,
    val start: Long,
    val end: Long,
    val reminder: Int,
    val rrule: String? = null,
    val exdate: String? = null,
    val originalUid: String? = null,
    val originalStart: Long? = null,
) {
    fun validate(terms: Set<String>) {
        require(managedCalendarUid(uid, terms) && uid.length < 160)
        require(title.isNotBlank() && end > start && reminder in 0..1440)
        require(listOf(title, location, description).all { it.length < 16000 })
        require((originalUid == null) == (originalStart == null))
        require(originalUid == null || (rrule == null && exdate == null && originalUid != uid))
        if (rrule != null) {
            val rule = Regex("FREQ=WEEKLY;INTERVAL=([12]);COUNT=(\\d{1,2})").matchEntire(rrule)
            require(rule != null && rule.groupValues[2].toInt() in 1..54)
        }
        if (exdate != null) {
            require(rrule != null)
            val dates = exdate.split(",")
            require(dates.size in 1..54 && dates.distinct().size == dates.size)
            val format = SimpleDateFormat("yyyyMMdd'T'HHmmss'Z'").apply {
                timeZone = TimeZone.getTimeZone("UTC")
                isLenient = false
            }
            require(dates.all { date ->
                Regex("\\d{8}T\\d{6}Z").matches(date) &&
                    runCatching { format.parse(date)?.let { format.format(it) == date } == true }
                        .getOrDefault(false)
            })
        }
    }
}

internal data class StoredCalendarEvent(val id: Long, val event: CalendarEvent, val deleted: Boolean = false)
internal data class CalendarPlan(
    val insert: List<CalendarEvent>,
    val update: List<Pair<Long, CalendarEvent>>,
    val delete: List<Long>,
)

internal fun calendarPlan(
    existing: List<StoredCalendarEvent>,
    desired: List<CalendarEvent>,
    terms: Set<String>,
    protectedUids: Set<String>,
): CalendarPlan {
    require(terms.isNotEmpty() && terms.all { it.matches(Regex("\\d{6}")) })
    require(desired.size <= 5000 && desired.map { it.uid }.toSet().size == desired.size)
    desired.forEach { it.validate(terms) }
    val byUid = desired.associateBy { it.uid }
    val exceptions = desired.filter { it.originalUid != null }
    require(exceptions.map { it.originalUid to it.originalStart }.toSet().size == exceptions.size)
    for (event in exceptions) {
        val parent = byUid[event.originalUid]
        require(parent?.rrule != null && parent.originalUid == null)
        val rule = Regex("FREQ=WEEKLY;INTERVAL=([12]);COUNT=(\\d{1,2})").matchEntire(parent.rrule)!!
        val step = rule.groupValues[1].toLong() * 7 * 24 * 60 * 60 * 1000
        val offset = event.originalStart!! - parent.start
        require(offset >= 0 && offset % step == 0L && offset / step < rule.groupValues[2].toInt())
        require(event.uid.substringBeforeLast(":") == parent.uid.substringBeforeLast(":"))
    }
    val wanted = desired.associateBy { it.uid }.toMutableMap()
    val update = mutableListOf<Pair<Long, CalendarEvent>>()
    val delete = mutableListOf<Long>()
    val seen = mutableSetOf<String>()
    for ((id, event, deleted) in existing) {
        if (!managedCalendarUid(event.uid, terms)) continue
        val replacement = wanted.remove(event.uid)
        if (replacement != null) {
            seen.add(event.uid)
            if (deleted || event != replacement) update += id to replacement
        } else if (event.uid !in protectedUids || event.uid in seen) {
            delete += id
        }
    }
    return CalendarPlan(wanted.values.toList(), update, delete)
}
