package com.weijx.fzu_assistant;

import android.app.Activity;
import android.app.Instrumentation;
import android.content.ContentUris;
import android.content.ContentValues;
import android.content.Context;
import android.content.ContextWrapper;
import android.content.SharedPreferences;
import android.database.Cursor;
import android.net.Uri;
import android.os.Bundle;
import android.provider.CalendarContract;
import com.weijx.fzu_widget_bridge.SystemCalendarSync;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.text.SimpleDateFormat;
import java.util.Date;
import java.util.Locale;
import java.util.TimeZone;

/**
 * Runs against the real Calendar Provider without a Google account or network.
 * A separate preference namespace and account isolate all synthetic QA events.
 *
 * ./gradlew :app:assembleDebugAndroidTest
 * adb -s emulator-5554 shell am instrument -w \
 *   com.weijx.fzu_assistant.dev.test/com.weijx.fzu_assistant.CalendarSyncInstrumentation
 */
public class CalendarSyncInstrumentation extends Instrumentation {
    private static final String OWNER = "f".repeat(64);
    private Bundle arguments = Bundle.EMPTY;
    private Context context;
    private String account;

    @Override public void onCreate(Bundle arguments) {
        super.onCreate(arguments);
        this.arguments = arguments == null ? Bundle.EMPTY : new Bundle(arguments);
        start();
    }

