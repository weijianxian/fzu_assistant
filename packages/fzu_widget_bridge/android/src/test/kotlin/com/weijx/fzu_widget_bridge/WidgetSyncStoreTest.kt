package com.weijx.fzu_widget_bridge

import org.junit.Assert.*
import org.junit.Test
import org.json.JSONObject

class WidgetSyncStoreTest {
    @Test fun calendarSharesAutomaticScheduleAndInputFencing() {
        val f = Fixture()
        var calendarEnabled = true
        val store = WidgetSyncStore(f.flutter, f.widget, f.state, f.fence,
            additionalEnabled = { calendarEnabled }) { f.now }
        store.configure(true, 1380, "calendar")
        @Suppress("UNCHECKED_CAST")
        val baseline = store.prepare("calendar", false)!!["baseline"] as Map<String, Any?>
        var writes = 0
        assertTrue(store.commit("calendar", false, baseline, emptyMap(), snapshot) { writes++ })
        assertEquals(1, writes)
        assertFalse(store.commit("calendar", false, baseline, emptyMap(), snapshot) { writes++ })
        assertEquals(1, writes)
        store.invalidateInputs()
        calendarEnabled = false
        assertFalse(store.commit("calendar", false, baseline, emptyMap(), snapshot))
    }

    @Test fun legacyAutomaticStateMigratesWithoutLosingCalendarOnlySchedules() {
        for (widgetEnabled in listOf(false, true)) {
            for (calendarEnabled in listOf(false, true)) {
                val f = Fixture()
                f.state.values["enabled"] = widgetEnabled
                f.state.values["generation"] = "old"
                val store = WidgetSyncStore(f.flutter, f.widget, f.state, f.fence,
                    additionalEnabled = { calendarEnabled }) { f.now }
                val effective = widgetEnabled || calendarEnabled
                assertEquals(effective, store.getState()["enabled"])
                assertEquals(effective, store.isValid("old"))
                store.configure(effective, 1380, "migrated")
                assertEquals(effective, f.state.values["automaticEnabled"])
                assertEquals(effective, store.isValid("migrated"))
            }
        }
    }

    @Test fun sharedAutomaticOffBlocksCalendarBackgroundButAllowsManualSync() {
        val f = Fixture()
        var calendarEnabled = true
        val store = WidgetSyncStore(f.flutter, f.widget, f.state, f.fence,
            additionalEnabled = { calendarEnabled }) { f.now }
        store.configure(true, 1380, "active")
        store.configure(false, 1380, "paused")
        assertEquals(false, store.getState()["enabled"])
        assertFalse(store.isValid("active", true))
        assertFalse(store.isValid("paused"))
        assertNull(store.prepare("paused", false))
        assertFalse(store.markFailed("paused", false))
        @Suppress("UNCHECKED_CAST")
        val baseline = store.prepare("paused", true)!!["baseline"] as Map<String, Any?>
        assertTrue(store.commit("paused", true, baseline, emptyMap(), snapshot))
        // Toggling the calendar destination cannot undo the shared preference.
        calendarEnabled = false
        calendarEnabled = true
        assertEquals(false, store.getState()["enabled"])
    }
    private val snapshot = """{"version":1,"days":[],"sourceUpdatedAt":123}"""

    private class Preferences(initial: Map<String, Any?> = emptyMap()) : WidgetPreferences {
        val values = initial.toMutableMap()
        var calls = 0
        var failAt: Int? = null
        var throwAt: Int? = null
        var failAlways = false

        override fun read(): Map<String, Any?> = values.toMap()

        override fun commit(changes: Map<String, Any?>): Boolean {
            calls++
            for ((key, value) in changes) {
                if (value == null) values.remove(key) else values[key] = value
            }
            // Model SharedPreferences changing memory before commit reports a
            // disk failure, not an unrealistically side-effect-free failure.
            if (calls == throwAt) throw IllegalStateException("Disk unavailable")
            return !failAlways && calls != failAt
        }
    }

