# fzu_widget_bridge

Local Android Flutter plugin for publishing background course caches, widget
snapshots and system calendar events. It implements `FlutterPlugin`, has no Activity dependency, and declares
its Android implementation in `pubspec.yaml` so generated engine registration
also discovers it in `android_alarm_manager_plus`'s headless engine.

The channel is `com.weijx.fzu_assistant/widget_background`.
This package does not log in, perform network requests, schedule alarms, read
SecureStorage, or access credential/payment preferences. The host owns those
operations and passes display snapshots and, when authorized, course calendar events. Sync state
is stored separately in `widget_nightly_sync`, without account identity.

## Channel contract

Methods use StandardMethodCodec maps unless no arguments are indicated.

| Method | Arguments | Result |
| --- | --- | --- |
| `getState` | none | `{enabled: bool, minutes: int, generation: String?, alarmId: int?, lastSuccess: int?, lastAttempt: int?, failed: bool}` |
| `configure` | `{enabled: bool, minutes: int, generation: String}` | `null` |
| `cancel` | none | `null` |
| `prepare` | `{generation: String, manual?: bool}` | `{baseline: Map<String, Object?>}` or `null` if stale/disabled |
| `readInputs` | none | `{baseline: Map<String, Object?>}`, without requiring an account/task generation |
| `writeInputs` | `{writes: Map<String, String \| bool \| null>}` | `true`; storage/validation failure is a channel error |
| `writeCacheTerm` | `{key: String, term: String, value: String}` | `true`; atomically merges one JSON object/array into the latest cache map |
| `publishSnapshot` | `{baseline: Map<String, Object?>, snapshot: String}` | `true` if published; `false` if baseline changed |
| `commit` | `{generation: String, manual?: bool, baseline: Map<String, Object?>, writes: Map<String, String>, snapshot: String}` | `true` if published; `false` if stale/disabled or baseline changed |
| `markFailed` | `{generation: String, manual?: bool}` | `true` if recorded; `false` if stale/disabled |
| `acquireWakeLock` | `{generation: String}` | `true` if acquired; `false` if stale, disabled, or already held for that generation |
| `releaseWakeLock` | `{generation: String}` | `null` |

`enabled` defaults to `true`, `minutes` to `1380` (23:00 Beijing time), and
`failed` to `false`; generation, alarm ID and timestamps initially are `null`. `minutes`
must be 0–1439 and generation must be a nonblank opaque string without identity.
Timestamps are Unix epoch milliseconds. `configure` preserves previous attempt
and success timestamps, saves the preference and active generation, and
invalidates all previously prepared commits even when the active generation is
reused. It also releases old wake locks. A generation revoked by cancellation or
replacement cannot be configured again in the same process: use a new generation.
Reconfiguration persistence failure blocks task authorization until a successful
configuration.

Each successful `configure` allocates a new `alarmId`, including configuration of
the same active generation. The persistent `alarmCounter` stores the last
allocated ID: the first ID is `1000000`, subsequent IDs increment, and the ID
following `Int.MAX_VALUE - 1000` wraps to `1000000`. `cancel` removes `alarmId`
and preserves the counter. Only the host schedules/cancels these alarm IDs;
this plugin never invokes an alarm manager.

`enabled` is the shared automatic timetable refresh switch for caches, widgets,
and enabled calendar sync. `configure` persists `automaticEnabled` alongside the
legacy `enabled` key. Until that first configuration, old preferences retain
their effective state (`enabled || calendarEnabled`), so calendar-only users keep
their schedule after upgrading. Once configured, calendar sync cannot override
an explicitly disabled automatic switch. Manual refresh still updates all enabled
destinations. `getState` also adds `calendarEnabled`; `prepare` returns a `calendar`
configuration map, read under the same lock as the baseline.

`manual: true` bypasses only the enabled check on `prepare`, `commit` and
`markFailed`. It never bypasses generation/baseline checks. A disabled feature
can retain an active generation for manual refresh. `cancel` removes the active
generation, success/attempt timestamps and failure flag, invalidates all prepared
work, and releases all wake locks, while preserving `enabled` and `minutes`.
The process-wide authorization fence changes **before** persistence. Even when
the synchronous cancellation commit fails and rollback restores an old generation
on disk, every engine in the current process rejects its prepare/commit/failure
operations and wake-lock acquisition. `getState` masks its generation/alarm ID
and prior account status. Retrying configuration with that revoked generation is
rejected; a fresh generation can restore authorization. The host separately
clears the displayed widget snapshot during logout.

## Exact baseline contract

The host must pass `prepared['baseline']` back **unchanged**, including null
entries and the reserved revision entry. The baseline contains these raw keys
from legacy Android `FlutterSharedPreferences`:

