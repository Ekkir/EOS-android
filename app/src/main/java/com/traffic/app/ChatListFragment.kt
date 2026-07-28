package com.traffic.app

import android.content.Context
import android.graphics.Color
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.view.Gravity
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.*
import androidx.fragment.app.Fragment
import org.json.JSONArray
import java.net.URL
import java.util.concurrent.Executors

class ChatListFragment : Fragment() {

    private data class ChannelItem(val id: String, val name: String, val icon: String, val lastText: String, val lastTs: Long)

    private val prefs     get() = requireContext().getSharedPreferences("traffic_prefs", Context.MODE_PRIVATE)
    private val serverUrl get() = ServerUrlResolver.resolve(prefs)
    private val myName    get() = prefs.getString("profile_name", "")?.takeIf { it.isNotBlank() }
        ?: "${android.os.Build.MANUFACTURER} ${android.os.Build.MODEL}"

    private val handler  = Handler(Looper.getMainLooper())
    private val executor = Executors.newSingleThreadExecutor()

    private lateinit var listLayout: LinearLayout
    private var dp = 1f

    private val pollRunnable = object : Runnable {
        override fun run() {
            loadChannels()
            handler.postDelayed(this, 5000)
        }
    }

    override fun onCreateView(inflater: LayoutInflater, container: ViewGroup?, savedInstanceState: Bundle?): View {
        val ctx = requireContext()
        val t   = AppTheme.current
        dp = ctx.resources.displayMetrics.density

        val root = LinearLayout(ctx).apply {
            orientation = LinearLayout.VERTICAL
            background = bgDrawable(t)
        }

        // ── Шапка ────────────────────────────────────────────────
        val header = LinearLayout(ctx).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            setBackgroundColor(Color.parseColor(t.nav))
            setPadding((12 * dp).toInt(), (12 * dp).toInt() + statusBarHeight(ctx), (16 * dp).toInt(), (12 * dp).toInt())
            elevation = 4 * dp
        }
        header.addView(TextView(ctx).apply {
            text = "←"; textSize = 22f; gravity = Gravity.CENTER
            setTextColor(Color.parseColor(t.textPrimary))
            layoutParams = LinearLayout.LayoutParams((44 * dp).toInt(), (44 * dp).toInt())
            setOnClickListener { requireActivity().onBackPressed() }
        })
        header.addView(TextView(ctx).apply {
            text = "Мессенджер"; textSize = 17f; typeface = Typeface.DEFAULT_BOLD
            setTextColor(Color.parseColor(t.textPrimary))
            layoutParams = LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f).apply {
                marginStart = (8 * dp).toInt()
            }
        })
        root.addView(header)
        root.addView(View(ctx).apply {
            setBackgroundColor(Color.parseColor(t.cardBorder))
            layoutParams = LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, 1)
        })

        // ── Список чатов ─────────────────────────────────────────
        val scroll = ScrollView(ctx).apply {
            layoutParams = LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, 0, 1f)
        }
        listLayout = LinearLayout(ctx).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(0, (8 * dp).toInt(), 0, (16 * dp).toInt())
        }
        scroll.addView(listLayout)
        root.addView(scroll)

        return root
    }

    override fun onResume() {
        super.onResume()
        handler.post(pollRunnable)
    }

    override fun onPause() {
        super.onPause()
        handler.removeCallbacks(pollRunnable)
    }

    override fun onDestroyView() {
        super.onDestroyView()
        handler.removeCallbacksAndMessages(null)
        executor.shutdown()
    }

    private fun loadChannels() {
        executor.execute {
            try {
                val arr = JSONArray(URL("$serverUrl/channels").readText())
                val channels = mutableListOf<ChannelItem>()
                for (i in 0 until arr.length()) {
                    val o = arr.getJSONObject(i)
                    val id = o.getString("id")
                    var name = o.getString("name")
                    // Для ЛС показываем имя собеседника
                    if (id.startsWith("dm_")) {
                        val parts = id.removePrefix("dm_").split("_", limit = 2)
                        name = if (parts.size == 2) {
                            if (parts[0] == myName) parts[1] else parts[0]
                        } else id
                    }
                    channels.add(ChannelItem(
                        id       = id,
                        name     = name,
                        icon     = o.optString("icon", "💬"),
                        lastText = o.optString("last_text", ""),
                        lastTs   = o.optLong("last_ts", 0L),
                    ))
                }
                handler.post {
                    if (!isAdded) return@post
                    rebuildList(channels)
                }
            } catch (_: Exception) {}
        }
    }

    private fun rebuildList(channels: List<ChannelItem>) {
        val ctx = requireContext()
        val t   = AppTheme.current
        listLayout.removeAllViews()

        // Раздел: каналы
        listLayout.addView(sectionLabel(ctx, t, "КАНАЛЫ"))

        val systemChannels = channels.filter { !it.id.startsWith("dm_") }
        systemChannels.forEach { ch -> listLayout.addView(buildChannelRow(ctx, t, ch)) }

        // Раздел: личные
        val dms = channels.filter { it.id.startsWith("dm_") }
        if (dms.isNotEmpty()) {
            listLayout.addView(sectionLabel(ctx, t, "ЛИЧНЫЕ СООБЩЕНИЯ"))
            dms.forEach { ch -> listLayout.addView(buildChannelRow(ctx, t, ch)) }
        }
    }

    private fun buildChannelRow(ctx: Context, t: ThemeDef, ch: ChannelItem): View {
        val row = LinearLayout(ctx).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            setPadding((16 * dp).toInt(), (14 * dp).toInt(), (16 * dp).toInt(), (14 * dp).toInt())
            isClickable = true; isFocusable = true
            setOnClickListener { openChat(ch) }
        }

        // Иконка / аватар
        val iconSize = (48 * dp).toInt()
        val iconBox = FrameLayout(ctx).apply {
            layoutParams = LinearLayout.LayoutParams(iconSize, iconSize).apply { marginEnd = (14 * dp).toInt() }
            background = GradientDrawable().apply {
                shape = GradientDrawable.OVAL
                setColor(hexAlpha(t.accent, 30))
            }
        }
        iconBox.addView(TextView(ctx).apply {
            text = ch.icon; textSize = 22f; gravity = Gravity.CENTER
            layoutParams = FrameLayout.LayoutParams(FrameLayout.LayoutParams.MATCH_PARENT, FrameLayout.LayoutParams.MATCH_PARENT)
        })
        row.addView(iconBox)

        val textCol = LinearLayout(ctx).apply {
            orientation = LinearLayout.VERTICAL
            layoutParams = LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f)
        }
        textCol.addView(TextView(ctx).apply {
            text = ch.name; textSize = 16f; typeface = Typeface.DEFAULT_BOLD
            setTextColor(Color.parseColor(t.textPrimary))
        })
        if (ch.lastText.isNotEmpty()) {
            textCol.addView(TextView(ctx).apply {
                text = ch.lastText.take(50); textSize = 13f
                setTextColor(Color.parseColor(t.textSecondary))
                setPadding(0, (2 * dp).toInt(), 0, 0)
                maxLines = 1
                ellipsize = android.text.TextUtils.TruncateAt.END
            })
        }
        row.addView(textCol)

        // Разделитель
        val wrapper = LinearLayout(ctx).apply {
            orientation = LinearLayout.VERTICAL
            layoutParams = LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT)
        }
        wrapper.addView(row)
        wrapper.addView(View(ctx).apply {
            setBackgroundColor(hexAlpha(t.cardBorder, 80))
            layoutParams = LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, 1).apply {
                marginStart = (78 * dp).toInt()
            }
        })
        return wrapper
    }

    private fun sectionLabel(ctx: Context, t: ThemeDef, text: String) = TextView(ctx).apply {
        this.text = text
        textSize = 11f; letterSpacing = 0.12f; typeface = Typeface.DEFAULT_BOLD
        setTextColor(Color.parseColor(t.textSecondary))
        setPadding((16 * dp).toInt(), (16 * dp).toInt(), (16 * dp).toInt(), (6 * dp).toInt())
    }

    private fun openChat(ch: ChannelItem) {
        val tag = "messenger_${ch.id}"
        if (parentFragmentManager.findFragmentByTag(tag) != null) return
        val frag = MessengerFragment.newInstance(ch.id, ch.name)
        parentFragmentManager.beginTransaction()
            .add(R.id.fragmentContainer, frag, tag)
            .addToBackStack(tag)
            .commit()
    }
}