    private class Fixture {
        val flutter = Preferences(mapOf(
            "flutter.cache_courses_map" to """{"old":{"courses":[]}}""",
            "flutter.auto_adjust_course" to true,
            "flutter.locale_key" to "zh",
            "flutter.auth_not_in_baseline" to "must-not-be-returned",
        ))
        val widget = Preferences(mapOf("snapshot" to "old-snapshot", "other" to "keep"))
        val state = Preferences()
        val fence = WidgetSyncFence()
        var now = 1_000L
        val store = WidgetSyncStore(flutter, widget, state, fence) { now }

        fun configure(enabled: Boolean = true, minutes: Int = 1380, generation: String = "g") =
            store.configure(enabled, minutes, generation)

        @Suppress("UNCHECKED_CAST")
        fun baseline(manual: Boolean = false, generation: String = "g"): Map<String, Any?> =
            store.prepare(generation, manual)!!["baseline"] as Map<String, Any?>

        @Suppress("UNCHECKED_CAST")
        fun foregroundBaseline(): Map<String, Any?> =
            store.readInputs()["baseline"] as Map<String, Any?>
    }

    private fun publish(
        fixture: Fixture,
        baseline: Map<String, Any?> = fixture.baseline(),
        manual: Boolean = false,
        writes: Map<String, String> = mapOf("cache_courses_map" to """{"new":{"courses":[]}}"""),
        rawSnapshot: String = snapshot,
        generation: String = "g",
    ) = fixture.store.commit(generation, manual, baseline, writes, rawSnapshot)

    private inline fun <reified T : Throwable> expect(block: () -> Unit): T {
        try {
            block()
        } catch (error: Throwable) {
            if (error is T) return error
            throw error
        }
        throw AssertionError("Expected ${T::class.simpleName}")
    }

    @Test fun defaultsDoNotCreateGenerationOrReadUnrelatedPreferences() {
        val f = Fixture()
        assertEquals(mapOf(
            "enabled" to true, "minutes" to 1380, "generation" to null,
            "alarmId" to null, "lastSuccess" to null, "lastAttempt" to null, "failed" to false,
        ), f.store.getState())
        assertNull(f.store.prepare("g", false))
        assertFalse(f.store.isValid("g"))
    }

    @Test fun configureStoresOnlySyncStateAndAcceptsDayBounds() {
        val f = Fixture()
        val flutterBefore = f.flutter.read()
        val widgetBefore = f.widget.read()
        f.configure(minutes = 0)
        assertEquals(0, f.store.getState()["minutes"])
        f.configure(minutes = 1439)
        assertEquals(1439, f.store.getState()["minutes"])
        assertEquals("g", f.store.getState()["generation"])
        assertEquals(flutterBefore, f.flutter.read())
        assertEquals(widgetBefore, f.widget.read())
        expect<IllegalArgumentException> { f.configure(minutes = -1) }
        expect<IllegalArgumentException> { f.configure(minutes = 1440) }
        expect<IllegalArgumentException> { f.configure(generation = " ") }
    }

    @Test fun baselineHasEveryRelevantRawKeyIncludingMissingAndLegacyValues() {
        val f = Fixture()
        f.flutter.values["flutter.west2_adjustments_enabled"] = true
        f.configure()
        val baseline = f.baseline()
        assertEquals(WidgetSyncStore.INPUT_KEYS + WidgetSyncStore.BASELINE_REVISION, baseline.keys)
        assertEquals("""{"old":{"courses":[]}}""", baseline["flutter.cache_courses_map"])
        assertEquals(true, baseline["flutter.auto_adjust_course"])
        assertEquals(true, baseline["flutter.west2_adjustments_enabled"])
        assertTrue(baseline.containsKey("flutter.custom_courses_v1"))
        assertNull(baseline["flutter.custom_courses_v1"])
        assertFalse(baseline.containsKey("flutter.auth_not_in_baseline"))
    }

