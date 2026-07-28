package com.traffic.app

import android.content.Context
import android.graphics.Color
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.os.Bundle
import android.text.InputType
import android.view.Gravity
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.*
import androidx.fragment.app.Fragment

class ConnectionFragment : Fragment() {

    private val prefs get() = requireContext().getSharedPreferences("traffic_prefs", Context.MODE_PRIVATE)

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
            text = "Подключение"; textSize = 22f; typeface = Typeface.DEFAULT_BOLD
            setTextColor(Color.parseColor(t.textPrimary))
            layoutParams = LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f).apply {
                marginStart = (8 * dp).toInt()
            }
        })
        layout.addView(header)

        val serverCard = LinearLayout(ctx).apply {
            orientation = LinearLayout.VERTICAL
            setPadding((16 * dp).toInt(), (16 * dp).toInt(), (16 * dp).toInt(), (16 * dp).toInt())
            background = cardDrawable(t, 16f, dp)
            layoutParams = LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT)
        }

        serverCard.addView(TextView(ctx).apply {
            text = "АДРЕС СЕРВЕРА"; textSize = 10f; letterSpacing = 0.1f; typeface = Typeface.DEFAULT_BOLD
            setTextColor(Color.parseColor(t.textSecondary))
        })

        val urlInput = EditText(ctx).apply {
            inputType = InputType.TYPE_CLASS_TEXT or InputType.TYPE_TEXT_VARIATION_URI
            setText(prefs.getString("server_url", "http://eos-traffic.ddns.net:5000"))
            setTextColor(Color.parseColor(t.textPrimary))
            setHintTextColor(hexAlpha(t.textSecondary, 90))
            background = GradientDrawable().apply {
                shape = GradientDrawable.RECTANGLE; cornerRadius = 10f * dp
                setColor(hexAlpha(t.bg, 200))
                setStroke(1, Color.parseColor(t.cardBorder))
            }
            setPadding((12 * dp).toInt(), (10 * dp).toInt(), (12 * dp).toInt(), (10 * dp).toInt())
            textSize = 14f
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT
            ).also { it.topMargin = (8 * dp).toInt() }
        }
        serverCard.addView(urlInput)

        serverCard.addView(TextView(ctx).apply {
            text = "WiFi: http://192.168.0.15:5000\nИнтернет: http://eos-traffic.ddns.net:5000"
            textSize = 11f; setTextColor(Color.parseColor(t.textSecondary))
            setPadding(0, (6 * dp).toInt(), 0, (12 * dp).toInt())
        })

        serverCard.addView(Button(ctx).apply {
            text = "Сохранить"; textSize = 15f; isAllCaps = false; typeface = Typeface.DEFAULT_BOLD
            setTextColor(Color.parseColor(t.bg))
            background = GradientDrawable().apply {
                shape = GradientDrawable.RECTANGLE; cornerRadius = 10f * dp
                setColor(Color.parseColor(t.accent))
            }
            layoutParams = LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, (48 * dp).toInt())
            setOnClickListener {
                prefs.edit().putString("server_url", urlInput.text.toString().trimEnd('/')).apply()
                text = "✓ Сохранено"
                postDelayed({ text = "Сохранить" }, 1500)
            }
        })

        layout.addView(serverCard)
        return scroll
    }
}