```text
flutter.cache_school_calendar
flutter.cache_courses_map
flutter.cache_holiday_adjustments_map
flutter.custom_courses_v1
flutter.hidden_course_sessions
flutter.auto_adjust_course
flutter.west2_adjustments_access
flutter.west2_adjustments_enabled
flutter.locale_key
```

The names match `SpKeys` and `CustomCourseStore.storageKey`. There currently are
no separate Flutter widget settings; enabled/time/generation belong to
`widget_nightly_sync`. When another Flutter setting starts affecting snapshots,
add its raw key to `WidgetSyncStore.INPUT_KEYS`.

Values are **raw stored values**, not parsed or reserialized JSON. Missing keys
are included with `null`; strings, booleans, integer and floating-point
primitives are supported. JSON cache values remain strings. Integer values are
compared without 32/64-bit codec representation differences. String JSON is
compared byte-for-byte; equivalent JSON with different whitespace is changed.
No unrelated preference or authentication data is returned.

One reserved key, `__fzu_widget_bridge_revision`, combines an opaque configuration
revision from `widget_nightly_sync` and a process-wide storage/input revision;
it is not a Flutter preference. It makes a prepared operation invalid after
reconfiguration/cancellation, foreground input writes or background publication,
even if input strings are identical or have changed and then changed back.
Failed write attempts also conservatively invalidate previous baselines.
Do not strip it. The baseline itself is not persisted or logged.

## Foreground writers and snapshot publication

Every foreground writer of the nine input keys must use `writeInputs` instead
of writing directly to `SharedPreferences`. The keys are logical names without
`flutter.`; values must be strings, booleans or `null` (delete). Non-input keys
and other value types are rejected. This method saves the whole patch under the
same lock used by background commits and advances the input revision even for
identical values. It does not change widgets or nightly success timestamps.
The host must reload its cached Dart `SharedPreferences` after these native
writes before reading values.

For per-term cache updates, use `writeCacheTerm`, for example:

```dart
await channel.invokeMethod<bool>('writeCacheTerm', {
  'key': 'cache_courses_map',
  'term': term,
  'value': jsonEncode({'courses': courses, 'updatedAt': updatedAt}),
});
```

`key` must be one of the three logical `CACHE_KEYS` below. `value` must be a JSON
object or array string; arrays support holiday-adjustment records. Under the
shared lock the method reads the **latest** native whole-map object, replaces
only `term` with the parsed value and saves the merged map. A missing whole map
starts as `{}`. Invalid/corrupt existing maps are rejected, not overwritten.
Other terms, including a background update made after a foreground Dart read,
remain intact. This uses the same input revision, rollback and reload contract
as `writeInputs`.

A foreground snapshot builder first calls `readInputs`, builds from those
inputs, and passes the full opaque baseline to `publishSnapshot`. The method
validates and saves only the widget snapshot if the inputs/revision still
match. It needs no task generation; the host continues guarding the foreground
account and build revision. A successful background commit advances the revision
so an older foreground snapshot cannot overwrite it. `publishSnapshot` updates
all three widget providers and leaves nightly success/attempt state untouched.

## Exact writes contract

`writes` uses **logical Flutter keys without the `flutter.` prefix**. Its values
must be complete JSON **object strings**, matching `SharedPreferences.setString`
and `CacheHelper`. A subset or all three of the following are allowed:

```dart
{
  'cache_school_calendar': jsonEncode(calendar.toJson()),
  'cache_courses_map': jsonEncode(allCourseTermCaches),
  'cache_holiday_adjustments_map': jsonEncode(allHolidayTermCaches),
}
```

The plugin adds `flutter.` once. Raw prefixed keys, null values, deletions and
all other keys are rejected. In particular it cannot write custom/hidden
courses, language, theme, credentials or feature consent. Preserve other terms
when constructing the whole cache map.

`snapshot` is the serialized version 1 JSON object consumed by the existing
widget providers. It must have a `days` array of at most 180 entries and must
not exceed 2 MiB in UTF-8. Optional fields such as `sourceUpdatedAt` are preserved.
No account identifiers, credentials, cookies, tokens, keys or payment data may
be supplied in this display snapshot.

## Publishing and failures

All plugin instances share a JVM lock for state reads, generation changes,
baseline comparison and synchronous cache/snapshot commits. Valid publication
commits the cache patch, `next_course_widget.snapshot` and success state, setting
both timestamps to now and `failed` to `false`. It then broadcasts explicit
`APPWIDGET_UPDATE` intents with actual widget IDs to:

| Provider class | Preset |
| --- | --- |
| `com.weijx.fzu_assistant.NextCourseCompactWidgetProvider` | Next course, horizontal 2×1 |
| `com.weijx.fzu_assistant.NextCourseSquareWidgetProvider` | Next course, square 2×2 |
| `com.weijx.fzu_assistant.TimetableWidgetProvider` | This week's timetable, 4×4 |