    @Test fun disabledNightlyRefusesPrepareCommitAndFailureButRetainsGeneration() {
        val f = Fixture()
        f.configure()
        f.configure(enabled = false)
        val baseline = f.baseline(manual = true)
        assertNull(f.store.prepare("g", false))
        assertFalse(publish(f, baseline))
        assertFalse(f.store.markFailed("g", false))
        assertEquals("g", f.store.getState()["generation"])
        assertEquals("old-snapshot", f.widget.values["snapshot"])
    }

    @Test fun manualRefreshAndFailureWorkWhileDisabled() {
        val f = Fixture()
        f.configure(enabled = false)
        assertTrue(publish(f, f.baseline(manual = true), manual = true))
        assertEquals(snapshot, f.widget.values["snapshot"])
        assertEquals(1_000L, f.store.getState()["lastSuccess"])
        f.now = 2_000L
        assertTrue(f.store.markFailed("g", true))
        assertEquals(2_000L, f.store.getState()["lastAttempt"])
        assertEquals(true, f.store.getState()["failed"])
        assertEquals(snapshot, f.widget.values["snapshot"])
    }

    @Test fun manualFlagNeverBypassesGenerationOrCacheBaseline() {
        val f = Fixture()
        f.configure(enabled = false)
        val baseline = f.baseline(manual = true)
        assertNull(f.store.prepare("different", true))
        assertFalse(publish(f, baseline, manual = true, generation = "different"))
        assertFalse(f.store.markFailed("different", true))
        f.flutter.values["flutter.hidden_course_sessions"] = "[]"
        assertFalse(publish(f, baseline, manual = true))
    }

    @Test fun cancelClearsAccountStatusPreservingPreferencesAndSnapshot() {
        val f = Fixture()
        f.configure(enabled = false, minutes = 123)
        assertTrue(publish(f, f.baseline(manual = true), manual = true))
        f.store.markFailed("g", true)
        val baseline = f.baseline(manual = true)
        f.store.cancel()
        assertEquals(mapOf(
            "enabled" to false, "minutes" to 123, "generation" to null,
            "alarmId" to null, "lastSuccess" to null, "lastAttempt" to null, "failed" to false,
        ), f.store.getState())
        assertFalse(publish(f, baseline, manual = true))
        assertFalse(f.store.markFailed("g", true))
        assertNull(f.store.prepare("g", true))
        assertEquals(snapshot, f.widget.values["snapshot"])
    }

    @Test fun reusingGenerationAfterConfigureOrLogoutInvalidatesOldBaseline() {
        val f = Fixture()
        f.configure()
        val first = f.baseline()
        f.configure()
        assertFalse(publish(f, first))
        val second = f.baseline()
        f.store.cancel()
        expect<IllegalArgumentException> { f.configure() }
        f.configure(generation = "g2")
        assertFalse(publish(f, second))
        assertTrue(publish(f, f.baseline(generation = "g2"), generation = "g2"))
    }

    @Test fun separateEngineInstanceSeesCancellationAndNewConfiguration() {
        val f = Fixture()
        val otherEngine = WidgetSyncStore(f.flutter, f.widget, f.state, f.fence) { 500L }
        f.configure()
        val old = f.baseline()
        otherEngine.cancel()
        assertFalse(publish(f, old))
        otherEngine.configure(true, 1_000, "g2")
        assertEquals("g2", f.store.getState()["generation"])
        assertNull(f.store.prepare("g", true))
    }

    @Test fun everyRelevantInputChangeRejectsOldResults() {
        for (key in WidgetSyncStore.INPUT_KEYS) {
            val f = Fixture()
            f.configure()
            val baseline = f.baseline()
            f.flutter.values[key] = "changed"
            val before = f.flutter.read()
            assertFalse("Changed $key", publish(f, baseline))
            assertEquals(before, f.flutter.read())
            assertEquals("old-snapshot", f.widget.values["snapshot"])
            assertNull(f.store.getState()["lastSuccess"])
        }
    }

    @Test fun equivalentButReserializedJsonIsStillAChangedBaseline() {
        val f = Fixture()
        f.configure()
        val baseline = f.baseline()
        f.flutter.values["flutter.cache_courses_map"] = """{ "old": {"courses": []} }"""
        assertFalse(publish(f, baseline))
    }

