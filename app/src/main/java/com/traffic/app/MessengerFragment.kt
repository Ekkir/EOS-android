package com.traffic.app

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.graphics.*
import android.graphics.drawable.GradientDrawable
import android.net.Uri
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
import androidx.activity.result.contract.ActivityResultContracts
import androidx.core.content.FileProvider
import androidx.fragment.app.Fragment
import org.json.JSONArray
import org.json.JSONObject
import java.io.*
import java.net.HttpURLConnection
import java.net.URL
import java.text.SimpleDateFormat
import java.util.*
import java.util.concurrent.Executors

class MessengerFragment : Fragment() {

    companion object {
        private const val ARG_CHANNEL_ID   = "channelId"
        private const val ARG_CHANNEL_NAME = "channelName"

        fun newInstance(channelId: String, channelName: String) = MessengerFragment().apply {
            arguments = Bundle().apply {
                putString(ARG_CHANNEL_ID,   channelId)
                putString(ARG_CHANNEL_NAME, channelName)
            }
        }
    }

    private data class Message(
        val id:      Int,
        val sender:  String,
        val text:    String,
        val ts:      Long,
        val type:    String = "text",
        val mediaId: String = "",
    )

    private val channelId   get() = arguments?.getString(ARG_CHANNEL_ID,   "general") ?: "general"
    private val channelName get() = arguments?.getString(ARG_CHANNEL_NAME, "Мессенджер") ?: "Мессенджер"

    private val messages = mutableListOf<Message>()
    private var lastId   = 0
    private val handler  = Handler(Looper.getMainLooper())
    private val executor = Executors.newSingleThreadExecutor()

    private val prefs     get() = requireContext().getSharedPreferences("traffic_prefs", Context.MODE_PRIVATE)
    private val serverUrl get() = ServerUrlResolver.resolve(prefs)
    private val myName    get() = prefs.getString("profile_name", "")?.takeIf { it.isNotBlank() }
        ?: "${android.os.Build.MANUFACTURER} ${android.os.Build.MODEL}"

    private lateinit var messagesLayout: LinearLayout
    private lateinit var scrollView:     ScrollView
    private lateinit var inputField:     EditText
    private lateinit var statusText:     TextView

    private val timeFmt = SimpleDateFormat("HH:mm", Locale.getDefault())

    // Кэш аватаров по имени пользователя (bitmap)
    private val avatarCache = mutableMapOf<String, Bitmap>()

    private val pollRunnable = object : Runnable {
        override fun run() {
            fetchMessages()
            handler.postDelayed(this, 2000)
        }
    }

    // Лаунчер для выбора файла/изображения
    private val pickMedia = registerForActivityResult(ActivityResultContracts.GetContent()) { uri ->
        uri?.let { uploadMedia(it) }
    }

