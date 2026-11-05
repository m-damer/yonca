package com.yonca.app

import android.content.Context
import android.database.sqlite.SQLiteDatabase
import java.io.File

/** What the incoming-call card shows about one contact. */
class CardData(
    val contactId: Long,
    val name: String,
    val nickname: String,
    val company: String,
    val photoPath: String?,
    val lastAction: LastAction?,
    val deal: DealInfo?,
    val moreDeals: Int,
)

class LastAction(val type: String, val direction: String, val at: Long, val title: String, val text: String, val outcomeKey: String?, val outcomeName: String)

class DealInfo(val title: String, val amount: Double?, val currency: String, val description: String, val stageKey: String?, val stageName: String)

/** Reads the app's own SQLite file, read-only, so the card works without starting the app. */
object CallCardData {
    private const val TAIL = 9

    private fun digits(s: String) = s.filter { it.isDigit() }

    /** Two numbers are the same phone when they end in the same nine digits (or are equal when shorter). */
    private fun same(a: String, b: String): Boolean {
        if (a.isEmpty() || b.isEmpty()) return false
        if (a.length >= TAIL && b.length >= TAIL) return a.takeLast(TAIL) == b.takeLast(TAIL)
        return a == b
    }

    private fun open(context: Context): SQLiteDatabase? {
        val file = File(context.getDir("flutter", Context.MODE_PRIVATE), "yonca.sqlite")
        if (!file.exists()) return null
        return try {
            SQLiteDatabase.openDatabase(file.path, null, SQLiteDatabase.OPEN_READONLY)
        } catch (e: Exception) {
            null
        }
    }

    fun find(context: Context, number: String): CardData? {
        val db = open(context) ?: return null
        try {
            val incoming = digits(number)
            if (incoming.isEmpty()) return null
            var id: Long? = null
            db.rawQuery("SELECT contact_id, normalized FROM contact_phones", null).use { c ->
                while (c.moveToNext()) {
                    if (same(incoming, c.getString(1))) {
                        id = c.getLong(0)
                        break
                    }
                }
            }
            return id?.let { load(db, it) }
        } catch (e: Exception) {
            return null
        } finally {
            db.close()
        }
    }

    /** The first contact in the book, for the Preview button in Settings. */
    fun any(context: Context): CardData? {
        val db = open(context) ?: return null
        try {
            var id: Long? = null
            db.rawQuery(
                "SELECT c.id FROM contacts c WHERE EXISTS (SELECT 1 FROM deals d WHERE d.contact_id = c.id) " +
                    "OR EXISTS (SELECT 1 FROM activities a WHERE a.contact_id = c.id) ORDER BY c.updated_at DESC LIMIT 1", null
            ).use { if (it.moveToFirst()) id = it.getLong(0) }
            if (id == null) db.rawQuery("SELECT id FROM contacts ORDER BY updated_at DESC LIMIT 1", null).use { if (it.moveToFirst()) id = it.getLong(0) }
            return id?.let { load(db, it) }
        } catch (e: Exception) {
            return null
        } finally {
            db.close()
        }
    }

    private fun load(db: SQLiteDatabase, id: Long): CardData? {
        var name = ""
        var nick = ""
        var company = ""
        var photo: String? = null
        db.rawQuery("SELECT first_name, middle_name, last_name, nickname, company, photo_path FROM contacts WHERE id = ?", arrayOf(id.toString())).use { c ->
            if (!c.moveToFirst()) return null
            name = listOf(c.getString(0), c.getString(1), c.getString(2)).filter { it.isNotBlank() }.joinToString(" ")
            nick = c.getString(3)
            company = c.getString(4)
            photo = if (c.isNull(5)) null else c.getString(5)
        }
        if (name.isBlank()) name = company
        var last: LastAction? = null
        db.rawQuery(
            "SELECT a.type, a.direction, a.occurred_at, a.title, a.description, o.key, o.name FROM activities a " +
                "LEFT JOIN outcomes o ON o.id = a.outcome_id WHERE a.contact_id = ? ORDER BY a.occurred_at DESC LIMIT 1",
            arrayOf(id.toString())
        ).use { c ->
            if (c.moveToFirst()) {
                last = LastAction(
                    c.getString(0), c.getString(1), c.getLong(2) * 1000, c.getString(3), c.getString(4),
                    if (c.isNull(5)) null else c.getString(5), if (c.isNull(6)) "" else c.getString(6)
                )
            }
        }
        var deal: DealInfo? = null
        var more = 0
        db.rawQuery(
            "SELECT d.title, d.amount, d.currency, d.description, s.key, s.name FROM deals d JOIN deal_stages s ON s.id = d.stage_id " +
                "WHERE d.contact_id = ? AND s.kind = 'open' ORDER BY d.stage_changed_at DESC",
            arrayOf(id.toString())
        ).use { c ->
            while (c.moveToNext()) {
                if (deal == null) {
                    deal = DealInfo(c.getString(0), if (c.isNull(1)) null else c.getDouble(1), c.getString(2), c.getString(3), if (c.isNull(4)) null else c.getString(4), c.getString(5))
                } else {
                    more++
                }
            }
        }
        return CardData(id, name, nick, company, photo, last, deal, more)
    }
}
