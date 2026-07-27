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
import android.view.animation.DecelerateInterpolator
import android.widget.*
import androidx.fragment.app.Fragment
import org.json.JSONArray
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL
import java.text.SimpleDateFormat
import java.util.*
import java.util.concurrent.Executors

class MessengerFragment : Fragment() {

    private data class Message(val id: Int, val sender: String, val text: String, val ts: Long)

    private val messages = mutableListOf<Message>()
    private var lastId = 0
    private val handler = Handler(Looper.getMainLooper())
    private val executor = Executors.newSingleThreadExecutor()

    private val prefs get() = requireContext().getSharedPreferences("traffic_prefs", Context.MODE_PRIVATE)
    private val serverUrl get() = prefs.getString("server_url", "http://2.61.59.197:5000")!!
    private val myName get() = prefs.getString("profile_name", "")?.takeIf { it.isNotBlank() } ?: "Аноним"

    private lateinit var messagesLayout: LinearLayout
    private lateinit var scrollView: ScrollView
    private lateinit var inputField: EditText
    private lateinit var statusText: TextView

    private val timeFmt = SimpleDateFormat("HH:mm", Locale.getDefault())

    private val pollRunnable = object : Runnable {
        override fun run() {
            fetchMessages()
            handler.postDelayed(this, 2000)
        }
    }

    override fun onCreateView(inflater: LayoutInflater, container: ViewGroup?, savedInstanceState: Bundle?): View {
        val ctx = requireContext()
        val t = AppTheme.current
        val dp = ctx.resources.displayMetrics.density

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
            elevation = (4 * dp)
        }

        header.addView(TextView(ctx).apply {
            text = "←"; textSize = 22f; gravity = Gravity.CENTER
            setTextColor(Color.parseColor(t.textPrimary))
            layoutParams = LinearLayout.LayoutParams((44 * dp).toInt(), (44 * dp).toInt())
            setOnClickListener {
                requireActivity().onBackPressed()
            }
        })

