package com.traffic.app

import android.content.Context
import android.graphics.Color
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.os.Bundle
import android.view.Gravity
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.*
import androidx.fragment.app.Fragment

class ThemesFragment : Fragment() {

    private val prefs get() = requireContext().getSharedPreferences("traffic_prefs", Context.MODE_PRIVATE)

    private val accentPresets = mapOf(
        "glassneon" to listOf("#CC00FF","#00FF7F","#00BFFF","#FF00AA","#FFD700","#FF4400"),
        "minimal"   to listOf("#DDDDDD","#AAAAAA","#88AACC","#CCAA77","#77AACC","#CC8888"),
    )

    override fun onCreateView(inflater: LayoutInflater, container: ViewGroup?, savedInstanceState: Bundle?): View {
        val ctx = requireContext()
        val t   = AppTheme.current
        val dp  = ctx.resources.displayMetrics.density

        val scroll = ScrollView(ctx).apply { background = bgDrawable(t) }
        val layout = LinearLayout(ctx).apply {
            orientation = LinearLayout.VERTICAL
            setPadding((20 * dp).toInt(), (12 * dp).toInt() + statusBarHeight(ctx), (20 * dp).toInt(), (32 * dp).toInt())
        }
        scroll.addView(layout)

        // Шапка
        val header = LinearLayout(ctx).apply {
            orientation = LinearLayout.HORIZONTAL; gravity = Gravity.CENTER_VERTICAL
            setPadding(0, 0, 0, (20 * dp).toInt())
        }
        header.addView(TextView(ctx).apply {
            text = "←"; textSize = 22f; gravity = Gravity.CENTER
            setTextColor(Color.parseColor(t.textPrimary))
            layoutParams = LinearLayout.LayoutParams((44 * dp).toInt(), (44 * dp).toInt())
            setOnClickListener { requireActivity().onBackPressed() }
        })
        header.addView(TextView(ctx).apply {
            text = "Темы"; textSize = 22f; typeface = Typeface.DEFAULT_BOLD
            setTextColor(Color.parseColor(t.textPrimary))
            layoutParams = LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f).apply {
                marginStart = (8 * dp).toInt()
            }
        })
        layout.addView(header)

        val currentId = prefs.getString("theme_id", "glassneon") ?: "glassneon"
        AppTheme.themes.forEach { theme ->
            val isSelected = theme.id == currentId

            val card = LinearLayout(ctx).apply {
                orientation = LinearLayout.HORIZONTAL
                gravity = Gravity.CENTER_VERTICAL
                setPadding((16 * dp).toInt(), (14 * dp).toInt(), (16 * dp).toInt(), (14 * dp).toInt())
                layoutParams = LinearLayout.LayoutParams(
                    LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT
                ).also { it.bottomMargin = (10 * dp).toInt() }
                background = if (isSelected) {
                    GradientDrawable().apply {
                        shape = GradientDrawable.RECTANGLE; cornerRadius = 16f * dp
                        setColor(hexAlpha(theme.accent, 24))
                        setStroke((2 * dp).toInt(), Color.parseColor(theme.accent))
                    }
                } else {
                    cardDrawable(theme, 16f, dp)
                }
                isClickable = true; isFocusable = true
            }

            card.addView(FrameLayout(ctx).apply {
                layoutParams = LinearLayout.LayoutParams((40 * dp).toInt(), (40 * dp).toInt()).also {
                    it.marginEnd = (14 * dp).toInt()
                }
                background = GradientDrawable().apply {
                    shape = GradientDrawable.OVAL; setColor(Color.parseColor(theme.accent))
                }
            })

            val texts = LinearLayout(ctx).apply {
                orientation = LinearLayout.VERTICAL
                layoutParams = LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f)
            }
            texts.addView(TextView(ctx).apply {
                text = theme.name; textSize = 16f; typeface = Typeface.DEFAULT_BOLD
                setTextColor(Color.parseColor(theme.textPrimary))
            })
            texts.addView(TextView(ctx).apply {
                text = theme.accent
                textSize = 11f; setTextColor(Color.parseColor(theme.textSecondary))
                setPadding(0, (2 * dp).toInt(), 0, 0)
            })
            card.addView(texts)

            card.addView(TextView(ctx).apply {
                text = if (isSelected) "✓" else ""
                textSize = 18f; typeface = Typeface.DEFAULT_BOLD
                setTextColor(Color.parseColor(theme.accent))
                gravity = Gravity.CENTER
                layoutParams = LinearLayout.LayoutParams((36 * dp).toInt(), LinearLayout.LayoutParams.WRAP_CONTENT)
            })

            card.setOnClickListener {
                AppTheme.apply(ctx, theme.id)
                requireActivity().recreate()
            }
            layout.addView(card)

            if (isSelected) {
                val presets = accentPresets[theme.id] ?: emptyList()
                val customAccent = prefs.getString("accent_${theme.id}", theme.accent) ?: theme.accent
                val swatchRow = LinearLayout(ctx).apply {
                    orientation = LinearLayout.HORIZONTAL
                    gravity = Gravity.CENTER_VERTICAL
                    setPadding((16 * dp).toInt(), (8 * dp).toInt(), (16 * dp).toInt(), (12 * dp).toInt())
                    layoutParams = LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT)
                }
                swatchRow.addView(TextView(ctx).apply {
                    text = "Акцент"; textSize = 12f
                    setTextColor(Color.parseColor(t.textSecondary))
                    layoutParams = LinearLayout.LayoutParams(LinearLayout.LayoutParams.WRAP_CONTENT, LinearLayout.LayoutParams.WRAP_CONTENT).apply {
                        marginEnd = (12 * dp).toInt()
                    }
                })
                presets.forEach { color ->
                    val active = color.equals(customAccent, ignoreCase = true)
                    val size = (32 * dp).toInt()
                    swatchRow.addView(View(ctx).apply {
                        layoutParams = LinearLayout.LayoutParams(size, size).apply { marginEnd = (8 * dp).toInt() }
                        background = GradientDrawable().apply {
                            shape = GradientDrawable.OVAL
                            setColor(Color.parseColor(color))
                            setStroke(if (active) (2 * dp).toInt() else 0, Color.WHITE)
                        }
                        isClickable = true; isFocusable = true
                        setOnClickListener {
                            prefs.edit().putString("accent_${theme.id}", color).apply()
                            AppTheme.apply(ctx, theme.id)
                            requireActivity().recreate()
                        }
                    })
                }
                layout.addView(swatchRow)
            }
        }

        return scroll
    }
}
