package com.weijx.fzu_assistant

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.res.Configuration
import android.os.Build
import android.os.Bundle
import android.util.SizeF
import android.view.View
import android.widget.RemoteViews
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Date
import java.util.Locale
import java.util.TimeZone

/** Rendering is local. Background data synchronization belongs to the Dart scheduler. */
abstract class NextCourseWidgetProvider : AppWidgetProvider() {
    protected abstract val variant: CourseWidgetVariant

    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        ids.forEach { CourseWidgetRenderer.update(context, manager, it, variant, javaClass) }
    }

    override fun onAppWidgetOptionsChanged(
        context: Context, manager: AppWidgetManager, id: Int, newOptions: Bundle,
    ) {
        CourseWidgetRenderer.update(context, manager, id, variant, javaClass)
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        // The immutable callback cannot receive a filled-in widget ID.
        // Query this provider's bound widgets instead of trusting extras.
        if (intent.action == pinSuccessAction(variant.key)) {
            val manager = AppWidgetManager.getInstance(context)
            onUpdate(context, manager, manager.getAppWidgetIds(ComponentName(context, javaClass)))
            return
        }
        when (intent.action) {
            ACTION_REFRESH, Intent.ACTION_DATE_CHANGED, Intent.ACTION_TIME_CHANGED,
            Intent.ACTION_TIMEZONE_CHANGED, Intent.ACTION_LOCALE_CHANGED,
            Intent.ACTION_MY_PACKAGE_REPLACED -> updateAll(context)
        }
    }

    companion object {
        const val ACTION_REFRESH = "com.weijx.fzu_assistant.REFRESH_NEXT_COURSE_WIDGET"
        private const val ACTION_PIN_SUCCESS_PREFIX =
            "com.weijx.fzu_assistant.PIN_NEXT_COURSE_WIDGET."

        fun pinSuccessAction(variant: String) = ACTION_PIN_SUCCESS_PREFIX + variant

        fun preferences(context: Context) =
            context.getSharedPreferences("next_course_widget", Context.MODE_PRIVATE)

        fun providerClass(variant: String): Class<out NextCourseWidgetProvider> = when (variant) {
            "compact" -> NextCourseCompactWidgetProvider::class.java
            "square" -> NextCourseSquareWidgetProvider::class.java
            "timetable" -> TimetableWidgetProvider::class.java
            else -> throw IllegalArgumentException("未知的小组件尺寸")
        }

        fun updateAll(context: Context) {
            val manager = AppWidgetManager.getInstance(context)
            CourseWidgetVariant.entries.forEach { variant ->
                val provider = providerClass(variant.key)
                manager.getAppWidgetIds(ComponentName(context, provider)).forEach {
                    CourseWidgetRenderer.update(context, manager, it, variant, provider)
                }
            }
        }
    }
}

class NextCourseCompactWidgetProvider : NextCourseWidgetProvider() {
    override val variant = CourseWidgetVariant.COMPACT
}

class NextCourseSquareWidgetProvider : NextCourseWidgetProvider() {
    override val variant = CourseWidgetVariant.SQUARE
}

class TimetableWidgetProvider : NextCourseWidgetProvider() {
    override val variant = CourseWidgetVariant.TIMETABLE
}

enum class CourseWidgetVariant(val key: String, val defaultWidth: Float, val defaultHeight: Float) {
    COMPACT("compact", 156f, 72f),
    SQUARE("square", 156f, 156f),
    TIMETABLE("timetable", 300f, 320f),
}

internal data class WidgetCourse(
    val name: String,
    val location: String,
    val start: Long,
    val end: Long,
    val startClass: Int,
    val endClass: Int,
    val week: Int,
)

internal data class WidgetDay(
    val start: Long, val known: Boolean, val courses: List<WidgetCourse>, val week: Int?,
)

