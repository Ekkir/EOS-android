package com.traffic.app

import android.content.Context
import android.graphics.*
import android.graphics.drawable.GradientDrawable
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.view.Gravity
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.view.ViewOutlineProvider
import android.widget.*
import androidx.fragment.app.Fragment
import java.io.Serializable

class UserProfileFragment : Fragment() {

    companion object {
        private const val ARG_NAME       = "name"
        private const val ARG_CHANNEL_ID = "fromChannel"

        fun newInstance(name: String, avatarBitmap: Bitmap?, fromChannelId: String): UserProfileFragment {
            return UserProfileFragment().apply {
                cachedAvatar = avatarBitmap
                arguments = Bundle().apply {
                    putString(ARG_NAME,       name)
                    putString(ARG_CHANNEL_ID, fromChannelId)
                }
            }
        }
    }

    var cachedAvatar: Bitmap? = null

    private val senderName   get() = arguments?.getString(ARG_NAME,       "") ?: ""
    private val fromChannel  get() = arguments?.getString(ARG_CHANNEL_ID, "general") ?: "general"

    private val prefs get() = requireContext().getSharedPreferences("traffic_prefs", Context.MODE_PRIVATE)
    private val myName get() = prefs.getString("profile_name", "")?.takeIf { it.isNotBlank() }
        ?: "${android.os.Build.MANUFACTURER} ${android.os.Build.MODEL}"

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

        // ── Шапка ──────────────────────────────────────────────────
        val header = LinearLayout(ctx).apply {
            orientation = LinearLayout.HORIZONTAL; gravity = Gravity.CENTER_VERTICAL
            setPadding(0, 0, 0, (24 * dp).toInt())
        }
        header.addView(TextView(ctx).apply {
            text = "←"; textSize = 22f; gravity = Gravity.CENTER
            setTextColor(Color.parseColor(t.textPrimary))
            layoutParams = LinearLayout.LayoutParams((44 * dp).toInt(), (44 * dp).toInt())
            setOnClickListener { requireActivity().onBackPressed() }
        })
        header.addView(TextView(ctx).apply {
            text = "Профиль"; textSize = 22f; typeface = Typeface.DEFAULT_BOLD
            setTextColor(Color.parseColor(t.textPrimary))
            layoutParams = LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f).apply { marginStart = (8 * dp).toInt() }
        })
        layout.addView(header)

        // ── Аватар и имя ───────────────────────────────────────────
        val avaSize = (96 * dp).toInt()
        val avatarView = buildAvatarView(ctx, t, dp, avaSize)
        val avatarWrapper = FrameLayout(ctx).apply {
            layoutParams = LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT).apply {
                bottomMargin = (16 * dp).toInt()
            }
            addView(avatarView, FrameLayout.LayoutParams(avaSize, avaSize, Gravity.CENTER))
        }
        layout.addView(avatarWrapper)

        layout.addView(TextView(ctx).apply {
            text = senderName; textSize = 22f; typeface = Typeface.DEFAULT_BOLD
            setTextColor(Color.parseColor(t.textPrimary))
            gravity = Gravity.CENTER
            layoutParams = LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT).apply {
                bottomMargin = (24 * dp).toInt()
            }
        })

        // ── Кнопка "Написать" ──────────────────────────────────────
        if (senderName != myName) {
            layout.addView(Button(ctx).apply {
                text = "✉  Написать"; textSize = 16f; isAllCaps = false; typeface = Typeface.DEFAULT_BOLD
                setTextColor(Color.parseColor(t.bg))
                background = GradientDrawable().apply {
                    cornerRadius = 14 * dp
                    setColor(Color.parseColor(t.accent))
                }
                layoutParams = LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, (52 * dp).toInt())
                setOnClickListener { openDm() }
            })
        }

        return scroll
    }

    private fun buildAvatarView(ctx: Context, t: ThemeDef, dp: Float, size: Int): ImageView {
        val bmp = cachedAvatar?.let { circularBitmap(it, size) } ?: run {
            val b = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
            val c = Canvas(b)
            val p = Paint(Paint.ANTI_ALIAS_FLAG)
            val palette = listOf("#FF6B6B","#4ECDC4","#45B7D1","#96CEB4","#DDA0DD","#F7B731","#20BF6B")
            p.color = Color.parseColor(palette[Math.abs(senderName.hashCode()) % palette.size])
            c.drawCircle(size / 2f, size / 2f, size / 2f, p)
            p.color = Color.WHITE; p.textSize = size * 0.44f
            p.textAlign = Paint.Align.CENTER; p.typeface = Typeface.DEFAULT_BOLD
            val initial = senderName.firstOrNull()?.uppercaseChar()?.toString() ?: "?"
            c.drawText(initial, size / 2f, size / 2f + p.textSize / 3f, p)
            b
        }
        return ImageView(ctx).apply {
            setImageBitmap(bmp)
            scaleType  = ImageView.ScaleType.CENTER_CROP
            clipToOutline = true
            outlineProvider = object : ViewOutlineProvider() {
                override fun getOutline(v: View, o: Outline) { o.setOval(0, 0, v.width, v.height) }
            }
        }
    }

    private fun circularBitmap(src: Bitmap, size: Int): Bitmap {
        val out    = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(out)
        val paint  = Paint(Paint.ANTI_ALIAS_FLAG)
        val shader = BitmapShader(Bitmap.createScaledBitmap(src, size, size, true), Shader.TileMode.CLAMP, Shader.TileMode.CLAMP)
        paint.shader = shader
        canvas.drawCircle(size / 2f, size / 2f, size / 2f, paint)
        return out
    }

    private fun openDm() {
        val names    = listOf(myName, senderName).sorted()
        val dmId     = "dm_${names[0]}_${names[1]}"
        val tag      = "messenger_$dmId"
        if (parentFragmentManager.findFragmentByTag(tag) != null) {
            requireActivity().onBackPressed()
            return
        }
        val frag = MessengerFragment.newInstance(dmId, senderName)
        parentFragmentManager.beginTransaction()
            .replace(R.id.fragmentContainer, frag, tag)
            .addToBackStack(tag)
            .commit()
    }
}
