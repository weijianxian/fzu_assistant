package com.weijx.fzu_widget_bridge

import java.util.UUID

/** Only scalar preference changes are used; null removes a key. */
internal interface WidgetPreferences {
    fun read(): Map<String, Any?>
    fun commit(changes: Map<String, Any?>): Boolean
}

internal class WidgetStorageException(val rollbackSucceeded: Boolean) :
    IllegalStateException(
        if (rollbackSucceeded) "无法保存小组件数据，已回滚"
        else "无法保存小组件数据，回滚失败",
    )

/** Process-only authorization must never be restored by disk rollback. */
internal class WidgetSyncFence {
    var blocked = false
    var revision = UUID.randomUUID().toString()
    val revoked = mutableSetOf<String>()

    fun advance() {
        revision = UUID.randomUUID().toString()
    }
}

/** Shared by every engine's plugin instance in the application process. */
internal class WidgetSyncStore(
    private val flutter: WidgetPreferences,
    private val widget: WidgetPreferences,
    private val state: WidgetPreferences,
    private val fence: WidgetSyncFence = PROCESS_FENCE,
    private val additionalEnabled: () -> Boolean = { false },
    private val now: () -> Long = System::currentTimeMillis,
) {
    companion object {
        val LOCK = Any()
        private val PROCESS_FENCE = WidgetSyncFence()
        const val FLUTTER_PREFS = "FlutterSharedPreferences"
        const val WIDGET_PREFS = "next_course_widget"
        const val STATE_PREFS = "widget_nightly_sync"
        const val BASELINE_REVISION = "__fzu_widget_bridge_revision"
        const val FIRST_ALARM_ID = 1_000_000
        const val LAST_ALARM_ID = Int.MAX_VALUE - 1_000

        // Logical names match SpKeys and CustomCourseStore.storageKey.
        val CACHE_KEYS = setOf(
            "cache_school_calendar",
            "cache_courses_map",
            "cache_holiday_adjustments_map",
        )
        val INPUT_KEYS = (CACHE_KEYS + setOf(
            "custom_courses_v1",
            "hidden_course_sessions",
            "auto_adjust_course",
            "west2_adjustments_access",
            "west2_adjustments_enabled",
            "locale_key",
        )).map { "flutter.$it" }.toSet()
    }

    fun getState(): Map<String, Any?> = synchronized(LOCK) {
        val values = state.read()
        val generation = values["generation"] as? String
        val active = generation != null && valid(values, generation, manual = true)
        val revoked = fence.blocked || (generation != null && generation in fence.revoked)
        mapOf(
            "enabled" to automaticEnabled(values),
            "minutes" to ((values["minutes"] as? Number)?.toInt() ?: 1380),
            "generation" to if (active) generation else null,
            "alarmId" to if (active) values["alarmId"] else null,
            "lastSuccess" to if (revoked) null else values["lastSuccess"],
            "lastAttempt" to if (revoked) null else values["lastAttempt"],
            "failed" to if (revoked) false else (values["failed"] as? Boolean ?: false),
        )
    }

    fun configure(enabled: Boolean, minutes: Int, generation: String) = synchronized(LOCK) {
        require(minutes in 0..1439) { "同步时间无效" }
        require(generation.isNotBlank()) { "缺少同步代次" }
        require(generation !in fence.revoked) { "已撤销的同步代次不可复用" }
        // Change authorization before any persistence. If configure fails,
        // every engine remains blocked until a successful fresh configuration.
        fence.blocked = true
        fence.advance()
        val before = state.read()
        (before["generation"] as? String)?.takeIf { it != generation }?.let {
            fence.revoked.add(it)
        }
        val counter = (before["alarmCounter"] as? Number)?.toLong()
        val alarmId = if (counter == null || counter < FIRST_ALARM_ID ||
            counter >= LAST_ALARM_ID) FIRST_ALARM_ID else (counter + 1).toInt()
        transaction(listOf(state to mapOf(
            "enabled" to enabled,
            "automaticEnabled" to enabled,
            "minutes" to minutes,
            "generation" to generation,
            "alarmId" to alarmId,
            "alarmCounter" to alarmId,
            // Configuring even the same generation invalidates prepared work.
            "revision" to UUID.randomUUID().toString(),
        )))
        fence.blocked = false
    }

    fun cancel() = synchronized(LOCK) {
        // A failed commit/rollback may restore the old generation on disk, but
        // it cannot undo this process-wide revocation or revive its baseline.
        fence.blocked = true
        fence.advance()
        (state.read()["generation"] as? String)?.let(fence.revoked::add)
        transaction(listOf(state to mapOf(
            "generation" to null,
            "alarmId" to null,
            "revision" to UUID.randomUUID().toString(),
            "lastSuccess" to null,
            "lastAttempt" to null,
            "failed" to null,
        )))
    }

    fun isValid(generation: String, manual: Boolean = false): Boolean = synchronized(LOCK) {
        valid(state.read(), generation, manual)
    }

    private fun valid(values: Map<String, Any?>, generation: String, manual: Boolean): Boolean =
        !fence.blocked && generation !in fence.revoked &&
            generation.isNotBlank() && values["generation"] == generation &&
            (manual || automaticEnabled(values))

    // Before the shared timetable settings existed, either destination could
    // keep the nightly task active. Preserve that state until first configure;
    // afterwards the shared automatic switch controls both destinations.
    private fun automaticEnabled(values: Map<String, Any?>): Boolean =
        values["automaticEnabled"] as? Boolean
            ?: ((values["enabled"] as? Boolean ?: true) || additionalEnabled())

    /** Calendar preferences participate in the same in-flight input fence. */
    fun invalidateInputs() = synchronized(LOCK) { fence.advance() }

    fun prepare(generation: String, manual: Boolean): Map<String, Any?>? = synchronized(LOCK) {
        val values = state.read()
        if (!valid(values, generation, manual)) return@synchronized null
        mapOf("baseline" to baseline(flutter.read(), values))
    }

    /** Foreground reads need no account/task generation. */
    fun readInputs(): Map<String, Any?> = synchronized(LOCK) {
        mapOf("baseline" to baseline(flutter.read(), state.read()))
    }

    /**
     * The host routes every foreground snapshot input writer through this
     * method, including whole-map WebDAV restores and cache deletion.
     */
    fun writeInputs(writes: Map<String, Any?>): Boolean = synchronized(LOCK) {
        require(writes.keys.all { "flutter.$it" in INPUT_KEYS }) { "不允许写入非小组件输入" }
        require(writes.values.all { it == null || it is String || it is Boolean }) {
            "小组件输入仅支持字符串、布尔值或删除"
        }
        if (writes.isEmpty()) return@synchronized true
        // Fence even identical writes and A -> B -> A edits. On failure,
        // conservatively invalidate pre-write baselines rather than revive them.
        fence.advance()
        transaction(listOf(flutter to writes.mapKeys { "flutter.${it.key}" }))
        true
    }

    /** Merge one term into the latest native map; never use a Dart-side copy. */
    fun writeCacheTerm(key: String, term: String, value: String): Boolean = synchronized(LOCK) {
        require(key in CACHE_KEYS) { "不允许写入非课表缓存" }
        val merged = WidgetSnapshotValidator.mergeCacheTerm(
            flutter.read()["flutter.$key"], term, value,
        )
        writeInputs(mapOf(key to merged))
    }

    /** Compare and publish under the same lock as input writers/background jobs. */
    fun publishSnapshot(
        expected: Map<String, Any?>,
        snapshot: String,
        onPublished: (() -> Unit)? = null,
    ): Boolean = synchronized(LOCK) {
        if (!matches(expected, baseline(flutter.read(), state.read()))) return@synchronized false
        WidgetSnapshotValidator.validate(snapshot)
        transaction(listOf(widget to mapOf("snapshot" to snapshot)))
        // Local publication leaves task timestamps, alarms and the input
        // revision untouched. Calendar work shares this lock and baseline,
        // including cancellation/reconfiguration; logout must also prevent a
        // fresh foreground read from writing while disconnect is in progress.
        if (!fence.blocked) onPublished?.invoke()
        true
    }

    private fun baseline(
        preferences: Map<String, Any?>,
        values: Map<String, Any?>,
    ): Map<String, Any?> = INPUT_KEYS.associateWith { key ->
        scalar(preferences[key])
    } + (BASELINE_REVISION to "${values["revision"] ?: ""}/${fence.revision}")

    private fun matches(expected: Map<String, Any?>, current: Map<String, Any?>): Boolean =
        expected.keys == current.keys && expected.mapValues { scalar(it.value) } == current

    private fun scalar(value: Any?): Any? = when (value) {
        null, is String, is Boolean -> value
        is Int, is Long -> (value as Number).toLong()
        is Float, is Double -> (value as Number).toDouble()
        else -> throw IllegalArgumentException("小组件缓存输入类型无效")
    }

    fun commit(
        generation: String,
        manual: Boolean,
        expected: Map<String, Any?>,
        writes: Map<String, String>,
        snapshot: String,
        onCommitted: (() -> Unit)? = null,
    ): Boolean = synchronized(LOCK) {
        val values = state.read()
        if (!valid(values, generation, manual)) return@synchronized false
        val current = baseline(flutter.read(), values)
        // Missing keys and explicit null differ: callers must return the whole
        // opaque baseline, including nulls for absent native preferences.
        if (!matches(expected, current)) return@synchronized false
        require(writes.keys.all { it in CACHE_KEYS }) { "不允许写入非课表缓存" }
        writes.values.forEach(WidgetSnapshotValidator::validateCache)
        WidgetSnapshotValidator.validate(snapshot)
        val timestamp = now()
        // Invalidate already-built foreground snapshots even if fetched cache
        // strings are identical. They cannot replace a newly published result.
        fence.advance()
        transaction(listOf(
            flutter to writes.mapKeys { "flutter.${it.key}" },
            widget to mapOf("snapshot" to snapshot),
            state to mapOf(
                "lastSuccess" to timestamp,
                "lastAttempt" to timestamp,
                "failed" to false,
            ),
        ))
        onCommitted?.invoke()
        true
    }

    fun markFailed(generation: String, manual: Boolean): Boolean = synchronized(LOCK) {
        if (!valid(state.read(), generation, manual)) return@synchronized false
        transaction(listOf(state to mapOf(
            "lastAttempt" to now(),
            "failed" to true,
        )))
        true
    }

    /**
     * Synchronous commits are serialized across engines. A failed commit may
     * already have changed SharedPreferences memory; restore that store too.
     * Only touched keys are restored, preserving unrelated user preferences.
     * SharedPreferences cannot provide a crash-atomic transaction across files.
     */
    private fun transaction(changes: List<Pair<WidgetPreferences, Map<String, Any?>>>) {
        val attempted = mutableListOf<Pair<WidgetPreferences, Map<String, Any?>>>()
        try {
            for ((preferences, patch) in changes) {
                if (patch.isEmpty()) continue
                val before = preferences.read()
                attempted += preferences to patch.keys.associateWith { before[it] }
                check(preferences.commit(patch)) { "Preference commit failed" }
            }
        } catch (_: Exception) {
            var restored = true
            for ((preferences, before) in attempted.asReversed()) {
                try {
                    if (!preferences.commit(before)) restored = false
                } catch (_: Exception) {
                    restored = false
                }
            }
            throw WidgetStorageException(restored)
        }
    }
}