internal data class CourseWidgetSnapshot(
    val signedIn: Boolean,
    val language: String?,
    val updatedAt: Long,
    val days: List<WidgetDay>,
) {
    companion object {
        fun read(context: Context): CourseWidgetSnapshot {
            val raw = NextCourseWidgetProvider.preferences(context).getString("snapshot", null)
                ?: return CourseWidgetSnapshot(false, null, 0, emptyList())
            return try {
                val data = JSONObject(raw)
                require(data.getInt("version") == 1)
                val items = data.getJSONArray("days")
                require(items.length() <= 180)
                val days = (0 until items.length()).map { index ->
                    val item = items.getJSONObject(index)
                    val courses = item.getJSONArray("courses")
                    WidgetDay(
                        start = item.getLong("start"),
                        known = item.optBoolean("known", false),
                        courses = (0 until courses.length()).map { courseIndex ->
                            val course = courses.getJSONObject(courseIndex)
                            WidgetCourse(
                                name = course.getString("name"),
                                location = course.optString("location"),
                                start = course.getLong("start"),
                                end = course.getLong("end"),
                                startClass = course.getInt("startClass"),
                                endClass = course.getInt("endClass"),
                                week = course.optInt("week", 0),
                            ).also {
                                require(it.end > it.start && it.startClass in 1..11 &&
                                    it.endClass in it.startClass..11)
                            }
                        }.sortedBy { it.start },
                        week = item.optInt("week", 0).takeIf { it > 0 },
                    )
                }.sortedBy { it.start }
                CourseWidgetSnapshot(
                    data.optBoolean("signedIn", false),
                    data.optString("locale"),
                    // An explicit zero means cache freshness is unknown.
                    if (data.has("sourceUpdatedAt")) data.optLong("sourceUpdatedAt", 0)
                    else data.optLong("generatedAt", 0),
                    days,
                )
            } catch (_: Exception) {
                // Invalid coverage is unknown, never an empty week.
                CourseWidgetSnapshot(true, null, 0, emptyList())
            }
        }
    }

    fun next(now: Long): Pair<Boolean, List<WidgetCourse>> {
        if (!signedIn) return false to emptyList()
        val today = days.indexOfFirst { now >= it.start && now < it.start + WidgetClock.DAY_MILLIS }
        if (today < 0) return true to emptyList()
        for (day in days.drop(today)) {
            if (!day.known) return true to emptyList()
            val remaining = day.courses.filter { it.end > now }
            if (remaining.isNotEmpty()) {
                return false to remaining.filter { it.start == remaining.first().start }
            }
        }
        return false to emptyList()
    }
}

internal object WidgetClock {
    const val DAY_MILLIS = 86_400_000L
    private val beijing = TimeZone.getTimeZone("Asia/Shanghai")

    fun format(context: Context, pattern: String, epoch: Long): String {
        val locale = context.resources.configuration.locales[0]
        return SimpleDateFormat(pattern, locale).apply { timeZone = beijing }.format(Date(epoch))
    }

    fun midnight(now: Long): Long = Calendar.getInstance(beijing).apply {
        timeInMillis = now
        set(Calendar.HOUR_OF_DAY, 0)
        set(Calendar.MINUTE, 0)
        set(Calendar.SECOND, 0)
        set(Calendar.MILLISECOND, 0)
    }.timeInMillis

    fun monday(now: Long): Long = Calendar.getInstance(beijing).apply {
        timeInMillis = midnight(now)
        add(Calendar.DAY_OF_MONTH, -((get(Calendar.DAY_OF_WEEK) + 5) % 7))
    }.timeInMillis

    fun localize(context: Context, language: String?): Context {
        if (language != "zh" && language != "en") return context
        return context.createConfigurationContext(Configuration(context.resources.configuration).apply {
            setLocale(Locale.forLanguageTag(language))
        })
    }
}