    // ── UI ────────────────────────────────────────────────────────
    override fun onCreateView(inflater: LayoutInflater, container: ViewGroup?, savedInstanceState: Bundle?): View {
        val ctx = requireContext()
        val t   = AppTheme.current
        val dp  = ctx.resources.displayMetrics.density

        val root = LinearLayout(ctx).apply {
            orientation = LinearLayout.VERTICAL
            background  = bgDrawable(t)
        }

        // Шапка
        val header = LinearLayout(ctx).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity     = Gravity.CENTER_VERTICAL
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
        val titleCol = LinearLayout(ctx).apply {
            orientation = LinearLayout.VERTICAL
            layoutParams = LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f).apply { marginStart = (8 * dp).toInt() }
        }
        titleCol.addView(TextView(ctx).apply {
            text = channelName; textSize = 17f; typeface = Typeface.DEFAULT_BOLD
            setTextColor(Color.parseColor(t.textPrimary))
        })
        statusText = TextView(ctx).apply {
            text = "подключение..."; textSize = 11f
            setTextColor(Color.parseColor(t.textSecondary))
        }
        titleCol.addView(statusText)
        header.addView(titleCol)
        header.addView(miniAvatarView(ctx, dp, t) { (activity as? MainActivity)?.openDrawer() })
        root.addView(header)
        root.addView(View(ctx).apply {
            setBackgroundColor(Color.parseColor(t.cardBorder))
            layoutParams = LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, 1)
        })

        // Список сообщений
        scrollView = ScrollView(ctx).apply {
            layoutParams = LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, 0, 1f)
        }
        messagesLayout = LinearLayout(ctx).apply {
            orientation = LinearLayout.VERTICAL
            setPadding((12 * dp).toInt(), (8 * dp).toInt(), (12 * dp).toInt(), (8 * dp).toInt())
        }
        scrollView.addView(messagesLayout)
        root.addView(scrollView)

        // Поле ввода
        val inputBar = LinearLayout(ctx).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity     = Gravity.CENTER_VERTICAL
            setBackgroundColor(Color.parseColor(t.nav))
            setPadding((8 * dp).toInt(), (10 * dp).toInt(), (12 * dp).toInt(), (22 * dp).toInt())
        }

        // Кнопка прикрепить
        inputBar.addView(TextView(ctx).apply {
            text = "📎"; textSize = 20f; gravity = Gravity.CENTER
            layoutParams = LinearLayout.LayoutParams((44 * dp).toInt(), (44 * dp).toInt()).apply { marginEnd = (4 * dp).toInt() }
            setOnClickListener { showAttachSheet(ctx, t, dp) }
        })

        inputField = EditText(ctx).apply {
            hint = "Сообщение..."; textSize = 15f
            setTextColor(Color.parseColor(t.textPrimary))
            setHintTextColor(Color.parseColor(t.textSecondary))
            background = GradientDrawable().apply {
                setColor(hexAlpha(t.surface, 180))
                cornerRadius = 20 * dp
                setStroke(1, Color.parseColor(t.cardBorder))
            }
            setPadding((16 * dp).toInt(), (10 * dp).toInt(), (16 * dp).toInt(), (10 * dp).toInt())
            maxLines = 4
            layoutParams = LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f)
        }
        inputBar.addView(inputField)

        inputBar.addView(TextView(ctx).apply {
            text = "→"; textSize = 20f; gravity = Gravity.CENTER
            setTextColor(Color.parseColor(t.bg))
            background = GradientDrawable().apply { setColor(Color.parseColor(t.accent)); cornerRadius = 20 * dp }
            layoutParams = LinearLayout.LayoutParams((44 * dp).toInt(), (44 * dp).toInt()).apply { marginStart = (8 * dp).toInt() }
            typeface = Typeface.DEFAULT_BOLD
            setOnClickListener { sendTextMessage() }
        })
        root.addView(inputBar)

        // Синхронизация своего аватара на сервер при первом открытии
        syncMyAvatar()

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

    // ── Сеть ─────────────────────────────────────────────────────
    private fun fetchMessages() {
        executor.execute {
            try {
                val arr = JSONArray(URL("$serverUrl/messages?channel=$channelId&since=$lastId").readText())
                val newMsgs = mutableListOf<Message>()
                for (i in 0 until arr.length()) {
                    val o  = arr.getJSONObject(i)
                    val id = o.getInt("id")
                    newMsgs.add(Message(id, o.getString("sender"), o.optString("text", ""), o.getLong("ts"),
                        o.optString("type", "text"), o.optString("media_id", "")))
                    if (id > lastId) lastId = id
                }
                handler.post {
                    if (!isAdded) return@post
                    statusText.text = "онлайн"
                    if (newMsgs.isNotEmpty()) {
                        newMsgs.forEach { msg -> messages.add(msg); addBubble(msg) }
                        scrollView.post { scrollView.fullScroll(View.FOCUS_DOWN) }
                    }
                }
            } catch (_: Exception) {
                handler.post { if (isAdded) statusText.text = "нет связи" }
            }
        }
    }

    private fun sendTextMessage() {
        val text = inputField.text.toString().trim()
        if (text.isEmpty()) return
        inputField.setText("")
        sendMessage("text", text, "")
    }

    private fun sendMessage(type: String, text: String, mediaId: String) {
        val sender = myName
        executor.execute {
            try {
                val conn = URL("$serverUrl/messages").openConnection() as HttpURLConnection
                conn.requestMethod = "POST"
                conn.doOutput = true
                conn.setRequestProperty("Content-Type", "application/json")
                conn.connectTimeout = 5000; conn.readTimeout = 5000
                val body = JSONObject().apply {
                    put("channel",  channelId)
                    put("sender",   sender)
                    put("text",     text)
                    put("type",     type)
                    put("media_id", mediaId)
                }.toString()
                conn.outputStream.use { it.write(body.toByteArray(Charsets.UTF_8)) }
                conn.responseCode; conn.disconnect()
            } catch (_: Exception) {}
        }
    }

    // ── Медиа: загрузка ─────────────────────────────────────────
    private fun showAttachSheet(ctx: Context, t: ThemeDef, dp: Float) {
        val root    = requireActivity().findViewById<FrameLayout>(R.id.rootLayout)
        val screenH = ctx.resources.displayMetrics.heightPixels
        val sheetH  = (screenH * 0.3).toInt()
        var sheetRef: FrameLayout? = null

        val dim = View(ctx).apply {
            setBackgroundColor(Color.argb(150, 0, 0, 0)); alpha = 0f
            layoutParams = FrameLayout.LayoutParams(FrameLayout.LayoutParams.MATCH_PARENT, FrameLayout.LayoutParams.MATCH_PARENT)
        }
        root.addView(dim)
        dim.animate().alpha(1f).setDuration(200).start()

        fun dismiss() {
            val s = sheetRef ?: return
            s.animate().translationY(sheetH.toFloat()).setDuration(200).withEndAction {
                root.removeView(dim); root.removeView(s)
            }.start()
            dim.animate().alpha(0f).setDuration(200).start()
        }
        dim.setOnClickListener { dismiss() }

        val content = LinearLayout(ctx).apply {
            orientation = LinearLayout.VERTICAL
            setPadding((16 * dp).toInt(), (16 * dp).toInt(), (16 * dp).toInt(), (32 * dp).toInt())
        }
        listOf(
            Triple("🖼️", "Изображение", "image/*"),
            Triple("📄", "Файл",         "*/*"),
        ).forEach { (icon, label, mime) ->
            content.addView(LinearLayout(ctx).apply {
                orientation = LinearLayout.HORIZONTAL
                gravity     = Gravity.CENTER_VERTICAL
                setPadding((8 * dp).toInt(), (14 * dp).toInt(), (8 * dp).toInt(), (14 * dp).toInt())
                isClickable = true; isFocusable = true
                setOnClickListener { dismiss(); pickMedia.launch(mime) }
                addView(TextView(ctx).apply {
                    text = icon; textSize = 24f; gravity = Gravity.CENTER
                    layoutParams = LinearLayout.LayoutParams((44 * dp).toInt(), (44 * dp).toInt()).apply { marginEnd = (12 * dp).toInt() }
                })
                addView(TextView(ctx).apply {
                    text = label; textSize = 16f
                    setTextColor(Color.parseColor(t.textPrimary))
                })
            })
        }

        val sheet = FrameLayout(ctx).apply {
            background = GradientDrawable().apply {
                cornerRadii = floatArrayOf(24 * dp, 24 * dp, 24 * dp, 24 * dp, 0f, 0f, 0f, 0f)
                setColor(Color.parseColor(t.nav))
            }
            translationY = sheetH.toFloat()
            layoutParams = FrameLayout.LayoutParams(FrameLayout.LayoutParams.MATCH_PARENT, sheetH).apply { gravity = Gravity.BOTTOM }
        }
        sheetRef = sheet
        sheet.addView(content, FrameLayout.LayoutParams(FrameLayout.LayoutParams.MATCH_PARENT, FrameLayout.LayoutParams.MATCH_PARENT))
        root.addView(sheet)
        sheet.animate().translationY(0f).setDuration(280).setInterpolator(DecelerateInterpolator(2f)).start()
    }

    private fun uploadMedia(uri: Uri) {
        val ctx = requireContext()
        executor.execute {
            try {
                val mimeType = ctx.contentResolver.getType(uri) ?: "application/octet-stream"
                val ext = when {
                    mimeType.startsWith("image/") -> ".jpg"
                    mimeType.startsWith("video/") -> ".mp4"
                    else -> ".bin"
                }
                val msgType = when {
                    mimeType.startsWith("image/") -> "image"
                    mimeType.startsWith("video/") -> "video"
                    else -> "file"
                }
                val fileName = "upload$ext"
                val boundary = "----EosBoundary${System.currentTimeMillis()}"
                val conn = URL("$serverUrl/media/upload").openConnection() as HttpURLConnection
                conn.requestMethod = "POST"
                conn.doOutput = true
                conn.setRequestProperty("Content-Type", "multipart/form-data; boundary=$boundary")
                conn.connectTimeout = 30000; conn.readTimeout = 30000

                val inputStream = ctx.contentResolver.openInputStream(uri) ?: return@execute
                val fileBytes   = inputStream.readBytes()
                inputStream.close()

                val out = conn.outputStream
                out.write("--$boundary\r\n".toByteArray())
                out.write("Content-Disposition: form-data; name=\"file\"; filename=\"$fileName\"\r\n".toByteArray())
                out.write("Content-Type: $mimeType\r\n\r\n".toByteArray())
                out.write(fileBytes)
                out.write("\r\n--$boundary--\r\n".toByteArray())
                out.flush()

                val code = conn.responseCode
                if (code == 200) {
                    val resp     = JSONObject(conn.inputStream.bufferedReader().readText())
                    val mediaId  = resp.getString("media_id")
                    conn.disconnect()
                    sendMessage(msgType, "", mediaId)

                    // Кэшируем локально
                    if (msgType == "image") {
                        val cacheFile = File(ctx.cacheDir, "media/$mediaId")
                        cacheFile.parentFile?.mkdirs()
                        cacheFile.writeBytes(fileBytes)
                    }
                } else { conn.disconnect() }
            } catch (_: Exception) {}
        }
    }

    // ── Синхронизация своего аватара ────────────────────────────
    private fun syncMyAvatar() {
        val ctx       = requireContext()
        val avatarFile = File(ctx.filesDir, "avatar.jpg")
        if (!avatarFile.exists()) return
        executor.execute {
            try {
                val boundary = "----EosBound${System.currentTimeMillis()}"
                val conn = URL("$serverUrl/avatar").openConnection() as HttpURLConnection
                conn.requestMethod = "POST"
                conn.doOutput = true
                conn.setRequestProperty("Content-Type", "multipart/form-data; boundary=$boundary")
                conn.connectTimeout = 10000; conn.readTimeout = 10000
                val bytes = avatarFile.readBytes()
                val out   = conn.outputStream
                out.write("--$boundary\r\n".toByteArray())
                out.write("Content-Disposition: form-data; name=\"sender\"\r\n\r\n${myName}\r\n".toByteArray())
                out.write("--$boundary\r\n".toByteArray())
                out.write("Content-Disposition: form-data; name=\"file\"; filename=\"avatar.jpg\"\r\n".toByteArray())
                out.write("Content-Type: image/jpeg\r\n\r\n".toByteArray())
                out.write(bytes)
                out.write("\r\n--$boundary--\r\n".toByteArray())
                out.flush()
                conn.responseCode; conn.disconnect()
            } catch (_: Exception) {}
        }
    }

    // ── Пузыри сообщений ─────────────────────────────────────────
    private fun addBubble(msg: Message) {
        val ctx  = requireContext()
        val t    = AppTheme.current
        val dp   = ctx.resources.displayMetrics.density
        val isMe = msg.sender == myName
        val avaSize = (34 * dp).toInt()

        val row = LinearLayout(ctx).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity     = Gravity.BOTTOM
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT
            ).apply { setMargins(0, (4 * dp).toInt(), 0, (4 * dp).toInt()) }
        }

        if (!isMe) {
            val ava = makeAvatar(ctx, msg.sender, avaSize, dp, avatarCache[msg.sender])
            ava.setOnClickListener { openUserProfile(msg.sender) }
            row.addView(ava)
            row.addView(View(ctx).apply { layoutParams = LinearLayout.LayoutParams((6 * dp).toInt(), 1) })
            // Загружаем аватар асинхронно если нет в кэше
            if (!avatarCache.containsKey(msg.sender)) loadRemoteAvatar(msg.sender, ava, avaSize)
        } else {
            row.addView(View(ctx).apply { layoutParams = LinearLayout.LayoutParams(0, 1, 1f) })
        }

        val bubbleCol = LinearLayout(ctx).apply {
            orientation = LinearLayout.VERTICAL
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.WRAP_CONTENT, LinearLayout.LayoutParams.WRAP_CONTENT
            ).apply {
                if (isMe) marginStart = (60 * dp).toInt() else marginEnd = (60 * dp).toInt()
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
            background  = bubbleBg
            setPadding((12 * dp).toInt(), (8 * dp).toInt(), (12 * dp).toInt(), (6 * dp).toInt())
        }

        when (msg.type) {
            "image" -> {
                bubble.addView(buildImageView(ctx, t, dp, msg.mediaId, isMe))
            }
            "file" -> {
                bubble.addView(buildFileCard(ctx, t, dp, msg.mediaId, isMe))
            }
            else -> {
                if (msg.text.isNotEmpty()) {
                    bubble.addView(TextView(ctx).apply {
                        text = msg.text; textSize = 15f
                        setTextColor(if (isMe) Color.parseColor(t.bg) else Color.parseColor(t.textPrimary))
                    })
                }
            }
        }

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

        messagesLayout.addView(row)

        if (isMe) {
            row.alpha = 0f; row.translationX = 18 * dp
            val offsets = floatArrayOf(12f, -8f, 5f, -3f, 0f)
            var step = 0
            val gh = Handler(Looper.getMainLooper())
            fun next() {
                if (step >= offsets.size) return
                row.animate()
                    .translationX(offsets[step] * dp)
                    .alpha(if (step == 0) 0.6f else if (step < offsets.lastIndex) 0.85f else 1f)
                    .setDuration(40).setInterpolator(DecelerateInterpolator())
                    .withEndAction { step++; if (step < offsets.size) gh.post { next() } }.start()
            }
            gh.postDelayed({ next() }, 30)
        } else {
            row.alpha = 0f; row.translationX = -20 * dp
            row.animate().alpha(1f).translationX(0f).setDuration(200).setInterpolator(DecelerateInterpolator()).start()
        }
    }

    // ── Медиа-элементы в пузыре ──────────────────────────────────
    private fun buildImageView(ctx: Context, t: ThemeDef, dp: Float, mediaId: String, isMe: Boolean): View {
        val size = (200 * dp).toInt()
        val imgView = ImageView(ctx).apply {
            scaleType = ImageView.ScaleType.CENTER_CROP
            clipToOutline = true
            outlineProvider = object : ViewOutlineProvider() {
                override fun getOutline(v: View, o: Outline) { o.setRoundRect(0, 0, v.width, v.height, 12 * dp) }
            }
            layoutParams = LinearLayout.LayoutParams(size, size)
            setBackgroundColor(hexAlpha(t.surface, 100))
        }
        loadMediaImage(mediaId, imgView)
        imgView.setOnClickListener { openMediaFullscreen(ctx, t, dp, mediaId) }
        return imgView
    }

    private fun buildFileCard(ctx: Context, t: ThemeDef, dp: Float, mediaId: String, isMe: Boolean): LinearLayout {
        return LinearLayout(ctx).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity     = Gravity.CENTER_VERTICAL
            setPadding(0, (4 * dp).toInt(), 0, (4 * dp).toInt())
            addView(TextView(ctx).apply {
                text = "📄"; textSize = 28f
                layoutParams = LinearLayout.LayoutParams(LinearLayout.LayoutParams.WRAP_CONTENT, LinearLayout.LayoutParams.WRAP_CONTENT).apply { marginEnd = (8 * dp).toInt() }
            })
            val col = LinearLayout(ctx).apply { orientation = LinearLayout.VERTICAL }
            val shortName = mediaId.takeLast(24)
            col.addView(TextView(ctx).apply {
                text = shortName; textSize = 13f; typeface = Typeface.DEFAULT_BOLD
                setTextColor(if (isMe) Color.parseColor(t.bg) else Color.parseColor(t.textPrimary))
                maxLines = 1; ellipsize = android.text.TextUtils.TruncateAt.MIDDLE
            })
            col.addView(TextView(ctx).apply {
                text = "Нажмите для скачивания"; textSize = 11f
                setTextColor(if (isMe) hexAlpha(t.bg, 160) else Color.parseColor(t.textSecondary))
            })
            addView(col)
            isClickable = true; isFocusable = true
            setOnClickListener { downloadAndOpenFile(ctx, mediaId) }
        }
    }

    private fun loadMediaImage(mediaId: String, imgView: ImageView) {
        val ctx = requireContext()
        executor.execute {
            try {
                val cacheFile = File(ctx.cacheDir, "media/$mediaId")
                val bitmap = if (cacheFile.exists()) {
                    BitmapFactory.decodeFile(cacheFile.absolutePath)
                } else {
                    val bytes = URL("$serverUrl/media/$mediaId").readBytes()
                    cacheFile.parentFile?.mkdirs()
                    cacheFile.writeBytes(bytes)
                    BitmapFactory.decodeByteArray(bytes, 0, bytes.size)
                }
                handler.post { if (isAdded) imgView.setImageBitmap(bitmap) }
            } catch (_: Exception) {}
        }
    }

    private fun openMediaFullscreen(ctx: Context, t: ThemeDef, dp: Float, mediaId: String) {
        val root = requireActivity().findViewById<FrameLayout>(R.id.rootLayout)
        val dim = View(ctx).apply {
            setBackgroundColor(Color.argb(220, 0, 0, 0)); alpha = 0f
            layoutParams = FrameLayout.LayoutParams(FrameLayout.LayoutParams.MATCH_PARENT, FrameLayout.LayoutParams.MATCH_PARENT)
        }
        val imgFull = ImageView(ctx).apply {
            scaleType = ImageView.ScaleType.FIT_CENTER
            layoutParams = FrameLayout.LayoutParams(FrameLayout.LayoutParams.MATCH_PARENT, FrameLayout.LayoutParams.MATCH_PARENT)
        }
        dim.setOnClickListener { dim.animate().alpha(0f).setDuration(200).withEndAction { root.removeView(dim); root.removeView(imgFull) }.start() }
        root.addView(dim); root.addView(imgFull)
        dim.animate().alpha(1f).setDuration(200).start()
        loadMediaImage(mediaId, imgFull)
    }

    private fun downloadAndOpenFile(ctx: Context, mediaId: String) {
        executor.execute {
            try {
                val cacheFile = File(ctx.cacheDir, "media/$mediaId")
                if (!cacheFile.exists()) {
                    val bytes = URL("$serverUrl/media/$mediaId").readBytes()
                    cacheFile.parentFile?.mkdirs()
                    cacheFile.writeBytes(bytes)
                }
                val uri = FileProvider.getUriForFile(ctx, "${ctx.packageName}.fileprovider", cacheFile)
                val intent = Intent(Intent.ACTION_VIEW).apply {
                    setDataAndType(uri, ctx.contentResolver.getType(uri) ?: "*/*")
                    addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                }
                handler.post { startActivity(intent) }
            } catch (_: Exception) {}
        }
    }

    // ── Аватары ───────────────────────────────────────────────────
    private fun loadRemoteAvatar(name: String, imgView: ImageView, size: Int) {
        val ctx = requireContext()
        executor.execute {
            try {
                val cacheFile = File(ctx.cacheDir, "avatars/${name.replace("/", "_")}.jpg")
                val bitmap = if (cacheFile.exists()) {
                    BitmapFactory.decodeFile(cacheFile.absolutePath)
                } else {
                    val bytes = URL("$serverUrl/avatar/${Uri.encode(name)}").readBytes()
                    cacheFile.parentFile?.mkdirs()
                    cacheFile.writeBytes(bytes)
                    BitmapFactory.decodeByteArray(bytes, 0, bytes.size)
                } ?: return@execute
                avatarCache[name] = bitmap
                handler.post {
                    if (isAdded) imgView.setImageBitmap(circularBitmap(bitmap, size))
                }
            } catch (_: Exception) {}
        }
    }

    private fun circularBitmap(src: Bitmap, size: Int): Bitmap {
        val out = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(out)
        val paint  = Paint(Paint.ANTI_ALIAS_FLAG)
        val shader = BitmapShader(
            Bitmap.createScaledBitmap(src, size, size, true),
            Shader.TileMode.CLAMP, Shader.TileMode.CLAMP
        )
        paint.shader = shader
        canvas.drawCircle(size / 2f, size / 2f, size / 2f, paint)
        return out
    }

    private fun openUserProfile(senderName: String) {
        if (!isAdded) return
        val tag = "profile_$senderName"
        if (parentFragmentManager.findFragmentByTag(tag) != null) return
        val frag = UserProfileFragment.newInstance(senderName, avatarCache[senderName], channelId)
        parentFragmentManager.beginTransaction()
            .add(R.id.fragmentContainer, frag, tag)
            .addToBackStack(tag)
            .commit()
    }

    private fun makeAvatar(ctx: Context, name: String, size: Int, dp: Float, bitmap: Bitmap?): ImageView {
        val bmp = bitmap?.let { circularBitmap(it, size) } ?: run {
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
            scaleType  = ImageView.ScaleType.CENTER_CROP
            clipToOutline = true
            outlineProvider = object : ViewOutlineProvider() {
                override fun getOutline(v: View, o: Outline) { o.setOval(0, 0, v.width, v.height) }
            }
            layoutParams = LinearLayout.LayoutParams(size, size)
        }
    }
}
