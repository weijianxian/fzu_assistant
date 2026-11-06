package com.weijx.fzu_widget_bridge

import org.junit.Assert.*
import org.junit.Test

class CalendarReconcileTest {
    private fun event(uid: String = "fzu-v1:202601:course", title: String = "课程", reminder: Int = 15) =
        CalendarEvent(uid, title, "教室", "教师", 1000L, 2000L, reminder)
    private val terms = setOf("202601")

    @Test fun idempotentSyncHasNoWrites() {
        val desired = event()
        val plan = calendarPlan(listOf(StoredCalendarEvent(1, desired)), listOf(desired), terms, emptySet())
        assertTrue(plan.insert.isEmpty())
        assertTrue(plan.update.isEmpty())
        assertTrue(plan.delete.isEmpty())
    }

    @Test fun updatesFieldsAndRemindersWithSameIdentity() {
        val desired = event(title = "新课程", reminder = 0).copy(location = "新教室", start = 1100)
        val plan = calendarPlan(listOf(StoredCalendarEvent(1, event())), listOf(desired), terms, emptySet())
        assertEquals(listOf(1L to desired), plan.update)
        assertTrue(plan.insert.isEmpty())
        assertTrue(plan.delete.isEmpty())
    }

    @Test fun restoresProviderTombstoneWithoutInsertingDuplicate() {
        val desired = event()
        val plan = calendarPlan(listOf(StoredCalendarEvent(1, desired, deleted = true)),
            listOf(desired), terms, emptySet())
        assertEquals(listOf(1L to desired), plan.update)
        assertTrue(plan.insert.isEmpty())
    }

    @Test fun deletesOnlyOwnedTermsAndKeepsManualEventsAndProtectedExams() {
        val exam = event("fzu-v1:202601:exam")
        val plan = calendarPlan(listOf(
            StoredCalendarEvent(1, event()),
            StoredCalendarEvent(2, event("manual")),
            StoredCalendarEvent(3, event("fzu-v1:202501:history")),
            StoredCalendarEvent(4, exam),
        ), emptyList(), terms, setOf(exam.uid))
        assertEquals(listOf(1L), plan.delete)
    }

    @Test fun reconcilesNewDeletedAndDuplicateRecordsTogether() {
        val desired = event()
        val added = event("fzu-v1:202601:new")
        val plan = calendarPlan(listOf(
            StoredCalendarEvent(1, desired),
            StoredCalendarEvent(2, desired),
            StoredCalendarEvent(3, event("fzu-v1:202601:removed")),
        ), listOf(desired, added), terms, emptySet())
        assertEquals(listOf(added), plan.insert)
        assertEquals(listOf(2L, 3L), plan.delete)
    }

    @Test(expected = IllegalArgumentException::class)
    fun rejectsPartialInvalidPayloadBeforeAnyPlan() {
        calendarPlan(emptyList(), listOf(event(), event("unmanaged")), terms, emptySet())
    }

    @Test(expected = IllegalArgumentException::class)
    fun refusesUnscopedDeletion() {
        calendarPlan(listOf(StoredCalendarEvent(1, event())), emptyList(), emptySet(), emptySet())
    }

    @Test fun migratesExpandedOccurrencesToOneSeriesAndKeepsHistoricalAndManualEvents() {
        val series = event("fzu-v2:202601:series").copy(rrule = "FREQ=WEEKLY;INTERVAL=1;COUNT=16")
        val plan = calendarPlan(listOf(
            StoredCalendarEvent(1, event("fzu-v1:202601:week1")),
            StoredCalendarEvent(2, event("fzu-v1:202601:week2")),
            StoredCalendarEvent(3, event("fzu-v1:202501:history")),
            StoredCalendarEvent(4, event("manual")),
        ), listOf(series), terms, emptySet())
        assertEquals(listOf(series), plan.insert)
        assertEquals(listOf(1L, 2L), plan.delete)
    }

    @Test fun updatesExcludedDatesAndSingleOccurrenceWithStableParentAndExceptionIds() {
        val series = event("fzu-v2:202601:series").copy(rrule = "FREQ=WEEKLY;INTERVAL=1;COUNT=4")
        val exception = event("fzu-v2:202601:exception").copy(
            originalUid = series.uid, originalStart = series.start, start = 3000, end = 4000,
        )
        val changed = exception.copy(location = "新教室", start = 5000, end = 6000)
        val excluded = series.copy(exdate = "20261107T002000Z")
        val plan = calendarPlan(listOf(StoredCalendarEvent(1, series), StoredCalendarEvent(2, exception)),
            listOf(excluded, changed), terms, emptySet())
        assertEquals(listOf(1L to excluded, 2L to changed), plan.update)
        assertTrue(plan.insert.isEmpty())
        assertTrue(plan.delete.isEmpty())
    }

    @Test(expected = IllegalArgumentException::class)
    fun rejectsOrphanExceptionBeforeWriting() {
        calendarPlan(emptyList(), listOf(event("fzu-v2:202601:exception").copy(
            originalUid = "fzu-v2:202601:absent", originalStart = 1000,
        )), terms, emptySet())
    }

    @Test(expected = IllegalArgumentException::class)
    fun rejectsExceptionOutsideTheOriginalSeries() {
        val series = event("fzu-v2:202601:series").copy(rrule = "FREQ=WEEKLY;INTERVAL=2;COUNT=4")
        val exception = event("fzu-v2:202601:exception").copy(
            originalUid = series.uid, originalStart = series.start + 7 * 86400000L,
        )
        calendarPlan(emptyList(), listOf(series, exception), terms, emptySet())
    }

    @Test(expected = IllegalArgumentException::class)
    fun rejectsInvalidRecurrenceBeforeWriting() {
        calendarPlan(emptyList(), listOf(event().copy(rrule = "FREQ=DAILY")), terms, emptySet())
    }

    @Test(expected = IllegalArgumentException::class)
    fun rejectsInvalidExcludedDateBeforeWriting() {
        calendarPlan(emptyList(), listOf(event().copy(
            rrule = "FREQ=WEEKLY;INTERVAL=1;COUNT=4", exdate = "20260230T000000Z",
        )), terms, emptySet())
    }
}