Component package names use `Context.packageName`, so `.dev` builds work while
the class names remain fixed. Empty provider ID lists are skipped. Rendering
errors do not undo a successful storage transaction.

An unsuccessful synchronous storage commit restores all touched keys in reverse
order, including the failed store because Android may already have changed its
in-memory map. Unrelated keys are preserved. A channel error
`widget_storage_failed` includes `{rollbackSucceeded: bool}`. Invalid arguments
produce `widget_background_failed`. Neither validation failure nor stale work
writes a cache or snapshot. `markFailed` updates only attempt time/failure state
and retains the old snapshot and last successful timestamp.

SharedPreferences offers no crash-atomic transaction across multiple files:
rollback covers reported synchronous failures/exceptions in the live process,
not power loss/process death between files, or writers bypassing this bridge's
lock. The host should reload its legacy `SharedPreferences` after a successful
background commit before reading cached Dart values.

## Wake-lock ownership

The lock is `PARTIAL_WAKE_LOCK`, non-reference-counted, tagged
`fzu_assistant:widget_sync`, with a hard 120-second Android timeout. Acquiring
requires an enabled current generation. A second alarm for the same generation
returns `false`; it must immediately return without networking **and without
calling release**. The task that received `true` must call `releaseWakeLock`
in `finally`. Release works after generation changes. Configuring or cancelling
also releases every existing lock. Engine detachment leaves other engines'
tasks alone; the platform timeout remains the final bound.

No extra native scheduling or service is introduced. The manifest merges only
`WAKE_LOCK`, already used by the host. Nightly scheduling stays in
`android_alarm_manager_plus`.

## System calendar

`calendarState` returns the independent calendar settings and result counters.
`calendarConfigure` accepts `{settings: {owner, enabled, includeExams, reminder}}`.
`owner` is a SHA-256 account digest, never the student ID. The host requests
READ_CALENDAR and WRITE_CALENDAR from its Activity; this plugin only checks their
current grants. Calendar settings invalidate the shared baseline. Settings are
stored in `system_calendar_sync`, outside WebDAV. `calendarDisconnect` disables
sync, preserving events. Logout revokes the shared task before disconnecting.

When enabled, `commit` additionally accepts `calendar: {owner, terms, events,
protected}`. Every event has `uid`, `title`, `location`, `description`, UTC epoch
`start`/`end`, and `reminder` minutes (0 disables). UIDs use `fzu-v1:<term>:<hash>`.
Weekly/alternate-week series use `fzu-v2:<term>:<hash>` and add `rrule`
(`FREQ=WEEKLY;INTERVAL=1|2;COUNT=n`) and optional UTC `exdate` values. The
provider writes series with DTSTART/DURATION, without DTEND. Moved or modified
single occurrences add `originalUid` and `originalStart`; they are linked using
ORIGINAL_ID, ORIGINAL_SYNC_ID and ORIGINAL_INSTANCE_TIME. They do not recur.
The host expands timetable rules only in memory to build this compact plan;
ordinary occurrences are never stored as individual provider events.
`occurrenceCount` reports actual visible occurrences rather than provider rows.
Only freshly fetched complete terms enter `terms`; unparseable exams enter
`protected` to retain their last valid event. The provider creates a local
calendar identified by package, owner digest and `fzu-schedule-v1`. It reconciles
managed UIDs in those terms only, preserving manual events, historical terms
and other calendars. Repeated identical synchronization preserves provider IDs
and performs no event writes. Batches insert/update before deleting stale events.
All provider work remains inside the generation/baseline commit lock.
Parents are saved before their exceptions, exceptions are deleted before their
parents, and old expanded v1 course rows are removed only after the v2 plan is
saved. Exam UIDs remain v1 for migration and malformed-exam protection.

`calendarClear` first invalidates prepared inputs and disables calendar sync,
then removes managed v1/v2 events across all accounts/terms in this package's
own local calendars. It keeps manually added independent events and other
packages' calendars. The host confirms this operation and reconciles the shared
nightly schedule afterward, preserving the widget switch.

Calendar-provider failures set the separate calendar failure state without
undoing valid official caches/widgets. Nightly network failures preserve events
and the last success time. The next exact alarm is scheduled before networking;
no native scheduler is added.

The host has a dependency-free real-provider instrumentation test, isolated by
its own preferences and test owner. Grant calendar permissions on the emulator
first, build `:app:assembleDebugAndroidTest`, install that test APK, then run:

```text
adb -s emulator-5554 shell am instrument -w com.weijx.fzu_assistant.dev.test/com.weijx.fzu_assistant.CalendarSyncInstrumentation
```

It verifies insertion, idempotency, updates/deletions, reminders, preservation of
manual/historical events, malformed-payload rejection, real RRULE/EXDATE Instances,
linked moved instances, legacy migration, multi-account cleanup and pause. Test calendars
are removed afterward; the real app calendar is only counted.