    @Test fun unrelatedPreferenceChangesDoNotBlockOrGetOverwritten() {
        val f = Fixture()
        f.configure()
        val baseline = f.baseline()
        f.flutter.values["flutter.unrelated"] = "user-edit"
        assertTrue(publish(f, baseline))
        assertEquals("user-edit", f.flutter.values["flutter.unrelated"])
        assertEquals("must-not-be-returned", f.flutter.values["flutter.auth_not_in_baseline"])
    }

    @Test fun truncatedExtraOrRevisionStrippedBaselineIsRejected() {
        val f = Fixture()
        f.configure()
        val baseline = f.baseline()
        assertFalse(publish(f, baseline - "flutter.locale_key"))
        assertFalse(publish(f, baseline + ("flutter.unrelated" to null)))
        assertFalse(publish(f, baseline - WidgetSyncStore.BASELINE_REVISION))
        assertFalse(publish(f, baseline + (WidgetSyncStore.BASELINE_REVISION to "stale")))
    }

    @Test fun integerCodecWidthChangesAndFloatingPointPrimitivesAreSupported() {
        val f = Fixture()
        f.flutter.values["flutter.locale_key"] = 12L
        f.flutter.values["flutter.custom_courses_v1"] = 1.25f
        f.configure()
        val baseline = f.baseline().toMutableMap()
        baseline["flutter.locale_key"] = 12 // Dart reencodes a small int as Int32.
        assertEquals(1.25, baseline["flutter.custom_courses_v1"])
        assertTrue(publish(f, baseline))
    }

    @Test fun successfulCommitWritesLogicalCacheKeysAndBothTimestamps() {
        val f = Fixture()
        f.configure()
        assertTrue(publish(f, writes = WidgetSyncStore.CACHE_KEYS.associateWith { "{}" }))
        for (key in WidgetSyncStore.CACHE_KEYS) {
            assertEquals("{}", f.flutter.values["flutter.$key"])
            assertFalse(f.flutter.values.containsKey(key))
        }
        assertEquals(snapshot, f.widget.values["snapshot"])
        assertEquals(1_000L, f.store.getState()["lastSuccess"])
        assertEquals(1_000L, f.store.getState()["lastAttempt"])
        assertEquals(false, f.store.getState()["failed"])
        assertEquals("keep", f.widget.values["other"])
    }

    @Test fun onlyThreeLogicalCacheKeysAreWritable() {
        for (key in listOf(
            "flutter.cache_courses_map", "custom_courses_v1", "hidden_course_sessions",
            "locale_key", "west2_adjustments_access", "credentials", "snapshot", "unknown",
        )) {
            val f = Fixture()
            f.configure()
            val before = f.flutter.read()
            expect<IllegalArgumentException> { publish(f, writes = mapOf(key to "{}")) }
            assertEquals(before, f.flutter.read())
            assertEquals("old-snapshot", f.widget.values["snapshot"])
        }
    }

    @Test fun cacheWritesMustBeSerializedJsonObjects() {
        val f = Fixture()
        f.configure()
        for (value in listOf("not json", "[]", "null", "12")) {
            expect<Exception> { publish(f, writes = mapOf("cache_courses_map" to value)) }
            assertEquals("old-snapshot", f.widget.values["snapshot"])
        }
    }

    @Test fun reportedFailureAtEachStageRestoresAllTouchedStores() {
        for (stage in 0..2) {
            val f = Fixture()
            f.configure()
            val stores = listOf(f.flutter, f.widget, f.state)
            val before = stores.map { it.read() }
            stores[stage].failAt = stores[stage].calls + 1
            assertTrue(expect<WidgetStorageException> {
                publish(f, writes = mapOf("cache_school_calendar" to "{}"))
            }.rollbackSucceeded)
            assertEquals(before, stores.map { it.read() })
        }
    }

