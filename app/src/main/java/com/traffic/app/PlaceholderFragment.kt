package com.traffic.app

import android.graphics.Color
import android.graphics.Typeface
import android.os.Bundle
import android.view.Gravity
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.LinearLayout
import android.widget.TextView
import androidx.fragment.app.Fragment

class PlaceholderFragment : Fragment() {

    companion object {
        fun new(icon: String, name: String) = PlaceholderFragment().apply {
            arguments = Bundle().apply {
                putString("icon", icon)
                putString("name", name)
            }
        }
    }

    override fun onCreateView(inflater: LayoutInflater, container: ViewGroup?, savedInstanceState: Bundle?): View {
        val icon = arguments?.getString("icon") ?: "📦"
        val name = arguments?.getString("name") ?: "Раздел"

        val t = AppTheme.current
        val layout = LinearLayout(requireContext()).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            background = bgDrawable(t)
            layoutParams = ViewGroup.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT
            )
        }

        layout.addView(TextView(requireContext()).apply {
            text = icon
            textSize = 72f
            gravity = Gravity.CENTER
        })

        layout.addView(TextView(requireContext()).apply {
            text = name
            textSize = 28f
            typeface = Typeface.DEFAULT_BOLD
            setTextColor(Color.parseColor(t.textPrimary))
            gravity = Gravity.CENTER
            setPadding(0, 24, 0, 12)
        })

        layout.addView(TextView(requireContext()).apply {
            text = "EOS · в разработке"
            textSize = 13f
            letterSpacing = 0.1f
            setTextColor(Color.parseColor(t.textSecondary))
            gravity = Gravity.CENTER
        })

        return layout
    }
}
