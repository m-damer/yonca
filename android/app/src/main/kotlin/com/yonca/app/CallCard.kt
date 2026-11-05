package com.yonca.app

import android.content.Context
import android.content.res.Configuration
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.text.TextUtils
import android.view.Gravity
import android.view.View
import android.view.ViewGroup
import android.view.WindowManager
import android.widget.FrameLayout
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.TextView
import androidx.core.content.ContextCompat
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import java.io.File
import java.text.NumberFormat
import java.util.Locale
import kotlin.concurrent.thread

/** The contact card drawn over the incoming-call screen (option B of the design): who, last action, open deal. */
object CallCard {
    private val main = Handler(Looper.getMainLooper())
    private var view: View? = null
    private var manager: WindowManager? = null

    private fun prefs(c: Context) = c.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)

    fun enabled(c: Context) = prefs(c).getBoolean("cc_enabled", false)

    fun canDraw(c: Context) = Settings.canDrawOverlays(c)

    /** Looks the number up and, for a saved contact, shows the card. [done] runs when the work is over. */
    fun showFor(c: Context, number: String, done: () -> Unit) {
        if (!enabled(c) || !canDraw(c)) {
            done()
            return
        }
        thread {
            val data = try {
                CallCardData.find(c, number)
            } catch (e: Exception) {
                null
            }
            main.post {
                try {
                    if (data != null) show(c, data)
                } finally {
                    done()
                }
            }
        }
    }

    /** Settings → Preview: shows the card for a contact that has something to show. Returns false when there is none. */
    fun preview(c: Context): Boolean {
        if (!canDraw(c)) return false
        val data = CallCardData.any(c) ?: return false
        show(c, data)
        main.removeCallbacksAndMessages(null)
        main.postDelayed({ removeNow() }, 9000)
        return true
    }

    /** Removes the card now when called on the main thread, otherwise as soon as the main thread is free. */
    fun hide() {
        if (Looper.myLooper() == Looper.getMainLooper()) removeNow() else main.post { removeNow() }
    }

    private fun removeNow() {
        val v = view ?: return
        view = null
        try {
            manager?.removeView(v)
        } catch (e: Exception) {
            // Already gone.
        }
    }

    private fun show(c: Context, d: CardData) {
        removeNow()
        val rtl = prefs(c).getBoolean("cc_rtl", false)
        val lang = prefs(c).getString("cc_lang", "en") ?: "en"
        val conf = Configuration(c.resources.configuration)
        conf.setLocale(Locale(lang))
        val ctx = c.createConfigurationContext(conf)
        val wm = ctx.getSystemService(Context.WINDOW_SERVICE) as WindowManager
        val root = FrameLayout(ctx)
        root.layoutDirection = if (rtl) View.LAYOUT_DIRECTION_RTL else View.LAYOUT_DIRECTION_LTR
        root.setPadding(dp(ctx, 16), 0, dp(ctx, 16), 0)
        root.addView(card(ctx, d, rtl), FrameLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT))
        val type = WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
        val lp = WindowManager.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT, type,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED,
            android.graphics.PixelFormat.TRANSLUCENT
        )
        lp.gravity = Gravity.TOP
        lp.y = (ctx.resources.displayMetrics.heightPixels * 0.14).toInt()
        try {
            wm.addView(root, lp)
            view = root
            manager = wm
        } catch (e: Exception) {
            // The phone refused the overlay (permission taken away since the check).
        }
    }

    private fun dp(c: Context, v: Int) = (v * c.resources.displayMetrics.density).toInt()

    private fun str(c: Context, key: String, fallback: String = "") = prefs(c).getString(key, fallback) ?: fallback

    private fun face(c: Context, rtl: Boolean, bold: Boolean): Typeface {
        val file = if (rtl) (if (bold) "IBMPlexSansArabic_500Medium" else "IBMPlexSansArabic_400Regular") else (if (bold) "Inter_600SemiBold" else "Inter_400Regular")
        return try {
            Typeface.createFromAsset(c.assets, "flutter_assets/assets/fonts/$file.ttf")
        } catch (e: Exception) {
            Typeface.create(Typeface.DEFAULT, if (bold) Typeface.BOLD else Typeface.NORMAL)
        }
    }

    private fun text(c: Context, rtl: Boolean, value: String, sp: Float, color: Int, bold: Boolean = false, lines: Int = 0): TextView {
        val t = TextView(c)
        t.text = value
        t.textSize = sp
        t.setTextColor(color)
        t.typeface = face(c, rtl, bold)
        t.includeFontPadding = false
        t.setLineSpacing(0f, 1.25f)
        t.textAlignment = View.TEXT_ALIGNMENT_VIEW_START
        if (lines > 0) {
            t.maxLines = lines
            t.ellipsize = TextUtils.TruncateAt.END
        }
        return t
    }

    private fun box(c: Context, color: Int, radiusDp: Int): GradientDrawable {
        val g = GradientDrawable()
        g.setColor(color)
        g.cornerRadius = dp(c, radiusDp).toFloat()
        return g
    }

    private fun chip(c: Context, rtl: Boolean, label: String, bg: Int, fg: Int): TextView {
        val t = text(c, rtl, label, 12f, fg, bold = true, lines = 1)
        t.background = box(c, bg, 99)
        t.setPadding(dp(c, 10), dp(c, 5), dp(c, 10), dp(c, 5))
        return t
    }

    private fun gap(c: Context, h: Int) = View(c).apply { layoutParams = LinearLayout.LayoutParams(1, dp(c, h)) }

    private fun card(c: Context, d: CardData, rtl: Boolean): View {
        val ink = ContextCompat.getColor(c, R.color.call_card_ink)
        val ink2 = ContextCompat.getColor(c, R.color.call_card_ink2)
        val primary = ContextCompat.getColor(c, R.color.call_card_primary)
        val block = ContextCompat.getColor(c, R.color.call_card_block)
        val col = LinearLayout(c)
        col.orientation = LinearLayout.VERTICAL
        col.background = box(c, ContextCompat.getColor(c, R.color.call_card_bg), 24)
        col.elevation = dp(c, 12).toFloat()
        col.setPadding(dp(c, 18), dp(c, 18), dp(c, 18), dp(c, 18))

        // Header: avatar, name / nickname / company, logo.
        val head = LinearLayout(c)
        head.orientation = LinearLayout.HORIZONTAL
        head.gravity = Gravity.CENTER_VERTICAL
        head.addView(avatar(c, d, rtl))
        val names = LinearLayout(c)
        names.orientation = LinearLayout.VERTICAL
        names.addView(text(c, rtl, d.name, 18f, ink, bold = true, lines = 1))
        if (d.nickname.isNotBlank()) names.addView(text(c, rtl, "“${d.nickname}”", 14f, ink2, lines = 1))
        if (d.company.isNotBlank()) names.addView(text(c, rtl, d.company, 14f, ink2, lines = 1))
        val nlp = LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f)
        nlp.marginStart = dp(c, 12)
        nlp.marginEnd = dp(c, 12)
        head.addView(names, nlp)
        head.addView(logo(c, 24))
        col.addView(head)

        d.lastAction?.let { a ->
            col.addView(gap(c, 14))
            col.addView(lastActionBlock(c, a, rtl, ink, ink2, primary, block))
        }
        d.deal?.let { deal ->
            col.addView(gap(c, 14))
            col.addView(dealBlock(c, deal, d.moreDeals, rtl, ink, ink2, primary, block))
        }

        col.setOnClickListener {
            hide()
            val uri = Uri.parse("yonca://contact/${d.contactId}")
            try {
                HomeWidgetLaunchIntent.getActivity(c, MainActivity::class.java, uri).send()
            } catch (e: Exception) {
                // The phone would not start the app from here.
            }
        }
        return col
    }

    private fun avatar(c: Context, d: CardData, rtl: Boolean): View {
        val size = dp(c, 52)
        val photo: Bitmap? = d.photoPath?.let { p ->
            val f = File(p)
            if (f.exists()) {
                try {
                    val o = BitmapFactory.Options().apply { inSampleSize = 4 }
                    BitmapFactory.decodeFile(p, o)
                } catch (e: Exception) {
                    null
                }
            } else {
                null
            }
        }
        if (photo != null) {
            val iv = ImageView(c)
            iv.setImageBitmap(photo)
            iv.scaleType = ImageView.ScaleType.CENTER_CROP
            iv.clipToOutline = true
            iv.outlineProvider = object : android.view.ViewOutlineProvider() {
                override fun getOutline(v: View, outline: android.graphics.Outline) = outline.setOval(0, 0, v.width, v.height)
            }
            iv.layoutParams = LinearLayout.LayoutParams(size, size)
            return iv
        }
        val initials = d.name.split(" ").filter { it.isNotBlank() }.take(2).joinToString("") { it.first().uppercase() }
        val t = text(c, rtl, initials, 18f, ContextCompat.getColor(c, R.color.call_card_avatar_ink), bold = true)
        t.gravity = Gravity.CENTER
        val g = GradientDrawable()
        g.shape = GradientDrawable.OVAL
        g.setColor(ContextCompat.getColor(c, R.color.call_card_avatar))
        t.background = g
        t.layoutParams = LinearLayout.LayoutParams(size, size)
        return t
    }

    /** The four-leaf YONCA mark, drawn from four rounded tiles (the same shapes as the app's logo). */
    private fun logo(c: Context, sizeDp: Int): View {
        val tile = dp(c, (sizeDp - 2) / 2)
        val r = tile * 0.42f
        fun leaf(color: Int, a: Boolean): View {
            val g = GradientDrawable()
            g.setColor(color)
            g.cornerRadii = if (a) floatArrayOf(0f, 0f, r, r, 0f, 0f, r, r) else floatArrayOf(r, r, 0f, 0f, r, r, 0f, 0f)
            return View(c).apply { background = g; layoutParams = LinearLayout.LayoutParams(tile, tile) }
        }
        fun row(x: View, y: View) = LinearLayout(c).apply {
            orientation = LinearLayout.HORIZONTAL
            addView(x)
            addView(gap2(c))
            addView(y)
        }
        val col = LinearLayout(c)
        col.orientation = LinearLayout.VERTICAL
        col.layoutDirection = View.LAYOUT_DIRECTION_LTR
        col.addView(row(leaf(ContextCompat.getColor(c, R.color.call_logo_1), true), leaf(ContextCompat.getColor(c, R.color.call_logo_2), false)))
        col.addView(View(c).apply { layoutParams = LinearLayout.LayoutParams(1, dp(c, 2)) })
        col.addView(row(leaf(ContextCompat.getColor(c, R.color.call_logo_3), false), leaf(ContextCompat.getColor(c, R.color.call_logo_4), true)))
        return col
    }

    private fun gap2(c: Context) = View(c).apply { layoutParams = LinearLayout.LayoutParams(dp(c, 2), 1) }

    private fun blockBox(c: Context, color: Int): LinearLayout {
        val b = LinearLayout(c)
        b.orientation = LinearLayout.VERTICAL
        b.background = box(c, color, 14)
        b.setPadding(dp(c, 12), dp(c, 12), dp(c, 12), dp(c, 12))
        return b
    }

    private fun label(c: Context, rtl: Boolean, value: String, ink2: Int) = text(c, rtl, value.uppercase(Locale.getDefault()), 12f, ink2, lines = 1)

    private fun lastActionBlock(c: Context, a: LastAction, rtl: Boolean, ink: Int, ink2: Int, primary: Int, block: Int): View {
        val b = blockBox(c, block)
        b.addView(label(c, rtl, str(c, "cc_last_action", "Last action"), ink2))
        b.addView(gap(c, 6))
        val row = LinearLayout(c)
        row.orientation = LinearLayout.HORIZONTAL
        row.gravity = Gravity.CENTER_VERTICAL
        val type = str(c, "cc_t_${a.type}", a.type)
        val head = "$type · ${ago(c, a.at)}"
        row.addView(text(c, rtl, head, 15f, ink, bold = true, lines = 1), LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f))
        val outcome = if (a.outcomeKey != null) str(c, "cc_o_${a.outcomeKey}", a.outcomeName) else a.outcomeName
        if (outcome.isNotBlank()) {
            val good = a.outcomeKey == "interested"
            row.addView(
                chip(
                    c, rtl, outcome,
                    ContextCompat.getColor(c, if (good) R.color.call_card_good_bg else R.color.call_card_bg),
                    ContextCompat.getColor(c, if (good) R.color.call_card_good_ink else R.color.call_card_ink)
                )
            )
        }
        b.addView(row)
        val body = listOf(a.title, a.text).filter { it.isNotBlank() }.joinToString(" — ")
        if (body.isNotBlank()) {
            b.addView(gap(c, 6))
            b.addView(text(c, rtl, body, 14f, ink2, lines = 3))
        }
        return b
    }

    private fun dealBlock(c: Context, deal: DealInfo, more: Int, rtl: Boolean, ink: Int, ink2: Int, primary: Int, block: Int): View {
        val b = blockBox(c, block)
        val head = LinearLayout(c)
        head.orientation = LinearLayout.HORIZONTAL
        head.gravity = Gravity.CENTER_VERTICAL
        head.addView(label(c, rtl, str(c, "cc_open_deal", "Open deal"), ink2), LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f))
        val stage = if (deal.stageKey != null) str(c, "cc_st_${deal.stageKey}", deal.stageName) else deal.stageName
        if (stage.isNotBlank()) head.addView(chip(c, rtl, stage, ContextCompat.getColor(c, R.color.call_card_stage_bg), ink))
        b.addView(head)
        b.addView(gap(c, 6))
        val row = LinearLayout(c)
        row.orientation = LinearLayout.HORIZONTAL
        row.gravity = Gravity.CENTER_VERTICAL
        row.addView(text(c, rtl, deal.title, 16f, ink, bold = true, lines = 2), LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f))
        if (deal.amount != null && deal.amount > 0) {
            val amountView = text(c, rtl, money(deal.amount, deal.currency), 18f, primary, bold = true, lines = 1)
            amountView.layoutDirection = View.LAYOUT_DIRECTION_LTR
            row.addView(amountView)
        }
        b.addView(row)
        if (deal.description.isNotBlank()) {
            b.addView(gap(c, 6))
            b.addView(text(c, rtl, deal.description, 14f, ink2, lines = 3))
        }
        if (more > 0) {
            b.addView(gap(c, 8))
            b.addView(text(c, rtl, str(c, "cc_more_deals", "+{n} more").replace("{n}", more.toString()), 13f, primary, bold = true, lines = 1))
        }
        return b
    }

    private fun money(v: Double, currency: String): String {
        val n = NumberFormat.getNumberInstance(Locale.US)
        n.maximumFractionDigits = if (v % 1.0 == 0.0) 0 else 2
        val s = n.format(v)
        return if (currency == "USD") "$$s" else "$currency $s"
    }

    private fun ago(c: Context, at: Long): String {
        val days = ((System.currentTimeMillis() - at) / 86_400_000L).toInt().coerceAtLeast(0)
        return when {
            days < 1 -> str(c, "cc_ago_today", "today")
            days < 2 -> str(c, "cc_ago_yesterday", "yesterday")
            days < 14 -> str(c, "cc_ago_d_$days", "$days d")
            days < 60 -> str(c, "cc_ago_w_${days / 7}", "${days / 7} w")
            days < 730 -> str(c, "cc_ago_m_${days / 30}", "${days / 30} m")
            else -> str(c, "cc_ago_y_${minOf(days / 365, 60)}", "${days / 365} y")
        }
    }
}