    @Test fun thrownFailureAlsoRollsBackFailedStoreInMemory() {
        val f = Fixture()
        f.configure()
        val before = listOf(f.flutter.read(), f.widget.read(), f.state.read())
        f.widget.throwAt = f.widget.calls + 1
        assertTrue(expect<WidgetStorageException> { publish(f) }.rollbackSucceeded)
        assertEquals(before, listOf(f.flutter.read(), f.widget.read(), f.state.read()))
    }

    @Test fun rollbackFailureIsReportedInsteadOfClaimingSuccess() {
        val f = Fixture()
        f.configure()
        f.widget.failAlways = true
        assertFalse(expect<WidgetStorageException> { publish(f) }.rollbackSucceeded)
        assertNull(f.store.getState()["lastSuccess"])
    }

    @Test fun failureStatusNeverRemovesSnapshotOrPreviousSuccess() {
        val f = Fixture()
        f.configure()
        assertTrue(publish(f))
        f.now = 2_000
        assertTrue(f.store.markFailed("g", false))
        assertEquals(1_000L, f.store.getState()["lastSuccess"])
        assertEquals(2_000L, f.store.getState()["lastAttempt"])
        assertEquals(true, f.store.getState()["failed"])
        assertEquals(snapshot, f.widget.values["snapshot"])
        f.now = 3_000
        assertTrue(publish(f))
        assertEquals(false, f.store.getState()["failed"])
        assertEquals(3_000L, f.store.getState()["lastAttempt"])
    }

    @Test fun snapshotsValidateVersionDaysUtf8BytesAndOptionalFields() {
        WidgetSnapshotValidator.validate(snapshot)
        WidgetSnapshotValidator.validate(
            """{"version":1,"days":[${List(180) { "{}" }.joinToString(",")}]}""",
        )
        for (value in listOf(
            """{"version":2,"days":[]}""",
            """{"version":"1","days":[]}""",
            """{"version":1.5,"days":[]}""",
            """{"version":1,"days":{}}""",
            """{"version":1,"days":[${List(181) { "{}" }.joinToString(",")}]}""",
            """{"version":1,"days":[],"extra":"${"课".repeat(700_000)}"}""",
        )) {
            expect<Exception> { WidgetSnapshotValidator.validate(value) }
        }
    }

    @Test fun invalidSnapshotLeavesAllStoresUntouched() {
        val f = Fixture()
        f.configure()
        val before = listOf(f.flutter.read(), f.widget.read(), f.state.read())
        expect<Exception> { publish(f, rawSnapshot = """{"version":2,"days":[]}""") }
        assertEquals(before, listOf(f.flutter.read(), f.widget.read(), f.state.read()))
    }

    @Test fun failedLogoutCannotRestoreAuthorizationInAnyEngineOrByReusingGeneration() {
        for (throwInsteadOfFalse in listOf(false, true)) {
            val f = Fixture()
            val otherEngine = WidgetSyncStore(f.flutter, f.widget, f.state, f.fence) { 500L }
            f.configure()
            val prepared = f.baseline()
            val foreground = f.foregroundBaseline()
            if (throwInsteadOfFalse) f.state.throwAt = f.state.calls + 1
            else f.state.failAt = f.state.calls + 1
            assertTrue(expect<WidgetStorageException> { f.store.cancel() }.rollbackSucceeded)
            // Rollback really restored persisted authorization, which must not
            // defeat revocation in the live process.
            assertEquals("g", f.state.values["generation"])
            assertFalse(f.store.isValid("g", true))
            assertFalse(otherEngine.isValid("g", true))
            assertNull(otherEngine.prepare("g", true))
            assertFalse(publish(f, prepared, manual = true))
            assertFalse(f.store.markFailed("g", true))
            assertFalse(f.store.publishSnapshot(foreground, snapshot))
            assertNull(f.store.getState()["generation"])
            assertNull(f.store.getState()["alarmId"])
            expect<IllegalArgumentException> { f.configure() }
            f.configure(generation = "fresh-generation")
            assertTrue(otherEngine.isValid("fresh-generation"))
            assertFalse(otherEngine.isValid("g", true))
        }
    }