    @Override public void onStart() {
        if ("widgetColors".equals(arguments.getString("suite"))) {
            new WidgetColorsRuntimeTest(this, arguments).run();
            return;
        }
        Bundle result = new Bundle();
        int resultCode = Activity.RESULT_CANCELED;
        try {
            Context target = getTargetContext();
            context = new ContextWrapper(target) {
                @Override public SharedPreferences getSharedPreferences(String name, int mode) {
                    return super.getSharedPreferences("calendar_instrumentation_" + name, mode);
                }
                @Override public String getPackageName() {
                    return target.getPackageName() + ".calendarqa";
                }
            };
            account = context.getPackageName() + ":" + OWNER;
            SystemCalendarSync sync = new SystemCalendarSync(context);
            Map<String, Object> settings = new HashMap<>();
            settings.put("enabled", true);
            settings.put("owner", OWNER);
            settings.put("includeExams", true);
            settings.put("reminder", 15);
            sync.configure(settings);
            cleanup();
            long realEvents = countRealEvents(target);

            Map<String, Object> course = event("202601:course", "Course", 15);
            Map<String, Object> exam = event("202601:exam", "Exam", 15);
            Map<String, Object> history = event("202501:history", "Previous term", 0);
            sync.sync(payload(List.of("202601", "202501"), List.of(course, exam, history)));
            check(number(sync.state(), "inserted") == 3, "First sync inserts three events");
            long calendar = calendarId();
            check(count(calendar) == 3, "Provider contains three events");
            List<Long> originalIds = ids(calendar);

            sync.sync(payload(List.of("202601", "202501"), List.of(course, exam, history)));
            check(number(sync.state(), "inserted") == 0 && number(sync.state(), "updated") == 0 &&
                number(sync.state(), "deleted") == 0, "Repeated sync performs no writes");
            check(originalIds.equals(ids(calendar)), "Repeated sync preserves provider IDs");
            context.getContentResolver().delete(
                ContentUris.withAppendedId(CalendarContract.Events.CONTENT_URI, originalIds.get(0)), null, null);
            sync.sync(payload(List.of("202601", "202501"), List.of(course, exam, history)));
            check(originalIds.equals(ids(calendar)), "A manually deleted managed event is restored with the same ID");
            check(number(sync.state(), "inserted") == 0 && number(sync.state(), "updated") == 1,
                "Provider tombstones do not create duplicates");

            Map<String, Object> moved = new HashMap<>(course);
            moved.put("title", "Changed course");
            moved.put("location", "New room");
            moved.put("reminder", 0);
            moved.put("start", ((Number) course.get("start")).longValue() + 60000);
            Map<String, Object> added = event("202601:new", "New course", 30);
            sync.sync(payload(List.of("202601"), List.of(moved, added)));
            check(number(sync.state(), "inserted") == 1 && number(sync.state(), "updated") == 1 &&
                number(sync.state(), "deleted") == 1, "Adds, updates and deletes in one reconciliation");
            check(count(calendar) == 3, "Other term is preserved");
            check(reminderCount(calendar) == 1, "Changed reminder is removed and new reminder is added");

            ContentValues manual = new ContentValues();
            manual.put(CalendarContract.Events.CALENDAR_ID, calendar);
            manual.put(CalendarContract.Events.TITLE, "Manual QA event");
            manual.put(CalendarContract.Events.DTSTART, course.get("start").toString());
            manual.put(CalendarContract.Events.DTEND, course.get("end").toString());
            manual.put(CalendarContract.Events.EVENT_TIMEZONE, "Asia/Shanghai");
            Uri manualUri = context.getContentResolver().insert(CalendarContract.Events.CONTENT_URI, manual);
            check(manualUri != null, "Manual event created");
            sync.sync(payload(List.of("202601"), List.of()));
            check(count(calendar) == 2, "Manual event and other term survive current-term deletion");

            Map<String, Object> bad = new HashMap<>(course);
            bad.put("end", 0L);
            boolean rejected = false;
            try {
                sync.sync(payload(List.of("202601"), List.of(bad)));
            } catch (IllegalArgumentException expected) {
                rejected = true;
            }
            check(rejected && count(calendar) == 2, "Malformed replacement does not mutate provider");

            // Migrate old expanded rows to one true series and one linked
            // exception, then verify the actual expanded provider Instances.
            long start = ((Number) course.get("start")).longValue();
            long week = 7 * 86400000L;
            Map<String, Object> legacy1 = event("202601:legacy1", "Legacy", 15);
            Map<String, Object> legacy2 = event("202601:legacy2", "Legacy", 15);
            legacy2.put("start", start + week);
            legacy2.put("end", start + week + 7200000L);
            sync.sync(payload(List.of("202601"), List.of(legacy1, legacy2)));
            Map<String, Object> series = event("202601:series", "Weekly course", 15);
            series.put("uid", "fzu-v2:202601:series");
            series.put("rrule", "FREQ=WEEKLY;INTERVAL=1;COUNT=4");
            series.put("exdate", timestamp(start + week));
            Map<String, Object> exception = event("202601:exception", "Weekly course", 15);
            exception.put("uid", "fzu-v2:202601:exception");
            exception.put("originalUid", series.get("uid"));
            exception.put("originalStart", start + 2 * week);
            exception.put("start", start + 2 * week + 86400000L);
            exception.put("end", start + 2 * week + 86400000L + 7200000L);
            exception.put("location", "Moved room");
            sync.sync(payload(List.of("202601"), List.of(series, exception)));
            check(number(sync.state(), "inserted") == 2 && number(sync.state(), "deleted") == 2,
                "Migration replaces expanded legacy records with a recurring parent and exception");
            check(count(calendar) == 4, "Only two recurring records plus manual/history remain");
            long parentId = idForUid(calendar, (String) series.get("uid"));
            long exceptionId = idForUid(calendar, (String) exception.get("uid"));
            check(exceptionParent(exceptionId) == parentId, "Exception links to its actual parent ID");
            List<Long> times = instanceTimes(calendar, List.of(parentId, exceptionId), start, start + 5 * week);
            check(times.equals(List.of(start, start + 2 * week + 86400000L, start + 3 * week)),
                "EXDATE excludes only week two and the exception moves only week three: " + times);
            sync.sync(payload(List.of("202601"), List.of(series, exception)));
            check(number(sync.state(), "inserted") == 0 && number(sync.state(), "updated") == 0 &&
                number(sync.state(), "deleted") == 0, "Recurring synchronization is idempotent");
            check(idForUid(calendar, (String) series.get("uid")) == parentId &&
                idForUid(calendar, (String) exception.get("uid")) == exceptionId, "Recurring IDs are stable");

            sync.sync(payload(List.of("202601"), List.of(series)));
            check(instanceTimes(calendar, List.of(parentId), start, start + 5 * week)
                .equals(List.of(start, start + 2 * week, start + 3 * week)),
                "Removing a moved exception restores the original occurrence");
            series.remove("exdate");
            sync.sync(payload(List.of("202601"), List.of(series)));
            check(instanceTimes(calendar, List.of(parentId), start, start + 5 * week)
                .equals(List.of(start, start + week, start + 2 * week, start + 3 * week)),
                "Removing EXDATE restores only the cancelled occurrence");

            settings.put("owner", "e".repeat(64));
            sync.configure(settings);
            Map<String, Object> secondPayload = new HashMap<>(payload(List.of("202601"), List.of(course)));
            secondPayload.put("owner", "e".repeat(64));
            sync.sync(secondPayload);
            String firstAccount = account;
            account = context.getPackageName() + ":" + "e".repeat(64);
            long secondCalendar = calendarId();
            account = firstAccount;
            check(count(secondCalendar) == 1, "Another account has its own events");
            sync.clearAll();
            check(!sync.getEnabled() && number(sync.state(), "count") == 0,
                "Clear all stops synchronization and clears its state");
            check(count(calendar) == 1 && count(secondCalendar) == 0,
                "Clear all removes managed events from every account and term, retaining the manual event");
            check(countRealEvents(target) == realEvents, "Other app calendars are unchanged");
            boolean paused = false;
            try { sync.sync(secondPayload); } catch (IllegalStateException expected) { paused = true; }
            check(paused, "Cleared events cannot be recreated by a stale enabled request");
            sync.clearAll();
            check(count(calendar) == 1, "Repeating clear all remains safe");
            sync.disconnect();
            check(!sync.getEnabled(), "Disconnect disables sync");
            check(count(calendar) == 1, "Disconnect keeps manual events");
            result.putString("stream", "\nPASS: real Calendar Provider insertion, idempotency, updates, deletion, " +
                "RRULE/EXDATE expansion, linked moved instances, legacy migration, multi-account cleanup, " +
                "reminders, term/manual-event isolation, invalid-payload preservation and pause.\n" +
                "Existing app-managed provider events before isolated QA: " + realEvents + "\n");
            result.putInt("tests", 1);
            resultCode = Activity.RESULT_OK;
        } catch (Throwable error) {
            result.putString("stream", "\nFAIL: " + error + "\n");
        } finally {
            if (context != null && account != null) {
                cleanup();
                context.getSharedPreferences("system_calendar_sync", Context.MODE_PRIVATE).edit().clear().commit();
            }
        }
        finish(resultCode, result);
    }

