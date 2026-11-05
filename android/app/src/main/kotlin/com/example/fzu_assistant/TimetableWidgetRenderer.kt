package com.weijx.fzu_assistant

import android.content.Context
import android.content.res.Configuration
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.RectF
import android.graphics.Typeface
import android.graphics.drawable.Icon
import android.os.Build
import android.text.Layout
import android.text.StaticLayout
import android.text.TextPaint
import android.text.TextUtils
import android.view.View
import android.widget.RemoteViews
import kotlin.math.floor
import kotlin.math.max
import kotlin.math.min
import kotlin.math.sqrt

/** A bounded bitmap keeps a seven-column timetable consistent across launcher sizes. */
internal object TimetableWidgetRenderer {
    fun render(
        context: Context, snapshot: CourseWidgetSnapshot, now: Long, width: Float, height: Float,
    ): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.timetable_widget)
        val monday = WidgetClock.monday(now)
        val daysByStart = snapshot.days.associateBy { it.start }
        val week = (0..6).map { daysByStart[monday + it * WidgetClock.DAY_MILLIS] }
        fun number(day: WidgetDay?) =
            day?.week ?: day?.courses?.firstOrNull()?.week?.takeIf { it > 0 }
        val number = number(daysByStart[WidgetClock.midnight(now)])
            ?: week.firstNotNullOfOrNull { number(it) }
        val title = context.getString(R.string.widget_timetable)
        views.setTextViewText(R.id.widget_heading, if (number == null) title
            else context.getString(R.string.widget_timetable_week, number))
        val range = context.getString(
            R.string.widget_week_range,
            WidgetClock.format(context, "MM-dd", monday),
            WidgetClock.format(context, "MM-dd", monday + 6 * WidgetClock.DAY_MILLIS),
        )
        views.setTextViewText(R.id.widget_date, range)
        val updated = when {
            !snapshot.signedIn -> context.getString(R.string.widget_sign_in_description)
            week.any { it?.known != true } -> context.getString(R.string.widget_week_partial)
            snapshot.updatedAt > 0 -> context.getString(
                R.string.widget_updated, WidgetClock.format(context, "MM-dd HH:mm", snapshot.updatedAt),
            )
            else -> context.getString(R.string.widget_beijing_time, range)
        }
        views.setTextViewText(R.id.widget_updated, updated)
        views.setContentDescription(R.id.widget_container, "$title. $range. $updated")
        if (!snapshot.signedIn) {
            views.setViewVisibility(R.id.widget_timetable_grid, View.GONE)
            views.setViewVisibility(R.id.widget_timetable_message, View.VISIBLE)
            views.setTextViewText(R.id.widget_timetable_message, context.getString(R.string.widget_sign_in))
            return views
        }

        views.setViewVisibility(R.id.widget_timetable_grid, View.VISIBLE)
        views.setViewVisibility(R.id.widget_timetable_message, View.GONE)
        // Account for XML padding, the 40dp header, footer and the grid's top margin.
        val gridWidth = (width - 24).coerceIn(140f, 600f)
        val gridHeight = (height - 90).coerceIn(96f, 700f)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            // The launcher selects the matching icon when its night mode changes,
            // without waiting for a provider update or starting the app.
            val light = nightContext(context, Configuration.UI_MODE_NIGHT_NO)
            val dark = nightContext(context, Configuration.UI_MODE_NIGHT_YES)
            views.setIcon(
                R.id.widget_timetable_grid, "setImageIcon",
                Icon.createWithBitmap(drawWeek(light, week, monday, now, gridWidth, gridHeight)),
                Icon.createWithBitmap(drawWeek(dark, week, monday, now, gridWidth, gridHeight)),
            )
        } else {
            views.setImageViewBitmap(R.id.widget_timetable_grid,
                drawWeek(context, week, monday, now, gridWidth, gridHeight))
        }
        val details = week.mapIndexed { index, day ->
            val date = monday + index * WidgetClock.DAY_MILLIS
            val dateText = WidgetClock.format(context, "MM-dd EEEE", date)
            val classes = when {
                day?.known != true -> context.getString(R.string.widget_unknown)
                day.courses.isEmpty() -> context.getString(R.string.widget_day_empty)
                else -> day.courses.joinToString("; ") {
                    listOf(
                        context.getString(R.string.widget_period_range, it.startClass, it.endClass),
                        "${WidgetClock.format(context, "HH:mm", it.start)}–${WidgetClock.format(context, "HH:mm", it.end)}",
                        it.name,
                        it.location.ifBlank { context.getString(R.string.widget_location_unknown) },
                    ).joinToString(", ")
                }
            }
            "$dateText: $classes"
        }.joinToString(". ")
        views.setContentDescription(R.id.widget_timetable_grid, details)
        return views
    }

    private fun nightContext(context: Context, nightMode: Int): Context =
        context.createConfigurationContext(Configuration(context.resources.configuration).apply {
            uiMode = (uiMode and Configuration.UI_MODE_NIGHT_MASK.inv()) or nightMode
        })

    private fun drawWeek(
        context: Context, days: List<WidgetDay?>, monday: Long, now: Long,
        width: Float, height: Float,
    ): Bitmap {
        // The host already scales the ImageView. Bound raster dimensions and memory
        // independently of launcher density and arbitrary resize options.
        val display = context.resources.displayMetrics
        // At most four size variants are sent in a single RemoteViews update.
        // Android 12+ stores both night modes, so budget for eight images total.
        val imageCount = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) 8f else 4f
        val pixelBudget = max(1f, display.widthPixels.toFloat() * display.heightPixels / imageCount)
        val scale = min(min(2f, display.density),
            min(min(720f / width, 1000f / height), sqrt(pixelBudget / (width * height))))
        val bitmap = Bitmap.createBitmap(
            max(1, (width * scale).toInt()), max(1, (height * scale).toInt()), Bitmap.Config.ARGB_8888,
        )
        val canvas = Canvas(bitmap)
        canvas.scale(scale, scale)
        val palette = WidgetPalette(context)
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) {
            // Older hosts cannot switch bitmap palettes. Keep text on its own
            // matching surface until the next provider update redraws the grid.
            canvas.drawColor(palette.surface)
        }
        val paint = Paint(Paint.ANTI_ALIAS_FLAG)
        val labelWidth = if (width >= 280) 24f else 20f
        val headerHeight = 32f
        val columnWidth = (width - labelWidth) / 7
        val rowHeight = (height - headerHeight) / 11
        val today = ((WidgetClock.midnight(now) - monday) / WidgetClock.DAY_MILLIS).toInt()

        days.forEachIndexed { index, day ->
            val left = labelWidth + index * columnWidth
            val date = monday + index * WidgetClock.DAY_MILLIS
            if (index == today) {
                paint.color = palette.todaySurface
                canvas.drawRoundRect(RectF(left + 1, 0f, left + columnWidth - 1, height), 10f, 10f, paint)
            }
            val dateText = WidgetClock.format(context, "d", date)
            val weekday = WidgetClock.format(context, if (columnWidth < 36) "EEEEE" else "EEE", date)
            centered(canvas, paint, weekday, left + columnWidth / 2, 10f, 9f,
                if (index == today) palette.accent else palette.secondary, false)
            centered(canvas, paint, dateText, left + columnWidth / 2, 24f, 11f,
                if (index == today) palette.accent else palette.primary, index == today)
            if (day?.known != true) {
                centered(canvas, paint, "?", left + columnWidth / 2,
                    headerHeight + (height - headerHeight) / 2, 16f, palette.secondary, false)
            }
        }
        for (period in 0..6) {
            val firstPeriod = (period * 2).coerceAtMost(11)
            val y = headerHeight + firstPeriod * rowHeight
            paint.color = palette.outline
            paint.strokeWidth = 0.5f
            canvas.drawLine(labelWidth, y, width, y, paint)
            if (period < 6) {
                val label = if (period == 5) "11" else "${period * 2 + 1}–${period * 2 + 2}"
                centered(canvas, paint, label,
                    labelWidth / 2 - 1, y + rowHeight * (if (period == 5) 0.5f else 1f) + 3,
                    8f, palette.secondary, false)
            }
        }
        days.forEachIndexed { index, day ->
            if (day?.known == true) {
                drawDay(canvas, paint, palette, day.courses,
                    labelWidth + index * columnWidth, columnWidth, headerHeight, rowHeight)
            }
        }
        if (days.all { it?.known == true } && days.all { it!!.courses.isEmpty() }) {
            val message = context.getString(R.string.widget_week_empty)
            paint.color = palette.surface
            val messageRect = RectF(labelWidth + 4, height / 2 - 15, width - 4, height / 2 + 15)
            canvas.drawRoundRect(messageRect, 12f, 12f, paint)
            centered(canvas, paint, message, messageRect.centerX(), messageRect.centerY() + 4,
                12f, palette.secondary, false)
        }
        return bitmap
    }

    private fun drawDay(
        canvas: Canvas, paint: Paint, palette: WidgetPalette, courses: List<WidgetCourse>,
        left: Float, width: Float, top: Float, rowHeight: Float,
    ) {
        // Assign lanes within connected overlap groups, including unequal start times.
        val ordered = courses.sortedWith(compareBy({ it.startClass }, { it.endClass }))
        var cursor = 0
        while (cursor < ordered.size) {
            var groupEnd = ordered[cursor].endClass
            var end = cursor + 1
            while (end < ordered.size && ordered[end].startClass <= groupEnd) {
                groupEnd = max(groupEnd, ordered[end].endClass)
                end++
            }
            val laneEnds = mutableListOf<Int>()
            val lanes = ordered.subList(cursor, end).map { course ->
                var lane = laneEnds.indexOfFirst { it < course.startClass }
                if (lane < 0) {
                    lane = laneEnds.size
                    laneEnds += course.endClass
                } else {
                    laneEnds[lane] = course.endClass
                }
                lane to course
            }
            val laneWidth = width / laneEnds.size
            lanes.forEach { (lane, course) ->
                val rect = RectF(
                    left + lane * laneWidth + 1.5f,
                    top + (course.startClass - 1) * rowHeight + 1,
                    left + (lane + 1) * laneWidth - 1.5f,
                    top + course.endClass * rowHeight - 1,
                )
                if (rect.width() > 0 && rect.height() > 0) {
                    val alternate = (course.name.hashCode() and 1) == 1
                    paint.color = if (alternate) palette.secondaryContainer else palette.primaryContainer
                    canvas.drawRoundRect(rect, 5f, 5f, paint)
                    drawCourse(canvas, course, rect,
                        if (alternate) palette.onSecondaryContainer else palette.onPrimaryContainer)
                }
            }
            cursor = end
        }
    }

    private fun drawCourse(canvas: Canvas, course: WidgetCourse, rect: RectF, color: Int) {
        val inset = if (rect.width() < 24) 2f else 3f
        val availableWidth = (rect.width() - inset * 2).toInt().coerceAtLeast(1)
        val availableHeight = rect.height() - 4
        val textSize = if (rect.width() >= 36) 10f else 9f
        val showLocation = rect.height() >= 46 && rect.width() >= 30 && course.location.isNotBlank()
        val nameHeight = availableHeight - if (showLocation) 13f else 0f
        val lines = max(1, floor(nameHeight / (textSize * 1.12f)).toInt())
        canvas.save()
        canvas.clipRect(rect)
        val name = block(course.name, availableWidth, textSize, color, true, lines)
        canvas.translate(rect.left + inset, rect.top + 2)
        name.draw(canvas)
        if (showLocation) {
            canvas.translate(0f, max(name.height.toFloat(), nameHeight))
            block(course.location, availableWidth, 8.5f, color, false, 1).draw(canvas)
        }
        canvas.restore()
    }

    private fun block(
        value: String, width: Int, size: Float, color: Int, bold: Boolean, lines: Int,
    ): StaticLayout {
        val paint = TextPaint(Paint.ANTI_ALIAS_FLAG).apply {
            textSize = size
            this.color = color
            typeface = Typeface.create("sans-serif", if (bold) Typeface.BOLD else Typeface.NORMAL)
        }
        return StaticLayout.Builder.obtain(value, 0, value.length, paint, width)
            .setAlignment(Layout.Alignment.ALIGN_NORMAL)
            .setIncludePad(false)
            .setLineSpacing(0f, 1.02f)
            .setMaxLines(lines)
            .setEllipsize(TextUtils.TruncateAt.END)
            .build()
    }

    private fun centered(
        canvas: Canvas, paint: Paint, value: String, x: Float, y: Float,
        size: Float, color: Int, bold: Boolean,
    ) {
        paint.color = color
        paint.textSize = size
        paint.typeface = Typeface.create("sans-serif", if (bold) Typeface.BOLD else Typeface.NORMAL)
        paint.textAlign = Paint.Align.CENTER
        canvas.drawText(value, x, y, paint)
        paint.textAlign = Paint.Align.LEFT
    }
}

private class WidgetPalette(private val context: Context) {
    private fun color(id: Int) = context.getColor(id)
    val surface = color(R.color.widget_background)
    val primary = color(R.color.widget_primary)
    val secondary = color(R.color.widget_secondary)
    val outline = color(R.color.widget_outline)
    val accent = color(R.color.widget_accent)
    val todaySurface = color(R.color.widget_today_surface)
    val primaryContainer = color(R.color.widget_primary_container)
    val onPrimaryContainer = color(R.color.widget_on_primary_container)
    val secondaryContainer = color(R.color.widget_secondary_container)
    val onSecondaryContainer = color(R.color.widget_on_secondary_container)
}
