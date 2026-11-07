package com.weijx.fzu_widget_bridge

/** Called only inside WidgetSyncStore's validated foreground publication lock. */
internal fun publishLocalCalendar(
    state: Map<String, Any?>,
    payload: Map<String, Any?>?,
    sync: (Map<String, Any?>) -> Unit,
    onFailure: (Exception) -> Unit,
) {
    if (payload == null || state["enabled"] != true || state["granted"] != true) return
    val owner = state["owner"] as? String ?: return
    if (payload["owner"] != owner) return
    try {
        sync(payload)
    } catch (error: Exception) {
        // Provider errors affect calendar status only, never accepted widgets or
        // the independent nightly refresh status and alarm configuration.
        onFailure(error)
    }
}