    private static Map<String, Object> event(String uid, String title, int reminder) {
        long start = 1794010800000L;
        Map<String, Object> value = new HashMap<>();
        value.put("uid", "fzu-v1:" + uid);
        value.put("title", title);
        value.put("location", "Room");
        value.put("description", "Calendar integration QA");
        value.put("start", start);
        value.put("end", start + 7200000L);
        value.put("reminder", reminder);
        return value;
    }

    private static Map<String, Object> payload(List<String> terms, List<Map<String, Object>> events) {
        return Map.of("owner", OWNER, "terms", terms, "events", events, "protected", List.of());
    }

    private static int number(Map<String, ?> state, String key) {
        return ((Number) state.get(key)).intValue();
    }

    private static String timestamp(long millis) {
        SimpleDateFormat format = new SimpleDateFormat("yyyyMMdd'T'HHmmss'Z'", Locale.ROOT);
        format.setTimeZone(TimeZone.getTimeZone("UTC"));
        return format.format(new Date(millis));
    }

    private long idForUid(long calendar, String uid) {
        try (Cursor c = context.getContentResolver().query(CalendarContract.Events.CONTENT_URI,
                new String[]{"_id"}, "calendar_id=? AND _sync_id=? AND deleted=0",
                new String[]{"" + calendar, uid}, null)) {
            check(c != null && c.moveToFirst(), "Managed event exists: " + uid);
            return c.getLong(0);
        }
    }

    private long exceptionParent(long id) {
        try (Cursor c = context.getContentResolver().query(
                ContentUris.withAppendedId(CalendarContract.Events.CONTENT_URI, id),
                new String[]{"original_id"}, null, null, null)) {
            check(c != null && c.moveToFirst(), "Exception exists");
            return c.getLong(0);
        }
    }

