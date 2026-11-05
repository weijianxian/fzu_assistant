package com.weijx.fzu_widget_bridge

import org.json.JSONObject
import org.json.JSONArray
import org.json.JSONTokener

internal object WidgetSnapshotValidator {
    private const val MAX_BYTES = 2 * 1024 * 1024

    fun validateCache(raw: String) {
        // All three supported CacheHelper values are serialized JSON objects.
        JSONObject(raw)
    }

    fun mergeCacheTerm(existing: Any?, term: String, rawValue: String): String {
        val values = when (existing) {
            null -> JSONObject()
            is String -> JSONObject(existing)
            else -> throw IllegalArgumentException("现有课表缓存不是 JSON 对象字符串")
        }
        val tokener = JSONTokener(rawValue)
        val value = tokener.nextValue()
        require(value is JSONObject || value is JSONArray) { "学期缓存必须为 JSON 对象或数组" }
        require(tokener.nextClean() == '\u0000') { "学期缓存含有多余内容" }
        return values.put(term, value).toString()
    }

    fun validate(raw: String) {
        require(raw.toByteArray(Charsets.UTF_8).size <= MAX_BYTES) { "课程快照过大" }
        val data = JSONObject(raw)
        // Reject numeric/string coercion, including version 1.5 or "1".
        val version = data.get("version")
        require(version is Number && version.toDouble() == 1.0) { "课程快照版本无效" }
        require(data.getJSONArray("days").length() <= 180) { "课程快照天数过多" }
    }
}
