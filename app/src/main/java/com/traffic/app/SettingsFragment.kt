package com.traffic.app

import android.app.AlertDialog
import android.content.Context
import android.content.res.ColorStateList
import android.graphics.Color
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.graphics.drawable.RippleDrawable
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.text.InputType
import android.view.Gravity
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.*
import androidx.fragment.app.Fragment
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL
import java.util.concurrent.Executors

class SettingsFragment : Fragment() {

    companion object {
        var adminUnlocked = false
    }

    private val executor = Executors.newSingleThreadExecutor()
    private val handler  = Handler(Looper.getMainLooper())

    override fun onCreateView(inflater: LayoutInflater, container: ViewGroup?, savedInstanceState: Bundle?): View {
        val ctx = requireContext()
        val t   = AppTheme.current
        val dp  = ctx.resources.displayMetrics.density
        val prefs = ctx.getSharedPreferences("traffic_prefs", Context.MODE_PRIVATE)
        val isAdmin = prefs.getString("google_email", "") == "razzorenovkiril@gmail.com"

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
            openFragment(ThemesFragment(), "themes")
        })
        layout.addView(spacer(ctx, dp, 12f))
        layout.addView(buildItem("🚦", "Светофоры", "Тайминги и порядок фаз", dp, t) {
            openFragment(CalibrationFragment(), "calib_traffic")
        })
        layout.addView(spacer(ctx, dp, 12f))
        layout.addView(buildItem("🔌", "Подключение", "Адрес сервера", dp, t) {
            openFragment(ConnectionFragment(), "connection")
        })
        layout.addView(spacer(ctx, dp, 12f))
        layout.addView(buildItem("ℹ️", "О приложении", "Версия, обновления", dp, t) {
            openFragment(AboutFragment(), "about_settings")
        })

        if (isAdmin) {
            layout.addView(spacer(ctx, dp, 24f))
            layout.addView(buildItem("🛡️", "Эндминестратор", "Управление сервером", dp, t) {
                showAdminPasswordDialog(ctx, t, dp)
            })
        }

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

    private fun showAdminPasswordDialog(ctx: Context, t: ThemeDef, dp: Float) {
        if (adminUnlocked) { openFragment(AdminFragment(), "admin"); return }

        val serverUrl = ctx.getSharedPreferences("traffic_prefs", Context.MODE_PRIVATE)
            .getString("server_url", "http://eos-traffic.ddns.net:5000")!!

        val input = EditText(ctx).apply {
            inputType = InputType.TYPE_CLASS_NUMBER or InputType.TYPE_NUMBER_VARIATION_PASSWORD
            hint = "Пароль"
            setTextColor(Color.parseColor(t.textPrimary))
            setHintTextColor(hexAlpha(t.textSecondary, 100))
            setPadding((16 * dp).toInt(), (12 * dp).toInt(), (16 * dp).toInt(), (12 * dp).toInt())
        }
        val container = LinearLayout(ctx).apply {
            setPadding((24 * dp).toInt(), (8 * dp).toInt(), (24 * dp).toInt(), 0)
            addView(input)
        }

        val dialog = AlertDialog.Builder(ctx)
            .setTitle("Эндминестратор")
            .setView(container)
            .setPositiveButton("Войти", null)
            .setNegativeButton("Отмена", null)
            .create()

        dialog.setOnShowListener {
            dialog.getButton(AlertDialog.BUTTON_POSITIVE)?.apply {
                setTextColor(Color.parseColor(t.accent))
                setOnClickListener {
                    val pwd = input.text.toString().trim()
                    if (pwd.isEmpty()) return@setOnClickListener
                    this.isEnabled = false
                    this.text = "Проверяю..."
                    executor.execute {
                        try {
                            val conn = URL("$serverUrl/check_admin").openConnection() as HttpURLConnection
                            conn.requestMethod = "POST"
                            conn.setRequestProperty("Content-Type", "application/json")
                            conn.doOutput = true
                            conn.connectTimeout = 6000
                            conn.outputStream.write("{\"password\":\"$pwd\"}".toByteArray())
                            val code = conn.responseCode; conn.disconnect()
                            handler.post {
                                if (!isAdded) return@post
                                if (code == 200) {
                                    adminUnlocked = true
                                    dialog.dismiss()
                                    openFragment(AdminFragment(), "admin")
                                } else {
                                    this.isEnabled = true; this.text = "Войти"
                                    input.error = "Неверный пароль"
                                }
                            }
                        } catch (e: Exception) {
                            handler.post {
                                if (!isAdded) return@post
                                this.isEnabled = true; this.text = "Войти"
                                input.error = "Нет связи с сервером"
                            }
                        }
                    }
                }
            }
            dialog.getButton(AlertDialog.BUTTON_NEGATIVE)?.setTextColor(Color.parseColor(t.textSecondary))
        }
        dialog.show()
    }

    private fun spacer(ctx: android.content.Context, dp: Float, h: Float) = View(ctx).apply {
        layoutParams = LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, (h * dp).toInt())
    }

    override fun onDestroyView() {
        super.onDestroyView()
        handler.removeCallbacksAndMessages(null)
        executor.shutdown()
    }
}
