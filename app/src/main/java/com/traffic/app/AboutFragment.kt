package com.traffic.app

import android.animation.ValueAnimator
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.BitmapShader
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.LinearGradient
import android.graphics.Paint
import android.graphics.Shader
import android.graphics.Typeface
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
import androidx.core.content.FileProvider
import androidx.fragment.app.Fragment
import org.json.JSONObject
import java.io.File
import java.io.FileOutputStream
import java.net.HttpURLConnection
import java.net.URL
import java.util.concurrent.Executors

class AboutFragment : Fragment() {

    companion object {
        const val GITHUB_OWNER  = "Ekkir"
        const val GITHUB_REPO   = "EOS-android"
        const val CURRENT_VERSION = "1.1.19"
    }

    private val handler  = Handler(Looper.getMainLooper())
    private val executor = Executors.newSingleThreadExecutor()

    private lateinit var updateCard: LinearLayout
    private lateinit var updateStatus: TextView
    private lateinit var updateBtn: Button
    private lateinit var progressBar: ProgressBar
    private var sheetOverlay: View? = null
    private var storedSheetH = 0
    private var shimmerAnimator: ValueAnimator? = null
    private var downloadShimmer: ValueAnimator? = null
    private var cachedDp = 0f

    override fun onCreateView(inflater: LayoutInflater, container: ViewGroup?, savedInstanceState: Bundle?): View {
        val ctx = requireContext()
        val t   = AppTheme.current
        val dp  = ctx.resources.displayMetrics.density
        cachedDp = dp

        val scroll = ScrollView(ctx).apply { background = bgDrawable(t) }
        val layout = LinearLayout(ctx).apply {
            orientation = LinearLayout.VERTICAL
            setPadding((20 * dp).toInt(), (12 * dp).toInt() + statusBarHeight(ctx), (20 * dp).toInt(), (32 * dp).toInt())
        }
        scroll.addView(layout)

        // ── Шапка ─────────────────────────────────────────────────────────────
        val header = LinearLayout(ctx).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            setPadding(0, 0, 0, (20 * dp).toInt())
        }
        header.addView(TextView(ctx).apply {
            text = "←"; textSize = 22f; gravity = Gravity.CENTER
            setTextColor(Color.parseColor(t.textPrimary))
            layoutParams = LinearLayout.LayoutParams((44 * dp).toInt(), (44 * dp).toInt())
            setOnClickListener { requireActivity().onBackPressed() }
        })
        header.addView(TextView(ctx).apply {
            text = "О приложении"; textSize = 19f; typeface = Typeface.DEFAULT_BOLD
            setTextColor(Color.parseColor(t.textPrimary))
            layoutParams = LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f).apply {
                marginStart = (8 * dp).toInt()
            }
        })
        header.addView(miniAvatarView(ctx, dp, t) {
            (activity as? MainActivity)?.openDrawer()
        })
        layout.addView(header)

        // ── Лого / версия ─────────────────────────────────────────────────────
        val logoCard = LinearLayout(ctx).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER_HORIZONTAL
            setPadding((20 * dp).toInt(), (28 * dp).toInt(), (20 * dp).toInt(), (28 * dp).toInt())
            background = cardDrawable(t, 20f, dp)
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT
            ).apply { bottomMargin = (16 * dp).toInt() }
        }
        val shimmerColors = intArrayOf(
            Color.parseColor(t.textSecondary),
            Color.parseColor(t.accent),
            Color.parseColor(t.textPrimary),
            Color.parseColor(t.accent),
            Color.parseColor(t.textSecondary),
        )
        logoCard.addView(object : TextView(ctx) {
            private val anim = ValueAnimator.ofFloat(0f, 1f).apply {
                duration = 2400; repeatCount = ValueAnimator.INFINITE; repeatMode = ValueAnimator.RESTART
                addUpdateListener { invalidate() }
                start()
            }
            init {
                text = "EOS"; textSize = 42f; typeface = Typeface.DEFAULT_BOLD
                gravity = Gravity.CENTER_HORIZONTAL
                layoutParams = LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT)
            }
            override fun onDraw(canvas: Canvas) {
                val w = width.toFloat(); if (w == 0f) { super.onDraw(canvas); return }
                val frac = anim.animatedValue as Float
                val start = -w + frac * 3f * w
                paint.shader = LinearGradient(start, 0f, start + w, 0f, shimmerColors, null, Shader.TileMode.CLAMP)
                super.onDraw(canvas)
            }
            override fun onDetachedFromWindow() { super.onDetachedFromWindow(); anim.cancel() }
        })
        logoCard.addView(TextView(ctx).apply {
            text = "SYSTEM"; textSize = 12f; letterSpacing = 0.3f; typeface = Typeface.DEFAULT_BOLD
            setTextColor(Color.parseColor(t.textSecondary))
            gravity = Gravity.CENTER_HORIZONTAL
            setPadding(0, 0, 0, (16 * dp).toInt())
        })
        logoCard.addView(TextView(ctx).apply {
            text = "Версия $CURRENT_VERSION"; textSize = 14f
            setTextColor(Color.parseColor(t.textSecondary))
            gravity = Gravity.CENTER_HORIZONTAL
        })
        layout.addView(logoCard)

        layout.addView(creatorCard(ctx, t, dp))
        layout.addView(spacer(ctx, dp, 20f))

        // ── Обновления ────────────────────────────────────────────────────────
        layout.addView(sectionLabel(ctx, "ОБНОВЛЕНИЯ", t, dp))
        layout.addView(spacer(ctx, dp, 10f))

        updateCard = LinearLayout(ctx).apply {
            orientation = LinearLayout.VERTICAL
            setPadding((16 * dp).toInt(), (16 * dp).toInt(), (16 * dp).toInt(), (16 * dp).toInt())
            background = cardDrawable(t, 16f, dp)
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT
            )
        }

        updateStatus = TextView(ctx).apply {
            text = "Нажмите кнопку, чтобы проверить наличие обновлений"; textSize = 14f
            setTextColor(Color.parseColor(t.textSecondary))
            setPadding(0, 0, 0, (12 * dp).toInt())
        }
        updateCard.addView(updateStatus)

        progressBar = ProgressBar(ctx, null, android.R.attr.progressBarStyleHorizontal).apply {
            isIndeterminate = false; max = 100; progress = 0
            visibility = View.GONE
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT, (6 * dp).toInt()
            ).apply { bottomMargin = (10 * dp).toInt() }
        }
        updateCard.addView(progressBar)

        updateBtn = Button(ctx).apply {
            text = "Проверить обновления"; textSize = 15f; isAllCaps = false
            typeface = Typeface.DEFAULT_BOLD
            setTextColor(Color.parseColor(t.bg))
            background = GradientDrawable().apply {
                shape = GradientDrawable.RECTANGLE; cornerRadius = 12f * dp
                setColor(Color.parseColor(t.accent))
            }
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT, (52 * dp).toInt()
            )
            setOnClickListener { checkForUpdates(ctx, dp) }
        }
        updateCard.addView(updateBtn)

        layout.addView(updateCard)

        val root = FrameLayout(ctx).apply {
            layoutParams = ViewGroup.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT)
        }
        root.addView(scroll)
        return root
    }

    override fun onDestroyView() {
        super.onDestroyView()
        handler.removeCallbacksAndMessages(null)
        executor.shutdown()
        shimmerAnimator?.cancel()
        downloadShimmer?.cancel()
    }

    private fun startButtonShimmer() {
        val t = AppTheme.current
        shimmerAnimator?.cancel()
        shimmerAnimator = ValueAnimator.ofArgb(
            Color.parseColor(t.accent),
            Color.parseColor(t.textPrimary),
            Color.parseColor(t.accent),
        ).apply {
            duration = 900; repeatCount = ValueAnimator.INFINITE; repeatMode = ValueAnimator.REVERSE
            addUpdateListener { anim ->
                if (!isAdded) return@addUpdateListener
                updateBtn.background = GradientDrawable().apply {
                    shape = GradientDrawable.RECTANGLE; cornerRadius = 12f * cachedDp
                    setColor(anim.animatedValue as Int)
                }
            }
            start()
        }
    }

    private fun stopButtonShimmer() {
        shimmerAnimator?.cancel(); shimmerAnimator = null
        if (!isAdded) return
        val t = AppTheme.current
        updateBtn.background = GradientDrawable().apply {
            shape = GradientDrawable.RECTANGLE; cornerRadius = 12f * cachedDp
            setColor(Color.parseColor(t.accent))
        }
    }

    private fun startDownloadShimmer() {
        val t = AppTheme.current
        val accent = Color.parseColor(t.accent)
        // Яркость акцента: если светлый (minimal) — тёмный отблеск, если тёмный — белый отблеск
        val lum = (0.299f * Color.red(accent) + 0.587f * Color.green(accent) + 0.114f * Color.blue(accent)) / 255f
        val highlight = if (lum > 0.55f)
            Color.argb(255, (Color.red(accent) * 0.45f).toInt(), (Color.green(accent) * 0.45f).toInt(), (Color.blue(accent) * 0.45f).toInt())
        else
            Color.WHITE
        downloadShimmer?.cancel()
        downloadShimmer = ValueAnimator.ofFloat(0f, 1f).apply {
            duration = 1100; repeatCount = ValueAnimator.INFINITE; repeatMode = ValueAnimator.RESTART
            addUpdateListener { anim ->
                if (!isAdded) return@addUpdateListener
                val f = anim.animatedValue as Float
                fun spot(pos: Float): Int {
                    val d = (f - pos).let { if (it < 0f) it + 1f else it }
                    if (d > 0.28f) return accent
                    val blend = 1f - d / 0.28f
                    return Color.argb(255,
                        (Color.red(accent)   + (Color.red(highlight)   - Color.red(accent))   * blend).toInt().coerceIn(0, 255),
                        (Color.green(accent) + (Color.green(highlight) - Color.green(accent)) * blend).toInt().coerceIn(0, 255),
                        (Color.blue(accent)  + (Color.blue(highlight)  - Color.blue(accent))  * blend).toInt().coerceIn(0, 255)
                    )
                }
                updateBtn.background = GradientDrawable(
                    GradientDrawable.Orientation.LEFT_RIGHT,
                    intArrayOf(spot(0f), spot(0.33f), spot(0.66f), spot(1f))
                ).apply { cornerRadius = 12f * cachedDp }
            }
            start()
        }
    }

    private fun stopDownloadShimmer() {
        downloadShimmer?.cancel(); downloadShimmer = null
        if (!isAdded) return
        val t = AppTheme.current
        updateBtn.background = GradientDrawable().apply {
            shape = GradientDrawable.RECTANGLE; cornerRadius = 12f * cachedDp
            setColor(Color.parseColor(t.accent))
        }
    }

    private fun showBottomSheet(version: String, summary: String, actionLabel: String, onAction: () -> Unit) {
        if (!isAdded) return
        hideBottomSheet()
        val ctx = requireContext()
        val t = AppTheme.current
        val dp = ctx.resources.displayMetrics.density
        val rootView = requireView() as FrameLayout
        val screenH = ctx.resources.displayMetrics.heightPixels
        val sheetH = (screenH * 0.82).toInt()
        storedSheetH = sheetH

        val dim = View(ctx).apply {
            setBackgroundColor(Color.argb(170, 0, 0, 0))
            alpha = 0f
            layoutParams = FrameLayout.LayoutParams(FrameLayout.LayoutParams.MATCH_PARENT, FrameLayout.LayoutParams.MATCH_PARENT)
            setOnClickListener { hideBottomSheet() }
        }

        val sheetContent = LinearLayout(ctx).apply {
            orientation = LinearLayout.VERTICAL
            setPadding((20 * dp).toInt(), (16 * dp).toInt(), (20 * dp).toInt(), (32 * dp).toInt())
        }

        sheetContent.addView(FrameLayout(ctx).apply {
            layoutParams = LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, (24 * dp).toInt())
            addView(View(ctx).apply {
                background = GradientDrawable().apply { cornerRadius = 3 * dp; setColor(Color.argb(80, 255, 255, 255)) }
                layoutParams = FrameLayout.LayoutParams((44 * dp).toInt(), (4 * dp).toInt(), Gravity.CENTER)
            })
        })
        sheetContent.addView(TextView(ctx).apply {
            text = "🆕  Обновление $version"; textSize = 22f; typeface = Typeface.DEFAULT_BOLD
            setTextColor(Color.parseColor(t.accent))
            setPadding(0, (8 * dp).toInt(), 0, (4 * dp).toInt())
        })
        sheetContent.addView(TextView(ctx).apply {
            text = "Доступна новая версия приложения"; textSize = 13f
            setTextColor(Color.argb(140, 255, 255, 255))
            setPadding(0, 0, 0, (16 * dp).toInt())
        })

        val notesScroll = ScrollView(ctx).apply {
            layoutParams = LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, 0, 1f)
        }
        notesScroll.addView(TextView(ctx).apply {
            text = summary; textSize = 14f
            setLineSpacing(0f, 1.5f)
            setTextColor(Color.parseColor(t.textPrimary))
        })
        sheetContent.addView(notesScroll)

        sheetContent.addView(Button(ctx).apply {
            text = actionLabel; textSize = 17f; isAllCaps = false; typeface = Typeface.DEFAULT_BOLD
            setTextColor(Color.parseColor(t.bg))
            background = GradientDrawable().apply { cornerRadius = 14 * dp; setColor(Color.parseColor(t.accent)) }
            layoutParams = LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, (56 * dp).toInt()).apply {
                topMargin = (14 * dp).toInt()
            }
            setOnClickListener { onAction(); hideBottomSheet() }
        })

        val sheetPanel = FrameLayout(ctx).apply {
            background = GradientDrawable().apply {
                shape = GradientDrawable.RECTANGLE
                cornerRadii = floatArrayOf(28 * dp, 28 * dp, 28 * dp, 28 * dp, 0f, 0f, 0f, 0f)
                setColor(Color.parseColor("#111116"))
            }
            translationY = sheetH.toFloat()
            layoutParams = FrameLayout.LayoutParams(FrameLayout.LayoutParams.MATCH_PARENT, sheetH).apply {
                gravity = Gravity.BOTTOM
            }
        }
        sheetPanel.addView(sheetContent, FrameLayout.LayoutParams(FrameLayout.LayoutParams.MATCH_PARENT, FrameLayout.LayoutParams.MATCH_PARENT))

        val overlay = FrameLayout(ctx).apply {
            layoutParams = FrameLayout.LayoutParams(FrameLayout.LayoutParams.MATCH_PARENT, FrameLayout.LayoutParams.MATCH_PARENT)
        }
        overlay.addView(dim)
        overlay.addView(sheetPanel)

        rootView.addView(overlay)
        sheetOverlay = overlay

        dim.animate().alpha(1f).setDuration(300).start()
        sheetPanel.animate().translationY(0f).setDuration(380).setInterpolator(DecelerateInterpolator(2f)).start()
    }

    private fun hideBottomSheet() {
        val overlay = sheetOverlay ?: return
        val rootView = requireView() as? FrameLayout ?: return
        val sheetPanel = (overlay as FrameLayout).getChildAt(1) ?: return
        val dim = overlay.getChildAt(0)
        val h = storedSheetH.toFloat()
        sheetPanel.animate().translationY(h).setDuration(280).withEndAction {
            if (isAdded) rootView.removeView(overlay)
            sheetOverlay = null
        }.start()
        dim?.animate()?.alpha(0f)?.setDuration(280)?.start()
    }

    private fun checkForUpdates(ctx: Context, dp: Float) {
        updateBtn.isEnabled = false
        updateBtn.text = "Проверяю..."
        startButtonShimmer()
        updateStatus.text = "Подключаюсь к GitHub..."
        progressBar.isIndeterminate = true
        progressBar.visibility = View.VISIBLE

        executor.execute {
            try {
                val url = "https://api.github.com/repos/$GITHUB_OWNER/$GITHUB_REPO/releases/latest"
                val conn = URL(url).openConnection() as HttpURLConnection
                conn.setRequestProperty("Accept", "application/vnd.github.v3+json")
                conn.connectTimeout = 8000
                conn.readTimeout = 8000
                val code = conn.responseCode
                if (code == 404) {
                    conn.disconnect()
                    handler.post {
                        if (!isAdded) return@post
                        progressBar.isIndeterminate = false
                        progressBar.visibility = View.GONE
                        stopButtonShimmer()
                        updateStatus.setTextColor(Color.parseColor(AppTheme.current.textSecondary))
                        updateStatus.text = "У вас последняя версия ($CURRENT_VERSION)\nОбновлений пока нет"
                        updateBtn.isEnabled = true
                        updateBtn.text = "Проверить ещё раз"
                        updateBtn.setOnClickListener { checkForUpdates(ctx, dp) }
                    }
                    return@execute
                }
                val json = JSONObject(conn.inputStream.bufferedReader().readText())
                conn.disconnect()

                val tagName     = json.getString("tag_name").trimStart('v', 'V')
                val releaseName = json.optString("name", "v$tagName")
                val body        = json.optString("body", "Нет описания")
                val assets      = json.optJSONArray("assets")
                var apkUrl      = ""
                var apkSize     = 0L
                if (assets != null) {
                    for (i in 0 until assets.length()) {
                        val asset = assets.getJSONObject(i)
                        if (asset.getString("name").endsWith(".apk")) {
                            apkUrl  = asset.getString("browser_download_url")
                            apkSize = asset.getLong("size")
                            break
                        }
                    }
                }

                val hasUpdate = isNewerVersion(tagName, CURRENT_VERSION)
                val finalUrl  = apkUrl
                val finalSize = apkSize
                val finalBody = body
                val finalTag  = releaseName

                handler.post {
                    if (!isAdded) return@post
                    progressBar.isIndeterminate = false
                    progressBar.visibility = View.GONE
                    stopButtonShimmer()

                    if (hasUpdate) {
                        updateStatus.setTextColor(Color.parseColor(AppTheme.current.accent))
                        updateStatus.text = "Доступно обновление: $finalTag\n\n$finalBody"
                        if (finalUrl.isNotEmpty()) {
                            updateBtn.isEnabled = true
                            updateBtn.text = "Скачать и установить"
                            updateBtn.setOnClickListener { downloadAndInstall(ctx, finalUrl, finalSize, dp) }
                            showBottomSheet(finalTag, finalBody, "Скачать") {
                                downloadAndInstall(ctx, finalUrl, finalSize, dp)
                            }
                        } else {
                            updateBtn.isEnabled = true
                            updateBtn.text = "Открыть страницу релиза"
                            updateBtn.setOnClickListener {
                                startActivity(Intent(Intent.ACTION_VIEW,
                                    Uri.parse("https://github.com/$GITHUB_OWNER/$GITHUB_REPO/releases/latest")))
                            }
                            showBottomSheet(finalTag, finalBody, "Открыть") {
                                startActivity(Intent(Intent.ACTION_VIEW,
                                    Uri.parse("https://github.com/$GITHUB_OWNER/$GITHUB_REPO/releases/latest")))
                            }
                        }
                    } else {
                        updateStatus.setTextColor(Color.parseColor(AppTheme.current.textSecondary))
                        updateStatus.text = "✓  У вас последняя версия ($CURRENT_VERSION)"
                        updateBtn.isEnabled = true
                        updateBtn.text = "Проверить ещё раз"
                        updateBtn.setOnClickListener { checkForUpdates(ctx, dp) }
                    }
                }
            } catch (_: Exception) {
                handler.post {
                    if (!isAdded) return@post
                    progressBar.isIndeterminate = false
                    progressBar.visibility = View.GONE
                    stopButtonShimmer()
                    updateStatus.setTextColor(Color.parseColor("#FF6B6B"))
                    updateStatus.text = "Не удалось подключиться к GitHub"
                    updateBtn.isEnabled = true
                    updateBtn.text = "Попробовать снова"
                    updateBtn.setOnClickListener { checkForUpdates(ctx, dp) }
                }
            }
        }
    }

    private fun downloadAndInstall(ctx: Context, apkUrl: String, totalSize: Long, dp: Float) {
        updateBtn.isEnabled = false
        updateBtn.text = "Скачиваю..."
        startDownloadShimmer()
        progressBar.progress = 0
        progressBar.visibility = View.VISIBLE
        updateStatus.setTextColor(Color.parseColor(AppTheme.current.textSecondary))
        updateStatus.text = "Загрузка..."

        executor.execute {
            try {
                val outFile = File(ctx.cacheDir, "eos_update.apk")
                val conn = URL(apkUrl).openConnection() as HttpURLConnection
                conn.connectTimeout = 10000
                conn.readTimeout = 60000
                conn.connect()
                val input  = conn.inputStream
                val output = FileOutputStream(outFile)
                val buf    = ByteArray(8192)
                var downloaded = 0L
                var bytes: Int
                while (input.read(buf).also { bytes = it } != -1) {
                    output.write(buf, 0, bytes)
                    downloaded += bytes
                    val pct = if (totalSize > 0) (downloaded * 100 / totalSize).toInt() else 0
                    handler.post {
                        if (!isAdded) return@post
                        progressBar.progress = pct
                        updateStatus.text = "Загрузка: $pct%  (${downloaded / 1024} КБ)"
                    }
                }
                output.close(); input.close(); conn.disconnect()

                handler.post {
                    if (!isAdded) return@post
                    stopDownloadShimmer()
                    progressBar.visibility = View.GONE
                    updateStatus.text = "Загрузка завершена. Запускаю установщик..."
                    installApk(ctx, outFile)
                }
            } catch (e: Exception) {
                handler.post {
                    if (!isAdded) return@post
                    stopDownloadShimmer()
                    progressBar.visibility = View.GONE
                    updateStatus.setTextColor(Color.parseColor("#FF6B6B"))
                    updateStatus.text = "Ошибка загрузки: ${e.message}"
                    updateBtn.isEnabled = true
                    updateBtn.text = "Попробовать снова"
                    updateBtn.setOnClickListener { downloadAndInstall(ctx, apkUrl, totalSize, dp) }
                }
            }
        }
    }

    private fun installApk(ctx: Context, file: File) {
        val uri = FileProvider.getUriForFile(ctx, "${ctx.packageName}.fileprovider", file)
        val intent = Intent(Intent.ACTION_INSTALL_PACKAGE).apply {
            setDataAndType(uri, "application/vnd.android.package-archive")
            flags = Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_ACTIVITY_NEW_TASK
        }
        ctx.startActivity(intent)
    }

    private fun isNewerVersion(remote: String, current: String): Boolean {
        val rParts = remote.split(".").mapNotNull { it.trim().toIntOrNull() }
        val cParts = current.split(".").mapNotNull { it.trim().toIntOrNull() }
        val len = maxOf(rParts.size, cParts.size)
        for (i in 0 until len) {
            val r = rParts.getOrElse(i) { 0 }
            val c = cParts.getOrElse(i) { 0 }
            if (r > c) return true
            if (r < c) return false
        }
        return false
    }

    // ── helpers ───────────────────────────────────────────────────────────────

    private fun creatorCard(ctx: Context, t: ThemeDef, dp: Float): LinearLayout {
        val avaSize    = (46 * dp).toInt()
        val prefs      = ctx.getSharedPreferences("traffic_prefs", Context.MODE_PRIVATE)
        val senderName = prefs.getString("profile_name", "")?.takeIf { it.isNotBlank() } ?: "Ekkir"
        val srvUrl     = prefs.getString("server_url", "http://eos-traffic.ddns.net:5000")!!

        fun makePlaceholder(): Bitmap {
            val b = Bitmap.createBitmap(avaSize, avaSize, Bitmap.Config.ARGB_8888)
            val c = Canvas(b); val p = Paint(Paint.ANTI_ALIAS_FLAG)
            p.color = Color.parseColor(t.accent)
            c.drawCircle(avaSize / 2f, avaSize / 2f, avaSize / 2f, p)
            p.color = Color.parseColor(t.bg); p.textSize = avaSize * 0.44f
            p.textAlign = Paint.Align.CENTER; p.typeface = Typeface.DEFAULT_BOLD
            c.drawText("E", avaSize / 2f, avaSize / 2f + p.textSize / 3f, p)
            return b
        }

        val avatarView = ImageView(ctx).apply {
            setImageBitmap(makePlaceholder())
            scaleType = ImageView.ScaleType.CENTER_CROP
            clipToOutline = true
            outlineProvider = object : ViewOutlineProvider() {
                override fun getOutline(v: View, outline: android.graphics.Outline) {
                    outline.setOval(0, 0, v.width, v.height)
                }
            }
            layoutParams = LinearLayout.LayoutParams(avaSize, avaSize).apply {
                marginEnd = (12 * dp).toInt()
            }
        }

        executor.execute {
            try {
                val avatarFile = File(ctx.filesDir, "avatar.jpg")
                if (avatarFile.exists()) {
                    val boundary = "----Boundary${System.currentTimeMillis()}"
                    val conn = URL("$srvUrl/avatar").openConnection() as HttpURLConnection
                    conn.requestMethod = "POST"; conn.doOutput = true
                    conn.setRequestProperty("Content-Type", "multipart/form-data; boundary=$boundary")
                    conn.connectTimeout = 8000; conn.readTimeout = 8000
                    val out = conn.outputStream
                    out.write("--$boundary\r\nContent-Disposition: form-data; name=\"sender\"\r\n\r\n$senderName\r\n".toByteArray())
                    out.write("--$boundary\r\nContent-Disposition: form-data; name=\"file\"; filename=\"avatar.jpg\"\r\nContent-Type: image/jpeg\r\n\r\n".toByteArray())
                    out.write(avatarFile.readBytes())
                    out.write("\r\n--$boundary--\r\n".toByteArray())
                    out.flush(); conn.responseCode; conn.disconnect()
                }
                val raw = BitmapFactory.decodeStream(URL("$srvUrl/avatar/$senderName").openStream())
                if (raw != null) {
                    val circular = Bitmap.createBitmap(avaSize, avaSize, Bitmap.Config.ARGB_8888)
                    val c = Canvas(circular); val p = Paint(Paint.ANTI_ALIAS_FLAG)
                    p.shader = BitmapShader(Bitmap.createScaledBitmap(raw, avaSize, avaSize, true), Shader.TileMode.CLAMP, Shader.TileMode.CLAMP)
                    c.drawCircle(avaSize / 2f, avaSize / 2f, avaSize / 2f, p)
                    handler.post { if (isAdded) avatarView.setImageBitmap(circular) }
                }
            } catch (_: Exception) {}
        }

        return LinearLayout(ctx).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            setPadding((16 * dp).toInt(), (14 * dp).toInt(), (16 * dp).toInt(), (14 * dp).toInt())
            background = cardDrawable(t, 16f, dp)
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT
            ).apply { bottomMargin = (10 * dp).toInt() }
            addView(avatarView)
            val textCol = LinearLayout(ctx).apply {
                orientation = LinearLayout.VERTICAL
                layoutParams = LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f)
            }
            textCol.addView(TextView(ctx).apply {
                text = "Создатель"; textSize = 13f; typeface = Typeface.DEFAULT_BOLD
                setTextColor(Color.parseColor(t.textSecondary))
                setPadding(0, 0, 0, (3 * dp).toInt())
            })
            textCol.addView(TextView(ctx).apply {
                text = "Ekkir"; textSize = 14f
                setTextColor(Color.parseColor(t.textPrimary))
            })
            addView(textCol)
        }
    }

    private fun infoCard(ctx: Context, t: ThemeDef, dp: Float, icon: String, title: String, body: String): LinearLayout {
        return LinearLayout(ctx).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.TOP
            setPadding((16 * dp).toInt(), (14 * dp).toInt(), (16 * dp).toInt(), (14 * dp).toInt())
            background = cardDrawable(t, 16f, dp)
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT
            ).apply { bottomMargin = (10 * dp).toInt() }

            addView(TextView(ctx).apply {
                text = icon; textSize = 20f; gravity = Gravity.CENTER
                layoutParams = LinearLayout.LayoutParams((36 * dp).toInt(), (36 * dp).toInt()).apply {
                    marginEnd = (12 * dp).toInt()
                }
            })
            val textCol = LinearLayout(ctx).apply {
                orientation = LinearLayout.VERTICAL
                layoutParams = LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f)
            }
            textCol.addView(TextView(ctx).apply {
                text = title; textSize = 13f; typeface = Typeface.DEFAULT_BOLD
                setTextColor(Color.parseColor(t.textSecondary))
                setPadding(0, 0, 0, (3 * dp).toInt())
            })
            textCol.addView(TextView(ctx).apply {
                text = body; textSize = 14f
                setTextColor(Color.parseColor(t.textPrimary))
            })
            addView(textCol)
        }
    }

    private fun sectionLabel(ctx: Context, text: String, t: ThemeDef, dp: Float) = TextView(ctx).apply {
        this.text = text; textSize = 11f; letterSpacing = 0.15f; typeface = Typeface.DEFAULT_BOLD
        setTextColor(Color.parseColor(t.textSecondary))
    }

    private fun spacer(ctx: Context, dp: Float, h: Float) = View(ctx).apply {
        layoutParams = LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, (h * dp).toInt())
    }
}
