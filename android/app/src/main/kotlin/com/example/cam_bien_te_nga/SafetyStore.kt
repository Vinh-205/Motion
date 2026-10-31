package com.example.cam_bien_te_nga

import android.content.Context
import org.json.JSONArray
import org.json.JSONObject
import java.util.UUID

object SafetyStore {
    fun prefs(context: Context) = context.getSharedPreferences("motion_safety", Context.MODE_PRIVATE)
    fun validPhone(value: String) = Regex("^\\+?[0-9]{9,15}$").matches(value)
    fun normalize(value: String) = value.replace(Regex("[\\s().-]"), "")
    @Synchronized fun contacts(context: Context): List<Map<String, String>> {
        val p = prefs(context)
        if (p.contains("contacts")) {
            val array = try { JSONArray(p.getString("contacts", "[]")) } catch (_: Exception) { JSONArray() }
            return (0 until array.length()).map { i ->
                val c = array.getJSONObject(i)
                mapOf("id" to c.getString("id"), "name" to c.getString("name"), "phone" to c.getString("phone"))
            }
        }
        val phone = p.getString("contactPhone", "") ?: ""
        return if (validPhone(phone)) listOf(mapOf("id" to UUID.nameUUIDFromBytes(phone.toByteArray()).toString(), "name" to (p.getString("contactName", "") ?: ""), "phone" to phone)) else emptyList()
    }
    fun phoneKey(phone: String): String = normalize(phone).let { if (it.startsWith("+84")) "0" + it.drop(3) else it }
    fun eventRecipients(context: Context): List<Map<String, Any?>> {
        val array = try { JSONArray(prefs(context).getString("eventRecipients", "[]")) } catch (_: Exception) { JSONArray() }
        return (0 until array.length()).map { jsonMap(array.getJSONObject(it)) }
    }
    @Synchronized fun events(context: Context): List<Map<String, Any?>> {
        val array = try { JSONArray(prefs(context).getString("events", "[]")) } catch (_: Exception) { JSONArray() }
        return (0 until array.length()).map { jsonMap(array.getJSONObject(it)) }
    }
    private fun jsonValue(value: Any?): Any? = when(value) {
        null, JSONObject.NULL -> null
        is JSONObject -> jsonMap(value)
        is JSONArray -> (0 until value.length()).map { jsonValue(value.get(it)) }
        else -> value
    }
    private fun jsonMap(value: JSONObject): Map<String, Any?> = value.keys().asSequence().associateWith { key -> jsonValue(value.get(key)) }
    @Synchronized fun record(context: Context, event: Map<String, Any?>) {
        val p = prefs(context)
        val previous = events(context).filter { it["id"] != event["id"] }
        val metadata = if (event["id"] == p.getString("currentId", "")) {
            try { jsonMap(JSONObject(p.getString("eventMetadata", "{}") ?: "{}")) } catch (_: Exception) { emptyMap() }
        } else emptyMap()
        val entries = (listOf(metadata + event) + previous).take(200)
        val editor = p.edit().putString("events", JSONArray(entries.map { JSONObject(it) }).toString())
        for (expired in previous.drop(199)) {
            val id = expired["id"] as? String ?: continue
            editor.remove("callClaimed.$id")
            for (key in p.all.keys) if (key == "claimed.$id" || key.startsWith("claimed.$id:") || key.startsWith("sent.$id.") || key.startsWith("delivered.$id.") || key.startsWith("sent.$id:") || key.startsWith("delivered.$id:")) editor.remove(key)
        }
        editor.apply()
    }
    @Synchronized fun updateSms(context: Context, id: String, status: String, detail: String) {
        val p = prefs(context)
        var changed: Map<String, Any?>? = null
        val events = events(context).map { event ->
            @Suppress("UNCHECKED_CAST") val recipients = event["recipients"] as? List<Map<String, Any?>> ?: emptyList()
            val parent = event["id"] == id
            if (!parent && recipients.none { it["id"] == id }) event else {
                val updated = if (recipients.isEmpty()) event + mapOf("smsStatus" to status, "detail" to detail) else {
                    val next = recipients.map { recipient ->
                        if (recipient["id"] == id || (parent && recipient["smsStatus"] in listOf("pending", "preparing", "sending", ""))) recipient + mapOf("smsStatus" to status, "detail" to detail) else recipient
                    }
                    val states = next.map { it["smsStatus"] as? String ?: "pending" }
                    event + mapOf("recipients" to next, "smsStatus" to SmsBatchSummary.status(states), "detail" to SmsBatchSummary.detail(states))
                }
                changed = updated
                updated
            }
        }
        val editor = p.edit().putString("events", JSONArray(events.map { JSONObject(it) }).toString())
        changed?.let { event -> if (p.getString("currentId", "") == event["id"]) editor.putString("smsStatus", event["smsStatus"] as String).putString("sosMessage", event["detail"] as String) }
        editor.apply()
    }
    fun dispatchState(context: Context, id: String): Map<String, Any?>? {
        for (event in events(context)) {
            if (event["id"] == id) return event
            @Suppress("UNCHECKED_CAST") val recipients = event["recipients"] as? List<Map<String, Any?>> ?: emptyList()
            recipients.find { it["id"] == id }?.let { return it }
        }
        return null
    }
    @Synchronized fun updateCall(context: Context, id: String, status: String, detail: String) {
        val p = prefs(context)
        val next = events(context).map { if (it["id"] == id) it + mapOf("callStatus" to status, "callDetail" to detail) else it }
        val editor = p.edit().putString("events", JSONArray(next.map { JSONObject(it) }).toString())
        if (p.getString("currentId", "") == id) editor.putString("callStatus", status).putString("callDetail", detail)
        editor.apply()
    }
    fun snapshot(context: Context): Map<String, Any?> {
        val p = prefs(context)
        val deadline = p.getLong("deadline", 0)
        return mapOf(
            "running" to (SafetyService.instance?.running == true), "enabled" to p.getBoolean("enabled", false),
            "monitoring" to p.getBoolean("monitoring", true), "countdownSeconds" to p.getInt("countdownSeconds", 30),
            "backgroundEnabled" to p.getBoolean("backgroundEnabled", true),
            "sensorCollectionActive" to (SafetyService.instance?.let { it.running && it.shouldCollectSensors() } == true),
            "appVisible" to SafetyService.appVisible,
            "detectionDetail" to (SafetyService.instance?.detector?.diagnostic ?: "Chưa bắt đầu phát hiện tự động."),
            "lastDetectionRejection" to (SafetyService.instance?.detector?.lastRejection ?: ""),
            "sensitivity" to p.getString("sensitivity", "medium"), "ownerName" to p.getString("ownerName", ""),
            "contactName" to p.getString("contactName", ""), "contactPhone" to p.getString("contactPhone", ""),
            "contacts" to contacts(context),
            "autoCallEnabled" to p.getBoolean("autoCallEnabled", false),
            "shakeSosEnabled" to p.getBoolean("shakeSosEnabled", false),
            "callPermission" to (context.checkSelfPermission(android.Manifest.permission.CALL_PHONE) == android.content.pm.PackageManager.PERMISSION_GRANTED),
            "callStatus" to p.getString("callStatus", ""), "callDetail" to p.getString("callDetail", ""),
            "pending" to (deadline > 0), "deadline" to deadline, "eventAt" to p.getLong("eventAt", 0),
            "remainingMilliseconds" to (SafetyService.instance?.remainingMilliseconds() ?: (deadline - System.currentTimeMillis()).coerceAtLeast(0)),
            "source" to p.getString("source", "sensor"), "currentId" to p.getString("currentId", ""),
            "sosActive" to p.getBoolean("sosActive", false), "smsStatus" to p.getString("smsStatus", ""),
            "sosMessage" to p.getString("sosMessage", ""), "events" to events(context),
            "sensorError" to (SafetyService.instance?.sensorError ?: ""),
            "sensorReady" to (SafetyService.instance?.sensorsReady() == true),
            "detectorState" to (SafetyService.instance?.detector?.state ?: 0),
            "locationAvailable" to (SafetyService.instance?.lastLocation != null),
            "dryRun" to (SafetyService.instance?.dryRun == true),
            "startupError" to p.getString("startupError", ""),
        )
    }
}