    private List<Long> instanceTimes(long calendar, List<Long> ids, long begin, long end) {
        Uri.Builder uri = CalendarContract.Instances.CONTENT_URI.buildUpon();
        ContentUris.appendId(uri, begin - 1);
        ContentUris.appendId(uri, end);
        String placeholders = String.join(",", java.util.Collections.nCopies(ids.size(), "?"));
        List<String> arguments = new ArrayList<>();
        arguments.add("" + calendar);
        ids.forEach(id -> arguments.add("" + id));
        List<Long> result = new ArrayList<>();
        try (Cursor c = context.getContentResolver().query(uri.build(),
                new String[]{CalendarContract.Instances.BEGIN},
                "calendar_id=? AND event_id IN (" + placeholders + ")",
                arguments.toArray(new String[0]), CalendarContract.Instances.BEGIN)) {
            check(c != null, "Provider expands Instances");
            while (c.moveToNext()) result.add(c.getLong(0));
        }
        return result;
    }

    private static void check(boolean valid, String message) {
        if (!valid) throw new AssertionError(message);
    }

    private long calendarId() {
        try (Cursor c = context.getContentResolver().query(CalendarContract.Calendars.CONTENT_URI,
                new String[]{"_id"}, "account_name=? AND account_type=? AND name=?",
                new String[]{account, CalendarContract.ACCOUNT_TYPE_LOCAL, "fzu-schedule-v1"}, null)) {
            check(c != null && c.moveToFirst(), "Dedicated calendar exists");
            return c.getLong(0);
        }
    }

    private List<Long> ids(long calendar) {
        List<Long> result = new ArrayList<>();
        try (Cursor c = context.getContentResolver().query(CalendarContract.Events.CONTENT_URI,
                new String[]{"_id"}, "calendar_id=? AND deleted=0", new String[]{"" + calendar}, "_id")) {
            check(c != null, "Provider query succeeds");
            while (c.moveToNext()) result.add(c.getLong(0));
        }
        return result;
    }

    private int count(long calendar) { return ids(calendar).size(); }

    private int reminderCount(long calendar) {
        int result = 0;
        for (long id : ids(calendar)) {
            try (Cursor c = context.getContentResolver().query(CalendarContract.Reminders.CONTENT_URI,
                    new String[]{"_id"}, "event_id=?", new String[]{"" + id}, null)) {
                check(c != null, "Reminder query succeeds");
                result += c.getCount();
            }
        }
        return result;
    }

    private long countRealEvents(Context target) {
        long total = 0;
        try (Cursor c = target.getContentResolver().query(CalendarContract.Calendars.CONTENT_URI,
                new String[]{"_id"}, "account_type=? AND name=? AND account_name<>?",
                new String[]{CalendarContract.ACCOUNT_TYPE_LOCAL, "fzu-schedule-v1", account}, null)) {
            if (c != null) while (c.moveToNext()) total += count(c.getLong(0));
        }
        return total;
    }

    private void cleanup() {
        List<String> accounts = new ArrayList<>();
        try (Cursor c = context.getContentResolver().query(CalendarContract.Calendars.CONTENT_URI,
                new String[]{"account_name"}, "account_type=? AND name=?",
                new String[]{CalendarContract.ACCOUNT_TYPE_LOCAL, "fzu-schedule-v1"}, null)) {
            if (c != null) while (c.moveToNext()) {
                String name = c.getString(0);
                if (name.startsWith(context.getPackageName() + ":")) accounts.add(name);
            }
        }
        for (String name : accounts) {
            Uri uri = CalendarContract.Calendars.CONTENT_URI.buildUpon()
                .appendQueryParameter(CalendarContract.CALLER_IS_SYNCADAPTER, "true")
                .appendQueryParameter(CalendarContract.Calendars.ACCOUNT_NAME, name)
                .appendQueryParameter(CalendarContract.Calendars.ACCOUNT_TYPE, CalendarContract.ACCOUNT_TYPE_LOCAL).build();
            context.getContentResolver().delete(uri, "account_name=? AND account_type=? AND name=?",
                new String[]{name, CalendarContract.ACCOUNT_TYPE_LOCAL, "fzu-schedule-v1"});
        }
    }
}
