package com.traffic.app

import android.content.Context
import android.graphics.Color
import android.graphics.Typeface
import android.graphics.drawable.ColorDrawable
import android.graphics.drawable.GradientDrawable
import android.net.Uri
import android.os.Bundle
import android.text.InputType
import android.view.Gravity
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.*
import androidx.activity.result.contract.ActivityResultContracts
import androidx.fragment.app.Fragment
import java.io.File

class ProfileFragment : Fragment() {

    private val prefs get() = requireContext().getSharedPreferences("traffic_prefs", Context.MODE_PRIVATE)

    private var avatarBig: ImageView? = null
    private var nameInput: EditText? = null
    private var descInput: EditText? = null

    private val pickImage = registerForActivityResult(ActivityResultContracts.GetContent()) { uri: Uri? ->
        uri ?: return@registerForActivityResult
        copyImageToInternal(uri)
        reloadAvatarBig()
        (activity as? MainActivity)?.reloadAvatar()
    }

    override fun onCreateView(inflater: LayoutInflater, container: ViewGroup?, savedInstanceState: Bundle?): View {
        val ctx = requireContext()
        val t   = AppTheme.current
        val dp  = ctx.resources.displayMetrics.density

        val scroll = ScrollView(ctx).apply { background = bgDrawable(t) }
        val layout = LinearLayout(ctx).apply {
            orientation = LinearLayout.VERTICAL
            setPadding((20 * dp).toInt(), (24 * dp).toInt() + statusBarHeight(ctx), (20 * dp).toInt(), (48 * dp).toInt())
        }
        scroll.addView(layout)

        // Заголовок + кнопка закрыть
        val headerRow = LinearLayout(ctx).apply {
            orientation = LinearLayout.HORIZONTAL; gravity = Gravity.CENTER_VERTICAL
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT
            )
        }
        headerRow.addView(TextView(ctx).apply {
            text = "Профиль"; textSize = 22f; typeface = Typeface.DEFAULT_BOLD
            setTextColor(Color.parseColor(t.textPrimary))
            layoutParams = LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f)
        })
        headerRow.addView(miniAvatarView(ctx, dp, t) {
            (activity as? MainActivity)?.openDrawer()
        })
        headerRow.addView(Button(ctx).apply {
            text = "✕"; textSize = 20f
            setTextColor(Color.parseColor(t.textSecondary))
            setBackgroundColor(Color.TRANSPARENT)
            layoutParams = LinearLayout.LayoutParams((44 * dp).toInt(), (44 * dp).toInt()).apply {
                marginStart = (8 * dp).toInt()
            }
            setOnClickListener { requireActivity().onBackPressed() }
        })
        layout.addView(headerRow)

        // Большой аватар по центру
        val avatarSize = (120 * dp).toInt()
        val avatarContainer = FrameLayout(ctx).apply {
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT
            ).also { it.topMargin = (24 * dp).toInt() }
        }
        avatarBig = ImageView(ctx).apply {
            layoutParams = FrameLayout.LayoutParams(avatarSize, avatarSize, Gravity.CENTER)
            scaleType = ImageView.ScaleType.CENTER_CROP
            clipToOutline = true
            outlineProvider = object : android.view.ViewOutlineProvider() {
                override fun getOutline(view: android.view.View, outline: android.graphics.Outline) {
                    outline.setOval(0, 0, view.width, view.height)
                }
            }
            background = GradientDrawable().apply {
                shape = GradientDrawable.OVAL
                setColor(hexAlpha(t.accent, 30))
            }
        }
        avatarContainer.addView(avatarBig)
        layout.addView(avatarContainer)

        // Кнопка "Сменить фото"
        layout.addView(Button(ctx).apply {
            text = "Сменить фото"
            textSize = 15f
            setTextColor(Color.parseColor(t.textPrimary))
            isAllCaps = false
            background = cardDrawable(t, 12f, dp)
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT, (52 * dp).toInt()
            ).also { it.topMargin = (20 * dp).toInt() }
            setOnClickListener { pickImage.launch("image/*") }
        })

        divider(layout, ctx, t, dp)

        // Имя
        layout.addView(label(ctx, "Имя", t, dp))
        nameInput = editField(ctx, "Ваше имя",
            InputType.TYPE_CLASS_TEXT or InputType.TYPE_TEXT_FLAG_CAP_WORDS, t, dp)
        nameInput!!.setText(prefs.getString("profile_name", ""))
        layout.addView(nameInput)

        // Описание
        layout.addView(label(ctx, "Описание", t, dp))
        descInput = editField(ctx, "Расскажите о себе...",
            InputType.TYPE_CLASS_TEXT or InputType.TYPE_TEXT_FLAG_MULTI_LINE or InputType.TYPE_TEXT_FLAG_CAP_SENTENCES,
            t, dp)
        descInput!!.apply { minLines = 3; maxLines = 5; gravity = Gravity.TOP }
        descInput!!.setText(prefs.getString("profile_desc", ""))
        layout.addView(descInput)

        divider(layout, ctx, t, dp)

        // Кнопка сохранить
        layout.addView(Button(ctx).apply {
            text = "Сохранить"
            textSize = 17f
            setTextColor(Color.parseColor(t.bg))
            isAllCaps = false; typeface = Typeface.DEFAULT_BOLD
            background = GradientDrawable().apply {
                shape = GradientDrawable.RECTANGLE; cornerRadius = 14f * dp
                setColor(Color.parseColor(t.accent))
            }
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT, (56 * dp).toInt()
            ).also { it.topMargin = (24 * dp).toInt() }
            setOnClickListener { saveProfile(this) }
        })

        reloadAvatarBig()
        return scroll
    }

    private fun saveProfile(btn: Button) {
        val name = nameInput?.text?.toString()?.trim() ?: ""
        val desc = descInput?.text?.toString()?.trim() ?: ""
        prefs.edit().putString("profile_name", name).putString("profile_desc", desc).apply()
        btn.text = "✓ Сохранено"
        btn.postDelayed({
            if (!isAdded) return@postDelayed
            btn.text = "Сохранить"
            requireActivity().onBackPressed()
        }, 900)
    }

    private fun reloadAvatarBig() {
        val t = AppTheme.current
        val bmp = MainActivity.loadAvatarBitmap(requireContext())
        if (bmp != null) {
            avatarBig?.setImageBitmap(bmp)
        } else {
            avatarBig?.setImageDrawable(null)
            avatarBig?.background = GradientDrawable().apply {
                shape = GradientDrawable.OVAL
                setColor(hexAlpha(t.accent, 30))
            }
        }
    }

    private fun copyImageToInternal(uri: Uri) {
        try {
            val input = requireContext().contentResolver.openInputStream(uri) ?: return
            val file = File(requireContext().filesDir, "avatar.jpg")
            file.outputStream().use { out -> input.copyTo(out) }
            input.close()
        } catch (_: Exception) {}
    }

    private fun label(ctx: Context, text: String, t: ThemeDef, dp: Float) = TextView(ctx).apply {
        this.text = text.uppercase(); textSize = 10f
        letterSpacing = 0.1f; typeface = Typeface.DEFAULT_BOLD
        setTextColor(Color.parseColor(t.textSecondary))
        setPadding(0, (20 * dp).toInt(), 0, (6 * dp).toInt())
    }

    private fun editField(ctx: Context, hint: String, type: Int, t: ThemeDef, dp: Float) = EditText(ctx).apply {
        inputType = type; this.hint = hint
        setTextColor(Color.parseColor(t.textPrimary))
        setHintTextColor(hexAlpha(t.textSecondary, 90))
        background = GradientDrawable().apply {
            shape = GradientDrawable.RECTANGLE; cornerRadius = 10f * dp
            setColor(hexAlpha(t.bg, 220))
            setStroke(1, Color.parseColor(t.cardBorder))
        }
        setPadding((16 * dp).toInt(), (14 * dp).toInt(), (16 * dp).toInt(), (14 * dp).toInt())
        textSize = 15f
        layoutParams = LinearLayout.LayoutParams(
            LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT
        )
    }

    private fun divider(layout: LinearLayout, ctx: Context, t: ThemeDef, dp: Float) {
        layout.addView(View(ctx).apply {
            setBackgroundColor(Color.parseColor(t.cardBorder))
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT, 1
            ).also { it.topMargin = (24 * dp).toInt() }
        })
    }
}