    @Test fun foregroundWritersWhitelistLogicalKeysTypesDeletionAndRollback() {
        val f = Fixture()
        f.configure()
        assertTrue(f.store.writeInputs(mapOf(
            "cache_school_calendar" to "{}",
            "custom_courses_v1" to "[]",
            "auto_adjust_course" to false,
            "locale_key" to null,
        )))
        assertEquals("{}", f.flutter.values["flutter.cache_school_calendar"])
        assertEquals("[]", f.flutter.values["flutter.custom_courses_v1"])
        assertEquals(false, f.flutter.values["flutter.auto_adjust_course"])
        assertFalse(f.flutter.values.containsKey("flutter.locale_key"))
        val before = f.flutter.read()
        for (writes in listOf(
            mapOf("flutter.locale_key" to "en"),
            mapOf("credentials" to "forbidden"),
            mapOf("cache_courses_map" to 123),
            mapOf("custom_courses_v1" to listOf("bad")),
        )) {
            expect<IllegalArgumentException> { f.store.writeInputs(writes) }
            assertEquals(before, f.flutter.read())
        }
        val baseline = f.baseline()
        f.flutter.failAt = f.flutter.calls + 1
        assertTrue(expect<WidgetStorageException> {
            f.store.writeInputs(mapOf("custom_courses_v1" to "[{}]"))
        }.rollbackSucceeded)
        assertEquals(before, f.flutter.read())
        assertFalse(publish(f, baseline))
    }

    @Test fun identicalAndRestoredForegroundWritesInvalidateBothKindsOfPreparedWork() {
        val f = Fixture()
        f.configure()
        val background = f.baseline()
        val foreground = f.foregroundBaseline()
        f.store.writeInputs(mapOf("locale_key" to "zh"))
        assertFalse(publish(f, background))
        assertFalse(f.store.publishSnapshot(foreground, snapshot))
        val nextBackground = f.baseline()
        val nextForeground = f.foregroundBaseline()
        f.store.writeInputs(mapOf("locale_key" to "en"))
        f.store.writeInputs(mapOf("locale_key" to "zh"))
        assertFalse(publish(f, nextBackground))
        assertFalse(f.store.publishSnapshot(nextForeground, snapshot))
        assertTrue(f.store.publishSnapshot(f.foregroundBaseline(), snapshot))
    }

    @Test fun foregroundPublishNeedsNoTaskGenerationButChecksConfigurationAndInputs() {
        val f = Fixture()
        val baseline = f.foregroundBaseline()
        assertTrue(f.store.publishSnapshot(baseline, snapshot))
        assertNull(f.store.getState()["lastSuccess"])
        assertNull(f.store.getState()["lastAttempt"])
        f.configure()
        assertFalse(f.store.publishSnapshot(baseline, snapshot))
        val current = f.foregroundBaseline()
        f.store.cancel()
        assertFalse(f.store.publishSnapshot(current, snapshot))
        val cancelled = f.foregroundBaseline()
        val before = f.widget.read()
        expect<Exception> {
            f.store.publishSnapshot(cancelled, """{"version":2,"days":[]}""")
        }
        assertEquals(before, f.widget.read())
        assertTrue(f.store.publishSnapshot(cancelled, snapshot))
    }

    @Test fun backgroundPublicationPreventsAnOlderForegroundSnapshotOverwritingIt() {
        val f = Fixture()
        f.configure()
        val foreground = f.foregroundBaseline()
        // Even no changed input strings must advance the publication fence.
        assertTrue(publish(f, writes = emptyMap()))
        assertFalse(f.store.publishSnapshot(foreground, """{"version":1,"days":[]}"""))
        assertEquals(snapshot, f.widget.values["snapshot"])
        assertTrue(f.store.publishSnapshot(f.foregroundBaseline(), snapshot))
        assertEquals(1_000L, f.store.getState()["lastSuccess"])
    }