internal object CourseWidgetRenderer {
    fun update(
        context: Context,
        manager: AppWidgetManager,
        id: Int,
        variant: CourseWidgetVariant,
        provider: Class<out NextCourseWidgetProvider>,
    ) {
        val snapshot = CourseWidgetSnapshot.read(context)
        val localized = WidgetClock.localize(context, snapshot.language)
        val options = manager.getAppWidgetOptions(id)
        val now = System.currentTimeMillis()
        fun render(width: Float, height: Float): RemoteViews =
            if (variant == CourseWidgetVariant.TIMETABLE) {
                TimetableWidgetRenderer.render(localized, snapshot, now, width, height)
            } else {
                nextClass(localized, snapshot, now, height)
            }.also { bindActions(context, localized, it, id, provider) }

        val views = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            @Suppress("DEPRECATION")
            val suppliedSizes = options.getParcelableArrayList<SizeF>(AppWidgetManager.OPTION_APPWIDGET_SIZES)
            val sizes = suppliedSizes.orEmpty()
                .filter { it.width > 0 && it.height > 0 && it.width.isFinite() && it.height.isFinite() }
                .distinct().take(4)
            if (sizes.isNotEmpty()) {
                RemoteViews(sizes.associateWith { render(it.width, it.height) })
            } else {
                render(
                    options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH)
                        .takeIf { it > 0 }?.toFloat() ?: variant.defaultWidth,
                    options.getInt(AppWidgetManager.OPTION_APPWIDGET_MAX_HEIGHT)
                        .takeIf { it > 0 }?.toFloat() ?: variant.defaultHeight,
                )
            }
        } else {
            val portrait = render(
                options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH)
                    .takeIf { it > 0 }?.toFloat() ?: variant.defaultWidth,
                options.getInt(AppWidgetManager.OPTION_APPWIDGET_MAX_HEIGHT)
                    .takeIf { it > 0 }?.toFloat() ?: variant.defaultHeight,
            )
            val landscape = render(
                options.getInt(AppWidgetManager.OPTION_APPWIDGET_MAX_WIDTH)
                    .takeIf { it > 0 }?.toFloat() ?: variant.defaultWidth,
                options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT)
                    .takeIf { it > 0 }?.toFloat() ?: variant.defaultHeight,
            )
            RemoteViews(landscape, portrait)
        }
        manager.updateAppWidget(id, views)
    }

    private fun bindActions(
        context: Context, localized: Context, views: RemoteViews, id: Int,
        provider: Class<out NextCourseWidgetProvider>,
    ) {
        val open = Intent(context, MainActivity::class.java)
            .setAction(AppShortcutBridge.OPEN_SCHEDULE)
            .addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP)
        views.setOnClickPendingIntent(R.id.widget_container, PendingIntent.getActivity(
            context, id, open, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        ))
        val refresh = Intent(context, provider).setAction(NextCourseWidgetProvider.ACTION_REFRESH)
        views.setOnClickPendingIntent(R.id.widget_refresh, PendingIntent.getBroadcast(
            context, id, refresh, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        ))
        views.setContentDescription(R.id.widget_refresh, localized.getString(R.string.widget_refresh))
    }

    private fun nextClass(
        context: Context, snapshot: CourseWidgetSnapshot, now: Long, height: Float,
    ): RemoteViews {
        val compact = height < 130
        val layout = if (compact) R.layout.next_course_widget_compact
            else R.layout.next_course_widget_square
        val views = RemoteViews(context.packageName, layout)
        views.setInt(R.id.widget_course, "setMaxLines", if (compact && height < 68) 1 else 2)
        fun text(id: Int, value: String) = views.setTextViewText(id, value)
        fun show(id: Int, visible: Boolean) =
            views.setViewVisibility(id, if (visible) View.VISIBLE else View.GONE)
        fun format(pattern: String, instant: Long) = WidgetClock.format(context, pattern, instant)
        text(R.id.widget_heading, context.getString(R.string.widget_next_class))
        text(R.id.widget_date, format(if (compact) "MM-dd" else "MM-dd EEE", now))
        show(R.id.widget_time, false)
        show(R.id.widget_location, false)
        show(R.id.widget_updated, false)
        show(R.id.widget_status, false)
        show(R.id.widget_date, compact || height >= 144)
        show(R.id.widget_refresh, !compact)

        val (unknown, courses) = snapshot.next(now)
        val description = mutableListOf<String>()
        if (!snapshot.signedIn) {
            text(R.id.widget_course, context.getString(
                if (compact) R.string.widget_sign_in_short else R.string.widget_sign_in,
            ))
            text(R.id.widget_status, context.getString(R.string.widget_sign_in_short))
            description += context.getString(R.string.widget_sign_in)
            description += context.getString(R.string.widget_sign_in_description)
        } else if (unknown || courses.isEmpty()) {
            val title = context.getString(
                if (unknown) R.string.widget_unknown else R.string.widget_no_upcoming,
            )
            text(R.id.widget_course, title)
            text(R.id.widget_status, context.getString(
                if (unknown) R.string.widget_cache_missing else R.string.widget_cached,
            ))
            description += title
            description += context.getString(
                if (unknown) R.string.widget_refresh_description else R.string.widget_cached_range,
            )
        } else {
            val first = courses.first()
            val status = context.getString(
                if (first.start > now) R.string.widget_upcoming else R.string.widget_in_progress,
            )
            text(R.id.widget_status, status)
            text(R.id.widget_heading, status)
            val names = courses.joinToString(" / ") { it.name }
            val location = courses.map { it.location }.filter { it.isNotBlank() }.distinct()
                .joinToString(" / ").ifBlank { context.getString(R.string.widget_location_unknown) }
            text(R.id.widget_course, names)
            text(R.id.widget_time, if (compact) format("HH:mm", first.start)
                else "${format("HH:mm", first.start)}–${format("HH:mm", first.end)}")
            text(R.id.widget_location, location)
            text(R.id.widget_date, format(if (compact) "MM-dd" else "MM-dd EEE", first.start))
            show(R.id.widget_time, true)
            show(R.id.widget_location, !compact && height >= 144)
            description += status
            description += names
            description += "${format("MM-dd EEE HH:mm", first.start)}–${format("HH:mm", first.end)}"
            description += location
            description += context.getString(R.string.widget_period_range, first.startClass, first.endClass)
        }
        if (snapshot.signedIn && snapshot.updatedAt > 0) {
            val updated = context.getString(R.string.widget_updated, format("MM-dd HH:mm", snapshot.updatedAt))
            text(R.id.widget_updated, updated)
            show(R.id.widget_updated, !compact && height >= 230)
            description += updated
        }
        description += context.getString(R.string.widget_beijing_time, format("MM-dd EEE HH:mm", now))
        views.setContentDescription(R.id.widget_container, description.joinToString(". "))
        return views
    }
}
