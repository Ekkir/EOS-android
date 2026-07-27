package com.traffic.app

import android.content.Context
import android.content.res.ColorStateList
import android.graphics.Color
import android.graphics.Typeface
import android.graphics.drawable.RippleDrawable
import android.os.Bundle
import android.view.Gravity
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.*
import androidx.fragment.app.Fragment

class HomeFragment : Fragment() {

    private val cards = listOf(
        Card("traffic",  "🚦", "Светофоры",  "Текущее состояние перекрёстка"),
        Card("map",      "🗺",  "Карта",       "GPS позиция и метки объектов"),
        Card("cameras",  "📷", "Камеры",      "Видеонаблюдение (в разработке)"),
        Card("calib",    "🔧", "Настройки",   "Тайминги и порядок светофоров"),
    )

    data class Card(val sectionId: String, val icon: String, val title: String, val subtitle: String)

    override fun onCreateView(inflater: LayoutInflater, container: ViewGroup?, savedInstanceState: Bundle?): View {
        val ctx = requireContext()
        val t   = AppTheme.current
        val dp  = ctx.resources.displayMetrics.density

        val scroll = ScrollView(ctx).apply { background = bgDrawable(t) }
        val layout = LinearLayout(ctx).apply {
            orientation = LinearLayout.VERTICAL
            setPadding((20 * dp).toInt(), (16 * dp).toInt(), (20 * dp).toInt(), (24 * dp).toInt())
        }
        scroll.addView(layout)

        val prefs     = ctx.getSharedPreferences("traffic_prefs", Context.MODE_PRIVATE)
        val name      = prefs.getString("profile_name", "")?.takeIf { it.isNotBlank() }
        val leftShift = (100 * dp).toInt()


        cards.forEach { card ->
            layout.addView(buildCard(card))
            layout.addView(Space(ctx).apply {
                layoutParams = LinearLayout.LayoutParams(
                    LinearLayout.LayoutParams.MATCH_PARENT, (12 * dp).toInt()
                )
            })
        }

        return scroll
    }

    private fun buildCard(card: Card): View {
        val ctx = requireContext()
        val t   = AppTheme.current
        val dp  = ctx.resources.displayMetrics.density

        val row = LinearLayout(ctx).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            setPadding((18 * dp).toInt(), (18 * dp).toInt(), (18 * dp).toInt(), (18 * dp).toInt())
            background = cardDrawable(t, 20f, dp)
            isClickable = true; isFocusable = true
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT,
            )
        }

        val iconSize = (48 * dp).toInt()
        val iconBox = FrameLayout(ctx).apply {
            layoutParams = LinearLayout.LayoutParams(iconSize, iconSize).also {
                it.marginEnd = (16 * dp).toInt()
            }
            background = accentBox(t, dp, 10f)
        }
        iconBox.addView(TextView(ctx).apply {
            text = card.icon; textSize = 22f; gravity = Gravity.CENTER
            layoutParams = FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT, FrameLayout.LayoutParams.MATCH_PARENT
            )
        })
        row.addView(iconBox)

        val textCol = LinearLayout(ctx).apply {
            orientation = LinearLayout.VERTICAL
            layoutParams = LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f)
        }
        textCol.addView(TextView(ctx).apply {
            text = card.title; textSize = 17f; typeface = Typeface.DEFAULT_BOLD
            setTextColor(Color.parseColor(t.textPrimary))
        })
        textCol.addView(TextView(ctx).apply {
            text = card.subtitle; textSize = 13f
            setTextColor(Color.parseColor(t.textSecondary))
            setPadding(0, (3 * dp).toInt(), 0, 0)
        })
        row.addView(textCol)

        row.addView(TextView(ctx).apply {
            text = "›"; textSize = 26f
            setTextColor(hexAlpha(t.textSecondary, 120))
            gravity = Gravity.CENTER
            layoutParams = LinearLayout.LayoutParams((28 * dp).toInt(), LinearLayout.LayoutParams.WRAP_CONTENT)
        })

        row.setOnClickListener {
            (requireActivity() as? SectionNavigator)?.showSection(card.sectionId)
        }
        row.foreground = RippleDrawable(ColorStateList.valueOf(0x22FFFFFF.toInt()), null, null)

        return row
    }
}
