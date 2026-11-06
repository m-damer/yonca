package com.yonca.app

import android.content.Context
import org.json.JSONArray
import org.json.JSONObject

/**
 * Calls waiting to be logged in the app. The Android side cannot write to the app's database safely
 * while the app may be open, so it keeps each finished call here (with the outcome the person tapped, if any)
 * and the app picks them up the next time it opens.
 */
object CallLogStore {
    private fun prefs(c: Context) = c.getSharedPreferences("yonca_calls", Context.MODE_PRIVATE)

    @Synchronized
    private fun read(c: Context): JSONArray = try {
        JSONArray(prefs(c).getString("pending", "[]"))
    } catch (e: Exception) {
        JSONArray()
    }

    @Synchronized
    private fun write(c: Context, a: JSONArray) {
        prefs(c).edit().putString("pending", a.toString()).apply()
    }

    @Synchronized
    fun put(c: Context, e: JSONObject) {
        val a = read(c)
        val keep = JSONArray()
        for (i in 0 until a.length()) if (a.getJSONObject(i).getString("id") != e.getString("id")) keep.put(a.getJSONObject(i))
        keep.put(e)
        // Never let it grow without bound: keep the newest 50.
        val out = JSONArray()
        for (i in maxOf(0, keep.length() - 50) until keep.length()) out.put(keep.get(i))
        write(c, out)
    }

    @Synchronized
    fun get(c: Context, id: String): JSONObject? {
        val a = read(c)
        for (i in 0 until a.length()) if (a.getJSONObject(i).getString("id") == id) return a.getJSONObject(i)
        return null
    }

    @Synchronized
    fun setOutcome(c: Context, id: String, outcome: String) {
        val a = read(c)
        for (i in 0 until a.length()) {
            val o = a.getJSONObject(i)
            if (o.getString("id") == id) o.put("outcome", outcome)
        }
        write(c, a)
    }

    @Synchronized
    fun remove(c: Context, id: String) {
        val a = read(c)
        val out = JSONArray()
        for (i in 0 until a.length()) if (a.getJSONObject(i).getString("id") != id) out.put(a.get(i))
        write(c, out)
    }

    /** The calls of saved contacts whose outcome was chosen on the card or the notification; they leave the store. */
    @Synchronized
    fun takeLogged(c: Context): String {
        val a = read(c)
        val taken = JSONArray()
        val rest = JSONArray()
        for (i in 0 until a.length()) {
            val o = a.getJSONObject(i)
            if (o.optString("outcome").isNotEmpty() && o.optLong("contactId", -1) > 0) taken.put(o) else rest.put(o)
        }
        write(c, rest)
        return taken.toString()
    }
}