    @Test fun alarmIdsRotatePersistAcrossCancelAndRestartAndWrapWithoutOverflow() {
        val f = Fixture()
        f.configure()
        assertEquals(1_000_000, f.store.getState()["alarmId"])
        f.configure() // Reconfiguring the same active generation also rotates.
        assertEquals(1_000_001, f.store.getState()["alarmId"])
        f.store.cancel()
        assertNull(f.store.getState()["alarmId"])
        assertEquals(1_000_001, f.state.values["alarmCounter"])
        // Simulate a fresh JVM fence with the same persisted preferences.
        val restarted = WidgetSyncStore(f.flutter, f.widget, f.state, WidgetSyncFence()) { 5L }
        restarted.configure(true, 1380, "next")
        assertEquals(1_000_002, restarted.getState()["alarmId"])
        f.state.values["alarmCounter"] = WidgetSyncStore.LAST_ALARM_ID - 1
        restarted.configure(true, 1380, "next")
        assertEquals(WidgetSyncStore.LAST_ALARM_ID, restarted.getState()["alarmId"])
        restarted.configure(true, 1380, "next")
        assertEquals(WidgetSyncStore.FIRST_ALARM_ID, restarted.getState()["alarmId"])
    }

    @Test fun termMergePreservesBackgroundTermsAndAcceptsObjectArrayOrAbsentCache() {
        val f = Fixture()
        f.configure()
        // A foreground caller may already have read the old map. Native merge
        // must instead retain the whole background map committed meanwhile.
        assertTrue(publish(f, writes = mapOf("cache_courses_map" to
            """{"old":{"courses":[]},"background":{"courses":[],"updatedAt":42}}""")))
        val beforeMerge = f.foregroundBaseline()
        assertTrue(f.store.writeCacheTerm(
            "cache_courses_map", "old", """{"courses":[{"name":"foreground"}]}""",
        ))
        val courses = JSONObject(f.flutter.values["flutter.cache_courses_map"] as String)
        assertEquals(42, courses.getJSONObject("background").getInt("updatedAt"))
        assertEquals("foreground", courses.getJSONObject("old")
            .getJSONArray("courses").getJSONObject(0).getString("name"))
        assertFalse(f.store.publishSnapshot(beforeMerge, snapshot))
        assertTrue(f.store.writeCacheTerm(
            "cache_holiday_adjustments_map", "term-a", """[{"date":"2026-11-05"}]""",
        ))
        assertTrue(f.store.writeCacheTerm("cache_holiday_adjustments_map", "term-b", "[]"))
        val holidays = JSONObject(f.flutter.values["flutter.cache_holiday_adjustments_map"] as String)
        assertEquals(1, holidays.getJSONArray("term-a").length())
        assertEquals(0, holidays.getJSONArray("term-b").length())
        assertEquals(snapshot, f.widget.values["snapshot"])
        assertEquals(1_000L, f.store.getState()["lastSuccess"])
    }

    @Test fun termMergeRejectsBadInputsOrCorruptMapsAndRollsBackReportedFailure() {
        val f = Fixture()
        f.configure()
        val before = f.flutter.read()
        for (key in listOf("flutter.cache_courses_map", "custom_courses_v1", "unknown")) {
            expect<IllegalArgumentException> { f.store.writeCacheTerm(key, "term", "{}") }
        }
        for (value in listOf("null", "1", "\"text\"", "{} {}", "not-json")) {
            expect<Exception> { f.store.writeCacheTerm("cache_courses_map", "term", value) }
        }
        assertEquals(before, f.flutter.read())
        for (corrupt in listOf("[]", "broken", true)) {
            f.flutter.values["flutter.cache_courses_map"] = corrupt
            val corrupted = f.flutter.read()
            expect<Exception> { f.store.writeCacheTerm("cache_courses_map", "term", "{}") }
            assertEquals(corrupted, f.flutter.read())
        }
        f.flutter.values.clear()
        f.flutter.values.putAll(before)
        val prepared = f.baseline()
        f.flutter.failAt = f.flutter.calls + 1
        assertTrue(expect<WidgetStorageException> {
            f.store.writeCacheTerm("cache_courses_map", "term", "{}")
        }.rollbackSucceeded)
        assertEquals(before, f.flutter.read())
        assertFalse(publish(f, prepared))
    }
}
