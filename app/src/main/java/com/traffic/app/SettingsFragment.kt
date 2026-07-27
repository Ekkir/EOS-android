package com.traffic.app

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

class SettingsFragment : Fragment() {

    override fun onCreateView(inflater: LayoutInflater, container: ViewGroup?, savedInstanceState: Bundle?): View {
        val ctx = requireContext()
        val t   = AppTheme.current
        val dp  = ctx.resources.displayMetrics.density

        val scroll = ScrollView(ctx).apply { background = bgDrawable(t) }
        val layout = LinearLayout(ctx).apply {
            orientation = LinearLayout.VERTICAL
            setPadding((20 * dp).toInt(), (16 * dp).toInt(), (20 * dp).toInt(), (32 * dp).toInt())
        }
        scroll.addView(layout)

        layout.addView(TextView(ctx).apply {
            text = "Настройки"; textSize = 26f; typeface = Typeface.DEFAULT_BOLD
            setTextColor(Color.parseColor(t.textPrimary))
            setPadding(0, 0, 0, (24 * dp).toInt())
        })

        layout.addView(buildItem("🎨", "Темы", "Оформление приложения", dp, t) {
            openFragment(CalibrationFragment.newTabbed(1), "calib_theme")
        })
        layout.addView(spacer(ctx, dp, 12f))
        layout.addView(buildItem("🚦", "Светофоры", "Тайминги и порядок фаз", dp, t) {
            openFragment(CalibrationFragment.newTabbed(0), "calib_traffic")
        })
        layout.addView(spacer(ctx, dp, 12f))
        layout.addView(buildItem("ℹ️", "О приложении", "Версия, обновления", dp, t) {
            openFragment(AboutFragment(), "about_settings")
        })

        return scroll
    }

    private fun openFragment(fragment: Fragment, tag: String) {
        if (parentFragmentManager.findFragmentByTag(tag) != null) return
        (activity as? MainActivity)?.hideMainChrome()
        parentFragmentManager.beginTransaction()
            .add(R.id.fragmentContainer, fragment, tag)
            .addToBackStack(tag)
            .commit()
    }

    private fun buildItem(icon: String, title: String, subtitle: String, dp: Float, t: ThemeDef, onClick: () -> Unit): View {
        val ctx = requireContext()
        val row = LinearLayout(ctx).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            setPadding((18 * dp).toInt(), (18 * dp).toInt(), (18 * dp).toInt(), (18 * dp).toInt())
            background = cardDrawable(t, 20f, dp)
            isClickable = true; isFocusable = true
            foreground = RippleDrawable(ColorStateList.valueOf(0x22FFFFFF.toInt()), null, null)
            setOnClickListener { onClick() }
        }

        val iconSize = (52 * dp).toInt()
        val iconBox = FrameLayout(ctx).apply {
            layoutParams = LinearLayout.LayoutParams(iconSize, iconSize).apply { marginEnd = (16 * dp).toInt() }
            background = accentBox(t, dp, 12f)
        }
        iconBox.addView(TextView(ctx).apply {
            text = icon; textSize = 24f; gravity = Gravity.CENTER
            layoutParams = FrameLayout.LayoutParams(FrameLayout.LayoutParams.MATCH_PARENT, FrameLayout.LayoutParams.MATCH_PARENT)
        })
        row.addView(iconBox)

        val texts = LinearLayout(ctx).apply {
            orientation = LinearLayout.VERTICAL
            layoutParams = LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f)
        }
        texts.addView(TextView(ctx).apply {
            text = title; textSize = 17f; typeface = Typeface.DEFAULT_BOLD
            setTextColor(Color.parseColor(t.textPrimary))
        })
        texts.addView(TextView(ctx).apply {
            text = subtitle; textSize = 13f
            setTextColor(Color.parseColor(t.textSecondary))
            setPadding(0, (3 * dp).toInt(), 0, 0)
        })
        row.addView(texts)

        row.addView(TextView(ctx).apply {
            text = "›"; textSize = 26f
            setTextColor(hexAlpha(t.textSecondary, 120))
            gravity = Gravity.CENTER
            layoutParams = LinearLayout.LayoutParams((28 * dp).toInt(), LinearLayout.LayoutParams.WRAP_CONTENT)
        })

        return row
    }

    private fun spacer(ctx: android.content.Context, dp: Float, h: Float) = View(ctx).apply {
        layoutParams = LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, (h * dp).toInt())
    }
}
