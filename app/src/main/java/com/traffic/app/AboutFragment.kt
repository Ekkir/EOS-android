package com.traffic.app

import android.content.Context
import android.content.Intent
import android.graphics.Color
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
        const val CURRENT_VERSION = "1.1"
    }

    private val handler  = Handler(Looper.getMainLooper())
    private val executor = Executors.newSingleThreadExecutor()

    private lateinit var updateCard: LinearLayout
    private lateinit var updateStatus: TextView
    private lateinit var updateBtn: Button
    private lateinit var progressBar: ProgressBar
    private lateinit var bottomSheet: LinearLayout

    override fun onCreateView(inflater: LayoutInflater, container: ViewGroup?, savedInstanceState: Bundle?): View {
        val ctx = requireContext()
        val t   = AppTheme.current
        val dp  = ctx.resources.displayMetrics.density

        val scroll = ScrollView(ctx).apply { setBackgroundColor(Color.parseColor(t.bg)) }
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
        logoCard.addView(TextView(ctx).apply {
            text = "EOS"; textSize = 42f; typeface = Typeface.DEFAULT_BOLD
            setTextColor(Color.parseColor(t.accent))
            gravity = Gravity.CENTER_HORIZONTAL
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

        // ── Описание ──────────────────────────────────────────────────────────
        layout.addView(infoCard(ctx, t, dp,
            "📋", "Описание",
            "Система мониторинга светофоров в реальном времени. Показывает состояние перекрёстков, карту и позволяет настраивать тайминги."
        ))
        layout.addView(spacer(ctx, dp, 12f))

        layout.addView(infoCard(ctx, t, dp,
            "🔗", "Репозиторий",
            "github.com/$GITHUB_OWNER/$GITHUB_REPO"
        ).also { card ->
            card.isClickable = true; card.isFocusable = true
            card.setOnClickListener {
                startActivity(Intent(Intent.ACTION_VIEW,
                    Uri.parse("https://github.com/$GITHUB_OWNER/$GITHUB_REPO")))
            }
        })
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

        // ── Плашка снизу ──────────────────────────────────────────────────────
        val root = android.widget.FrameLayout(ctx).apply {
            layoutParams = ViewGroup.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT
            )
        }
        root.addView(scroll)

        bottomSheet = LinearLayout(ctx).apply {
            orientation = LinearLayout.VERTICAL
            setPadding((20 * dp).toInt(), (16 * dp).toInt(), (20 * dp).toInt(), (20 * dp).toInt())
            background = GradientDrawable().apply {
                shape = GradientDrawable.RECTANGLE
                cornerRadii = floatArrayOf(24f * dp, 24f * dp, 24f * dp, 24f * dp, 0f, 0f, 0f, 0f)
                setColor(Color.parseColor(t.nav))
                setStroke(1, Color.parseColor(t.cardBorder))
            }
            elevation = (16 * dp)
            visibility = View.GONE
            layoutParams = android.widget.FrameLayout.LayoutParams(
                android.widget.FrameLayout.LayoutParams.MATCH_PARENT,
                android.widget.FrameLayout.LayoutParams.WRAP_CONTENT
            ).apply { gravity = Gravity.BOTTOM }
        }

        val sheetRow = LinearLayout(ctx).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            setPadding(0, 0, 0, (10 * dp).toInt())
        }
        val sheetIcon = TextView(ctx).apply {
            text = "🆕"; textSize = 22f; gravity = Gravity.CENTER
            layoutParams = LinearLayout.LayoutParams((36 * dp).toInt(), (36 * dp).toInt()).apply {
                marginEnd = (12 * dp).toInt()
            }
        }
        val sheetTexts = LinearLayout(ctx).apply {
            orientation = LinearLayout.VERTICAL
            layoutParams = LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f)
        }
        val sheetTitle = TextView(ctx).apply {
            text = "Доступно обновление"; textSize = 15f; typeface = Typeface.DEFAULT_BOLD
            setTextColor(Color.parseColor(t.accent))
        }
        val sheetBody = TextView(ctx).apply {
            textSize = 13f; setTextColor(Color.parseColor(t.textSecondary))
        }
        val sheetClose = TextView(ctx).apply {
            text = "✕"; textSize = 18f; gravity = Gravity.CENTER
            setTextColor(Color.parseColor(t.textSecondary))
            layoutParams = LinearLayout.LayoutParams((40 * dp).toInt(), (40 * dp).toInt())
            setOnClickListener { hideBottomSheet() }
        }
        sheetTexts.addView(sheetTitle)
        sheetTexts.addView(sheetBody)
        sheetRow.addView(sheetIcon)
        sheetRow.addView(sheetTexts)
        sheetRow.addView(sheetClose)
        bottomSheet.addView(sheetRow)

        val sheetBtn = Button(ctx).apply {
            textSize = 15f; isAllCaps = false; typeface = Typeface.DEFAULT_BOLD
            setTextColor(Color.parseColor(t.bg))
            background = GradientDrawable().apply {
                shape = GradientDrawable.RECTANGLE; cornerRadius = 12f * dp
                setColor(Color.parseColor(t.accent))
            }
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT, (52 * dp).toInt()
            )
        }
        bottomSheet.addView(sheetBtn)

        root.addView(bottomSheet)

        // Сохраняем ссылки для использования в checkForUpdates
        bottomSheet.tag = Triple(sheetTitle, sheetBody, sheetBtn)

        return root
    }

    override fun onDestroyView() {
        super.onDestroyView()
        handler.removeCallbacksAndMessages(null)
        executor.shutdown()
    }

    private fun showBottomSheet(version: String, summary: String, actionLabel: String, onAction: () -> Unit) {
        @Suppress("UNCHECKED_CAST")
        val tag = bottomSheet.tag as Triple<TextView, TextView, Button>
        val (title, body, btn) = tag
        title.text = "Доступно обновление $version"
        body.text  = summary.lines().firstOrNull { it.isNotBlank() }?.take(80) ?: summary.take(80)
        btn.text   = actionLabel
        btn.setOnClickListener { onAction() }

        bottomSheet.visibility = View.VISIBLE
        bottomSheet.measure(
            View.MeasureSpec.makeMeasureSpec(0, View.MeasureSpec.UNSPECIFIED),
            View.MeasureSpec.makeMeasureSpec(0, View.MeasureSpec.UNSPECIFIED)
        )
        val h = bottomSheet.measuredHeight.toFloat()
        bottomSheet.translationY = h
        bottomSheet.animate()
            .translationY(0f)
            .setDuration(320)
            .setInterpolator(DecelerateInterpolator())
            .start()
    }

    private fun hideBottomSheet() {
        val h = bottomSheet.height.toFloat()
        bottomSheet.animate()
            .translationY(h)
            .setDuration(260)
            .setInterpolator(DecelerateInterpolator())
            .withEndAction { bottomSheet.visibility = View.GONE }
            .start()
    }

    private fun checkForUpdates(ctx: Context, dp: Float) {
        updateBtn.isEnabled = false
        updateBtn.text = "Проверяю..."
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
                    progressBar.visibility = View.GONE
                    updateStatus.text = "Загрузка завершена. Запускаю установщик..."
                    installApk(ctx, outFile)
                }
            } catch (e: Exception) {
                handler.post {
                    if (!isAdded) return@post
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