        val titleCol = LinearLayout(ctx).apply {
            orientation = LinearLayout.VERTICAL
            layoutParams = LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f)
            setPadding((8 * dp).toInt(), 0, 0, 0)
        }
        titleCol.addView(TextView(ctx).apply {
            text = "Мессенджер"; textSize = 17f; typeface = Typeface.DEFAULT_BOLD
            setTextColor(Color.parseColor(t.textPrimary))
        })
        statusText = TextView(ctx).apply {
            text = "подключение..."; textSize = 11f
            setTextColor(Color.parseColor(t.textSecondary))
        }
        titleCol.addView(statusText)
        header.addView(titleCol)

        header.addView(miniAvatarView(ctx, dp, t) {
            (activity as? MainActivity)?.openDrawer()
        })

        root.addView(header)

        // Тонкая линия
        root.addView(View(ctx).apply {
            setBackgroundColor(Color.parseColor(t.cardBorder))
            layoutParams = LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, 1)
        })

        // ── Список сообщений ────────────────────────────────────
        scrollView = ScrollView(ctx).apply {
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT, 0, 1f
            )
        }
        messagesLayout = LinearLayout(ctx).apply {
            orientation = LinearLayout.VERTICAL
            setPadding((12 * dp).toInt(), (8 * dp).toInt(), (12 * dp).toInt(), (8 * dp).toInt())
        }
        scrollView.addView(messagesLayout)
        root.addView(scrollView)

        // ── Поле ввода ───────────────────────────────────────────
        val inputBar = LinearLayout(ctx).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            setBackgroundColor(Color.parseColor(t.nav))
            setPadding((12 * dp).toInt(), (10 * dp).toInt(), (12 * dp).toInt(), (22 * dp).toInt())
        }

        val inputBg = GradientDrawable().apply {
            setColor(hexAlpha(t.surface, 180))
            cornerRadius = (20 * dp)
            setStroke(1, Color.parseColor(t.cardBorder))
        }
        inputField = EditText(ctx).apply {
            hint = "Сообщение..."; textSize = 15f
            setTextColor(Color.parseColor(t.textPrimary))
            setHintTextColor(Color.parseColor(t.textSecondary))
            background = inputBg
            setPadding((16 * dp).toInt(), (10 * dp).toInt(), (16 * dp).toInt(), (10 * dp).toInt())
            maxLines = 4
            layoutParams = LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f)
        }
        inputBar.addView(inputField)

        val sendBg = GradientDrawable().apply {
            setColor(Color.parseColor(t.accent))
            cornerRadius = (20 * dp)
        }
        inputBar.addView(TextView(ctx).apply {
            text = "→"; textSize = 20f; gravity = Gravity.CENTER
            setTextColor(Color.parseColor(t.bg))
            background = sendBg
            layoutParams = LinearLayout.LayoutParams((44 * dp).toInt(), (44 * dp).toInt()).apply {
                marginStart = (8 * dp).toInt()
            }
            typeface = Typeface.DEFAULT_BOLD
            setOnClickListener { sendMessage() }
        })

        root.addView(inputBar)

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

    private fun fetchMessages() {
        executor.execute {
            try {
                val json = JSONArray(URL("$serverUrl/messages?since=$lastId").readText())
                val newMsgs = mutableListOf<Message>()
                for (i in 0 until json.length()) {
                    val obj = json.getJSONObject(i)
                    val id = obj.getInt("id")
                    newMsgs.add(Message(id, obj.getString("sender"), obj.getString("text"), obj.getLong("ts")))
                    if (id > lastId) lastId = id
                }
                handler.post {
                    if (!isAdded) return@post
                    statusText.text = "онлайн"
                    if (newMsgs.isNotEmpty()) {
                        newMsgs.forEach { msg ->
                            messages.add(msg)
                            addBubble(msg)
                        }
                        scrollView.post { scrollView.fullScroll(View.FOCUS_DOWN) }
                    }
                }
            } catch (_: Exception) {
                handler.post { if (isAdded) statusText.text = "нет связи" }
            }
        }
    }

    private fun sendMessage() {
        val text = inputField.text.toString().trim()
        if (text.isEmpty()) return
        inputField.setText("")
        val sender = myName
        executor.execute {
            try {
                val conn = URL("$serverUrl/messages").openConnection() as HttpURLConnection
                conn.requestMethod = "POST"
                conn.doOutput = true
                conn.setRequestProperty("Content-Type", "application/json")
                conn.connectTimeout = 5000
                conn.readTimeout = 5000
                val body = JSONObject().apply { put("sender", sender); put("text", text) }.toString()
                conn.outputStream.use { it.write(body.toByteArray(Charsets.UTF_8)) }
                conn.responseCode
                conn.disconnect()
            } catch (_: Exception) {}
        }
    }

    private fun addBubble(msg: Message) {
        val ctx  = requireContext()
        val t    = AppTheme.current
        val dp   = ctx.resources.displayMetrics.density
        val isMe = msg.sender == myName
        val avaSize = (34 * dp).toInt()

        // Горизонтальная строка: аватар + пузырь (или пузырь + аватар для своих)
        val row = LinearLayout(ctx).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.BOTTOM
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            ).apply { setMargins(0, (4 * dp).toInt(), 0, (4 * dp).toInt()) }
        }

        if (!isMe) {
            row.addView(makeAvatar(ctx, msg.sender, avaSize, dp, null))
            row.addView(View(ctx).apply { layoutParams = LinearLayout.LayoutParams((6 * dp).toInt(), 1) })
        } else {
            // Спейсер слева чтобы пузырь прижался вправо
            row.addView(View(ctx).apply { layoutParams = LinearLayout.LayoutParams(0, 1, 1f) })
        }

        val bubbleCol = LinearLayout(ctx).apply {
            orientation = LinearLayout.VERTICAL
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.WRAP_CONTENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            ).apply {
                if (isMe) marginStart = (60 * dp).toInt()
                else       marginEnd   = (60 * dp).toInt()
            }
        }

        if (!isMe) {
            bubbleCol.addView(TextView(ctx).apply {
                text = msg.sender; textSize = 11f; typeface = Typeface.DEFAULT_BOLD
                setTextColor(Color.parseColor(t.accent))
                setPadding((4 * dp).toInt(), 0, 0, (2 * dp).toInt())
            })
        }

        val bubbleBg = GradientDrawable().apply {
            if (isMe) {
                setColor(hexAlpha(t.accent, 200))
                cornerRadii = floatArrayOf(16f, 16f, 4f, 4f, 16f, 16f, 16f, 16f).map { it * dp }.toFloatArray()
            } else {
                setColor(hexAlpha(t.surface, 200))
                setStroke(1, Color.parseColor(t.cardBorder))
                cornerRadii = floatArrayOf(4f, 4f, 16f, 16f, 16f, 16f, 16f, 16f).map { it * dp }.toFloatArray()
            }
        }
        val bubble = LinearLayout(ctx).apply {
            orientation = LinearLayout.VERTICAL
            background = bubbleBg
            setPadding((12 * dp).toInt(), (8 * dp).toInt(), (12 * dp).toInt(), (6 * dp).toInt())
        }
        bubble.addView(TextView(ctx).apply {
            text = msg.text; textSize = 15f
            setTextColor(if (isMe) Color.parseColor(t.bg) else Color.parseColor(t.textPrimary))
        })
        bubble.addView(TextView(ctx).apply {
            text = timeFmt.format(Date(msg.ts * 1000L)); textSize = 10f
            setTextColor(if (isMe) hexAlpha(t.bg, 180) else Color.parseColor(t.textSecondary))
            gravity = Gravity.END
            layoutParams = LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT)
        })
        bubbleCol.addView(bubble)
        row.addView(bubbleCol)

        if (isMe) {
            row.addView(View(ctx).apply { layoutParams = LinearLayout.LayoutParams((6 * dp).toInt(), 1) })
            row.addView(makeAvatar(ctx, msg.sender, avaSize, dp, MainActivity.loadAvatarBitmap(ctx)))
        }

        // Анимация глитча: быстрые случайные сдвиги по X + fade
        row.alpha = 0f
        row.translationX = if (isMe) (18 * dp) else (-18 * dp)
        messagesLayout.addView(row)
        val glitchOffsets = if (isMe) floatArrayOf(12f, -8f, 5f, -3f, 0f) else floatArrayOf(-12f, 8f, -5f, 3f, 0f)
        var step = 0
        val glitchHandler = Handler(Looper.getMainLooper())
        fun nextGlitch() {
            if (step >= glitchOffsets.size) return
            val offset = glitchOffsets[step] * dp
            row.animate()
                .translationX(offset)
                .alpha(if (step == 0) 0.6f else if (step < glitchOffsets.lastIndex) 0.85f else 1f)
                .setDuration(40)
                .setInterpolator(DecelerateInterpolator())
                .withEndAction { step++; if (step < glitchOffsets.size) glitchHandler.post { nextGlitch() } }
                .start()
        }
        glitchHandler.postDelayed({ nextGlitch() }, 30)
    }

    private fun makeAvatar(ctx: Context, name: String, size: Int, dp: Float, bitmap: Bitmap?): ImageView {
        val bmp = bitmap ?: run {
            val b = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
            val c = Canvas(b)
            val p = Paint(Paint.ANTI_ALIAS_FLAG)
            val palette = listOf("#FF6B6B","#4ECDC4","#45B7D1","#96CEB4","#DDA0DD","#F7B731","#20BF6B")
            p.color = Color.parseColor(palette[Math.abs(name.hashCode()) % palette.size])
            c.drawCircle(size / 2f, size / 2f, size / 2f, p)
            p.color = Color.WHITE; p.textSize = size * 0.44f
            p.textAlign = Paint.Align.CENTER; p.typeface = Typeface.DEFAULT_BOLD
            val initial = name.firstOrNull()?.uppercaseChar()?.toString() ?: "?"
            c.drawText(initial, size / 2f, size / 2f + p.textSize / 3f, p)
            b
        }
        return ImageView(ctx).apply {
            setImageBitmap(bmp)
            scaleType = ImageView.ScaleType.CENTER_CROP
            clipToOutline = true
            outlineProvider = object : ViewOutlineProvider() {
                override fun getOutline(v: View, outline: Outline) { outline.setOval(0, 0, v.width, v.height) }
            }
            layoutParams = LinearLayout.LayoutParams(size, size)
        }
    }
}
