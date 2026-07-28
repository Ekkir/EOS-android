package com.traffic.app

import android.content.Context
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Color
import android.graphics.Outline
import android.graphics.Typeface
import android.graphics.drawable.ColorDrawable
import android.graphics.drawable.GradientDrawable
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.view.Gravity
import android.view.View
import android.view.ViewOutlineProvider
import android.view.animation.DecelerateInterpolator
import android.widget.*
import androidx.work.*
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL
import java.util.concurrent.TimeUnit
import androidx.appcompat.app.AppCompatActivity
import androidx.core.view.GravityCompat
import androidx.core.view.ViewCompat
import androidx.core.view.WindowInsetsCompat
import androidx.drawerlayout.widget.DrawerLayout
import androidx.fragment.app.Fragment
import java.io.File

data class Section(val id: String, val icon: String, val label: String, val create: () -> Fragment)

interface SectionNavigator {
    fun showSection(id: String)
}

class MainActivity : AppCompatActivity(), SectionNavigator {

    private val sections = listOf(
        Section("home",    "🏠", "Главная")   { HomeFragment() },
        Section("traffic", "🚦", "Светофоры") { TrafficFragment() },
        Section("map",     "🗺",  "Карта")     { MapFragment() },
        Section("cameras", "📷", "Камеры")    { PlaceholderFragment.new("📷", "Камеры") },
        Section("calib",   "⚙️", "Настройки") { SettingsFragment() },
    )

    private var activeIndex = 0
    private lateinit var avatarView: ImageView
    private lateinit var drawerLayout: DrawerLayout
    private lateinit var drawerPanel: LinearLayout

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        AppTheme.load(this)
        setContentView(R.layout.activity_main)

        drawerLayout = findViewById(R.id.drawerLayout)

        val t = AppTheme.current
        findViewById<LinearLayout>(R.id.appHeader).setBackgroundColor(Color.parseColor(t.nav))
        findViewById<FrameLayout>(R.id.rootLayout).background = bgDrawable(t)

        buildHeader()
        buildDrawer()
        applyInsets()

        val prefs = getSharedPreferences("traffic_prefs", Context.MODE_PRIVATE)
        if (!prefs.getBoolean("theme_chosen", false)) {
            showThemePickerSheet()
        }
        scheduleUpdateCheck()
        checkForUpdatesOnStart()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            if (checkSelfPermission(android.Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) {
                requestPermissions(arrayOf(android.Manifest.permission.POST_NOTIFICATIONS), 1)
            }
        }
        EosFirebaseService.createNotificationChannel(this)
        com.google.firebase.messaging.FirebaseMessaging.getInstance().token
            .addOnSuccessListener { token ->
                getSharedPreferences("traffic_prefs", Context.MODE_PRIVATE)
                    .edit().putString("fcm_token", token).apply()
                EosFirebaseService.sendTokenToServer(this)
            }

        if (savedInstanceState == null) {
            val initTx = supportFragmentManager.beginTransaction()
            sections.forEach { s ->
                val f = s.create()
                initTx.add(R.id.fragmentContainer, f, s.id).hide(f)
            }
            initTx.commitNow()
            showTab(0)
        }
    }

    private fun buildHeader() {
        val dp           = resources.displayMetrics.density
        val avatarSize   = (54 * dp).toInt()
        val headerHeight = (64 * dp).toInt()
        val t            = AppTheme.current

        val header = findViewById<LinearLayout>(R.id.appHeader)

        // Левый спейсер — место под аватар
        header.addView(View(this).apply {
            layoutParams = LinearLayout.LayoutParams(avatarSize + (20 * dp).toInt(), 1)
        })

        val titleCol = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER_HORIZONTAL
            layoutParams = LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f)
        }
        titleCol.addView(TextView(this).apply {
            text = "EOS"; textSize = 22f; typeface = Typeface.DEFAULT_BOLD
            setTextColor(Color.parseColor(t.textPrimary))
            gravity = Gravity.CENTER_HORIZONTAL
        })
        titleCol.addView(TextView(this).apply {
            text = "SYSTEM"; textSize = 9f; letterSpacing = 0.3f; typeface = Typeface.DEFAULT_BOLD
            setTextColor(Color.parseColor(t.accent))
            gravity = Gravity.CENTER_HORIZONTAL
        })
        header.addView(titleCol)

        // Правый спейсер (симметрия)
        header.addView(View(this).apply {
            layoutParams = LinearLayout.LayoutParams(avatarSize + (20 * dp).toInt(), 1)
        })

        // Аватар в корневом FrameLayout — поверх всего, тап открывает drawer
        val root = findViewById<FrameLayout>(R.id.rootLayout)
        avatarView = ImageView(this).apply {
            scaleType = ImageView.ScaleType.CENTER_CROP
            clipToOutline = true
            outlineProvider = object : ViewOutlineProvider() {
                override fun getOutline(v: View, outline: Outline) { outline.setOval(0, 0, v.width, v.height) }
            }
            background = ColorDrawable(hexAlpha(t.accent, 30))
            elevation = (8 * dp)
        }
        avatarView.setOnClickListener { drawerLayout.openDrawer(GravityCompat.START) }
        root.addView(avatarView, FrameLayout.LayoutParams(avatarSize, avatarSize).apply {
            gravity = Gravity.TOP or Gravity.START
            topMargin   = headerHeight - avatarSize / 3
            marginStart = (16 * dp).toInt()
        })

        reloadAvatar()
    }

    private fun buildDrawer() {
        val dp = resources.displayMetrics.density
        val t  = AppTheme.current
        val drawerWidth = (280 * dp).toInt()

        val scroll = ScrollView(this).apply {
            setBackgroundColor(Color.parseColor(t.nav))
        }

        drawerPanel = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(0, (56 * dp).toInt(), 0, (24 * dp).toInt())
        }
        val panel = drawerPanel

        // ── Профиль ──────────────────────────────
        val prefs = getSharedPreferences("traffic_prefs", Context.MODE_PRIVATE)
        val profileName = prefs.getString("profile_name", "")?.takeIf { it.isNotBlank() } ?: "Профиль"

        val profileRow = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            setPadding((20 * dp).toInt(), (8 * dp).toInt(), (20 * dp).toInt(), (20 * dp).toInt())
            isClickable = true; isFocusable = true
        }
        val miniAvatarSize = (48 * dp).toInt()
        val miniAvatar = ImageView(this).apply {
            scaleType = ImageView.ScaleType.CENTER_CROP
            clipToOutline = true
            outlineProvider = object : ViewOutlineProvider() {
                override fun getOutline(v: View, outline: Outline) { outline.setOval(0, 0, v.width, v.height) }
            }
            background = ColorDrawable(hexAlpha(t.accent, 30))
            layoutParams = LinearLayout.LayoutParams(miniAvatarSize, miniAvatarSize)
        }
        loadAvatarBitmap(this)?.let { miniAvatar.setImageBitmap(it) }
        profileRow.addView(miniAvatar)

        val nameCol = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding((14 * dp).toInt(), 0, 0, 0)
        }
        nameCol.addView(TextView(this).apply {
            text = profileName; textSize = 15f; typeface = Typeface.DEFAULT_BOLD
            setTextColor(Color.parseColor(t.textPrimary))
        })
        nameCol.addView(TextView(this).apply {
            text = "EOS"; textSize = 12f
            setTextColor(Color.parseColor(t.textSecondary))
        })
        profileRow.addView(nameCol)
        profileRow.setOnClickListener {
            drawerLayout.closeDrawer(GravityCompat.START)
            openProfile()
        }
        panel.addView(profileRow)

        // Разделитель
        panel.addView(View(this).apply {
            setBackgroundColor(Color.parseColor(t.cardBorder))
            layoutParams = LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, 1).apply {
                setMargins((20 * dp).toInt(), 0, (20 * dp).toInt(), (8 * dp).toInt())
            }
        })

        // ── НАВИГАЦИЯ ────────────────────────────
        panel.addView(makeSectionLabel("НАВИГАЦИЯ", dp, t))
        sections.forEachIndexed { i, s ->
            panel.addView(makeDrawerItem(s.icon, s.label, dp, t) {
                drawerLayout.closeDrawer(GravityCompat.START)
                showTab(i)
            })
        }

        // Разделитель
        panel.addView(View(this).apply {
            setBackgroundColor(Color.parseColor(t.cardBorder))
            layoutParams = LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, 1).apply {
                setMargins((20 * dp).toInt(), (8 * dp).toInt(), (20 * dp).toInt(), (8 * dp).toInt())
            }
        })

        // ── ОБЩЕНИЕ ──────────────────────────────
        panel.addView(makeSectionLabel("ОБЩЕНИЕ", dp, t))
        panel.addView(makeDrawerItem("💬", "Мессенджер", dp, t) {
            drawerLayout.closeDrawer(GravityCompat.START)
            openMessenger()
        })

        // Разделитель
        panel.addView(View(this).apply {
            setBackgroundColor(Color.parseColor(t.cardBorder))
            layoutParams = LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, 1).apply {
                setMargins((20 * dp).toInt(), (8 * dp).toInt(), (20 * dp).toInt(), (8 * dp).toInt())
            }
        })

        // ── О ПРИЛОЖЕНИИ ─────────────────────────
        panel.addView(makeDrawerItem("ℹ️", "О приложении", dp, t) {
            drawerLayout.closeDrawer(GravityCompat.START)
            openAbout()
        })

        scroll.addView(panel)

        val params = DrawerLayout.LayoutParams(drawerWidth, DrawerLayout.LayoutParams.MATCH_PARENT)
        params.gravity = Gravity.START
        drawerLayout.addView(scroll, params)
    }

    private fun makeSectionLabel(text: String, dp: Float, t: ThemeDef) = TextView(this).apply {
        this.text = text; textSize = 10f; typeface = Typeface.DEFAULT_BOLD
        letterSpacing = 0.15f
        setTextColor(Color.parseColor(t.textSecondary))
        setPadding((20 * dp).toInt(), (8 * dp).toInt(), (20 * dp).toInt(), (6 * dp).toInt())
    }

    private fun makeDrawerItem(icon: String, label: String, dp: Float, t: ThemeDef, onClick: () -> Unit): LinearLayout {
        return LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            setPadding((16 * dp).toInt(), (10 * dp).toInt(), (16 * dp).toInt(), (10 * dp).toInt())
            isClickable = true; isFocusable = true
            setOnClickListener { onClick() }

            val boxSize = (36 * dp).toInt()
            addView(TextView(this@MainActivity).apply {
                text = icon; textSize = 16f; gravity = Gravity.CENTER
                layoutParams = LinearLayout.LayoutParams(boxSize, boxSize)
                background = accentBox(t, dp, 8f)
            })
            addView(TextView(this@MainActivity).apply {
                text = label; textSize = 15f
                setTextColor(Color.parseColor(t.textPrimary))
                setPadding((14 * dp).toInt(), 0, 0, 0)
            })
        }
    }

    private fun applyInsets() {
        val dp = resources.displayMetrics.density
        ViewCompat.setOnApplyWindowInsetsListener(drawerLayout) { _, insets ->
            val bars      = insets.getInsets(WindowInsetsCompat.Type.systemBars())
            val headerH   = (64 * dp).toInt()
            val pad       = (16 * dp).toInt()
            val avatarSize = (44 * dp).toInt()

            // Шапка: растягиваем под статус-бар
            val header = findViewById<LinearLayout>(R.id.appHeader)
            header.layoutParams = (header.layoutParams as LinearLayout.LayoutParams).also {
                it.height = headerH + bars.top
            }
            header.setPadding(pad, bars.top, pad, 0)

            // Аватар: центрируем вертикально в контентной части шапки (ниже статус-бара)
            avatarView.layoutParams = (avatarView.layoutParams as FrameLayout.LayoutParams).also {
                it.width      = avatarSize
                it.height     = avatarSize
                it.topMargin  = bars.top + (4 * dp).toInt()
                it.marginStart = (16 * dp).toInt()
            }

            // Ящик меню: сдвигаем содержимое ниже статус-бара
            drawerPanel.setPadding(0, (16 * dp).toInt() + bars.top, 0, (24 * dp).toInt())

            WindowInsetsCompat.CONSUMED
        }
    }

    fun reloadAvatar() {
        val bmp = loadAvatarBitmap(this)
        val t = AppTheme.current
        if (bmp != null) avatarView.setImageBitmap(bmp)
        else {
            avatarView.setImageDrawable(null)
            avatarView.background = ColorDrawable(hexAlpha(t.accent, 30))
        }
    }

    fun setAvatarVisible(visible: Boolean) {
        avatarView.visibility = if (visible) View.VISIBLE else View.GONE
    }

    fun openDrawer() = drawerLayout.openDrawer(GravityCompat.START)

    fun hideMainChrome() {
        findViewById<View>(R.id.appHeader).visibility = View.GONE
        avatarView.visibility = View.GONE
    }

    fun showMainChrome() {
        findViewById<View>(R.id.appHeader).visibility = View.VISIBLE
        avatarView.visibility = View.VISIBLE
    }

    fun openProfile() {
        if (supportFragmentManager.findFragmentByTag("profile") != null) return
        hideMainChrome()
        supportFragmentManager.beginTransaction()
            .add(R.id.fragmentContainer, ProfileFragment(), "profile")
            .addToBackStack("profile")
            .commit()
    }

    fun openMessenger() {
        if (supportFragmentManager.findFragmentByTag("chatlist") != null) return
        hideMainChrome()
        supportFragmentManager.beginTransaction()
            .add(R.id.fragmentContainer, ChatListFragment(), "chatlist")
            .addToBackStack("chatlist")
            .commit()
    }

    fun openAbout() {
        if (supportFragmentManager.findFragmentByTag("about") != null) return
        hideMainChrome()
        supportFragmentManager.beginTransaction()
            .add(R.id.fragmentContainer, AboutFragment(), "about")
            .addToBackStack("about")
            .commit()
    }

    override fun onBackPressed() {
        when {
            drawerLayout.isDrawerOpen(GravityCompat.START) ->
                drawerLayout.closeDrawer(GravityCompat.START)
            supportFragmentManager.backStackEntryCount > 0 -> {
                supportFragmentManager.popBackStack()
                showMainChrome()
            }
            else -> super.onBackPressed()
        }
    }

    override fun showSection(id: String) {
        val index = sections.indexOfFirst { it.id == id }
        if (index >= 0) showTab(index)
    }

    fun showTab(index: Int) {
        while (supportFragmentManager.backStackEntryCount > 0) {
            supportFragmentManager.popBackStackImmediate()
        }
        showMainChrome()
        val fm = supportFragmentManager
        val tx = fm.beginTransaction()
        sections.forEach { s -> fm.findFragmentByTag(s.id)?.let { tx.hide(it) } }
        var target = fm.findFragmentByTag(sections[index].id)
        if (target == null) {
            target = sections[index].create()
            tx.add(R.id.fragmentContainer, target, sections[index].id)
        } else {
            tx.show(target)
        }
        tx.commit()
        activeIndex = index
    }

    private fun checkForUpdatesOnStart() {
        val prefs = getSharedPreferences("traffic_prefs", Context.MODE_PRIVATE)
        if (!prefs.getBoolean("theme_chosen", false)) return
        val handler = Handler(Looper.getMainLooper())
        Thread {
            try {
                val url = "https://api.github.com/repos/${AboutFragment.GITHUB_OWNER}/${AboutFragment.GITHUB_REPO}/releases/latest"
                val conn = URL(url).openConnection() as HttpURLConnection
                conn.setRequestProperty("Accept", "application/vnd.github.v3+json")
                conn.connectTimeout = 8000; conn.readTimeout = 8000
                if (conn.responseCode == 404) { conn.disconnect(); return@Thread }
                val json = JSONObject(conn.inputStream.bufferedReader().readText())
                conn.disconnect()
                val tagName = json.getString("tag_name").trimStart('v', 'V')
                val body    = json.optString("body", "")
                val assets  = json.optJSONArray("assets")
                var apkUrl  = ""
                if (assets != null) {
                    for (i in 0 until assets.length()) {
                        val a = assets.getJSONObject(i)
                        if (a.getString("name").endsWith(".apk")) { apkUrl = a.getString("browser_download_url"); break }
                    }
                }
                if (isNewerVersion(tagName, AboutFragment.CURRENT_VERSION)) {
                    val finalUrl = apkUrl; val finalBody = body; val finalTag = tagName
                    handler.post { showUpdateSheet(finalTag, finalBody, finalUrl) }
                }
            } catch (_: Exception) {}
        }.start()
    }

    private fun isNewerVersion(remote: String, current: String): Boolean {
        val r = remote.split(".").mapNotNull { it.trim().toIntOrNull() }
        val c = current.split(".").mapNotNull { it.trim().toIntOrNull() }
        for (i in 0 until maxOf(r.size, c.size)) {
            val rv = r.getOrElse(i) { 0 }; val cv = c.getOrElse(i) { 0 }
            if (rv > cv) return true; if (rv < cv) return false
        }
        return false
    }

    private fun showUpdateSheet(version: String, body: String, apkUrl: String) {
        val aboutVisible = supportFragmentManager.findFragmentByTag("about")?.isVisible == true
            || supportFragmentManager.findFragmentByTag("about_settings")?.isVisible == true
        if (aboutVisible) return

        val dp = resources.displayMetrics.density
        val screenH = resources.displayMetrics.heightPixels
        val sheetH = (screenH * 0.82).toInt()
        val root = findViewById<FrameLayout>(R.id.rootLayout)
        val t = AppTheme.current

        val dim = View(this).apply {
            setBackgroundColor(Color.argb(170, 0, 0, 0)); alpha = 0f
            layoutParams = FrameLayout.LayoutParams(FrameLayout.LayoutParams.MATCH_PARENT, FrameLayout.LayoutParams.MATCH_PARENT)
        }
        root.addView(dim)
        dim.animate().alpha(1f).setDuration(300).start()

        val content = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding((20 * dp).toInt(), (16 * dp).toInt(), (20 * dp).toInt(), (32 * dp).toInt())
        }

        // Handle
        content.addView(FrameLayout(this).apply {
            layoutParams = LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, (24 * dp).toInt())
            addView(View(this@MainActivity).apply {
                background = GradientDrawable().apply { cornerRadius = 3 * dp; setColor(Color.argb(80, 255, 255, 255)) }
                layoutParams = FrameLayout.LayoutParams((44 * dp).toInt(), (4 * dp).toInt(), Gravity.CENTER)
            })
        })
        content.addView(TextView(this).apply {
            text = "🆕  Обновление v$version"; textSize = 22f; typeface = Typeface.DEFAULT_BOLD
            setTextColor(Color.parseColor(t.accent))
            setPadding(0, (8 * dp).toInt(), 0, (4 * dp).toInt())
        })
        content.addView(TextView(this).apply {
            text = "Доступна новая версия приложения"; textSize = 13f
            setTextColor(Color.argb(140, 255, 255, 255))
            setPadding(0, 0, 0, (16 * dp).toInt())
        })

        val notesScroll = ScrollView(this).apply {
            layoutParams = LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, 0, 1f)
        }
        notesScroll.addView(TextView(this).apply {
            text = body.ifBlank { "Нет описания" }; textSize = 14f
            setTextColor(Color.parseColor(t.textPrimary))
        })
        content.addView(notesScroll)

        var sheetRef: FrameLayout? = null
        content.addView(Button(this).apply {
            text = if (apkUrl.isNotEmpty()) "Скачать и установить" else "Открыть обновление"
            textSize = 17f; isAllCaps = false; typeface = Typeface.DEFAULT_BOLD
            setTextColor(Color.parseColor(t.bg))
            background = GradientDrawable().apply { cornerRadius = 14 * dp; setColor(Color.parseColor(t.accent)) }
            layoutParams = LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, (56 * dp).toInt()).apply {
                topMargin = (14 * dp).toInt()
            }
            setOnClickListener {
                val s = sheetRef ?: return@setOnClickListener
                s.animate().translationY(sheetH.toFloat()).setDuration(280).withEndAction {
                    root.removeView(dim); root.removeView(s)
                }.start()
                dim.animate().alpha(0f).setDuration(280).start()
                openAbout()
            }
        })

        val sheet = FrameLayout(this).apply {
            background = GradientDrawable().apply {
                shape = GradientDrawable.RECTANGLE
                cornerRadii = floatArrayOf(28 * dp, 28 * dp, 28 * dp, 28 * dp, 0f, 0f, 0f, 0f)
                setColor(Color.parseColor("#111116"))
            }
            translationY = sheetH.toFloat()
            layoutParams = FrameLayout.LayoutParams(FrameLayout.LayoutParams.MATCH_PARENT, sheetH).apply { gravity = Gravity.BOTTOM }
        }
        sheetRef = sheet
        sheet.addView(content, FrameLayout.LayoutParams(FrameLayout.LayoutParams.MATCH_PARENT, FrameLayout.LayoutParams.MATCH_PARENT))
        root.addView(sheet)

        dim.setOnClickListener {
            sheet.animate().translationY(sheetH.toFloat()).setDuration(280).withEndAction {
                root.removeView(dim); root.removeView(sheet)
            }.start()
            dim.animate().alpha(0f).setDuration(280).start()
        }
        sheet.animate().translationY(0f).setDuration(380).setInterpolator(DecelerateInterpolator(2f)).start()
    }

    private fun scheduleUpdateCheck() {
        val request = PeriodicWorkRequestBuilder<UpdateCheckWorker>(12, TimeUnit.HOURS)
            .setConstraints(Constraints.Builder().setRequiredNetworkType(NetworkType.CONNECTED).build())
            .build()
        WorkManager.getInstance(this).enqueueUniquePeriodicWork(
            "eos_update_check",
            ExistingPeriodicWorkPolicy.KEEP,
            request
        )
    }

    private fun showThemePickerSheet() {
        val dp = resources.displayMetrics.density
        val screenH = resources.displayMetrics.heightPixels
        val sheetH = (screenH * 0.90).toInt()
        val root = findViewById<FrameLayout>(R.id.rootLayout)
        val prefs = getSharedPreferences("traffic_prefs", Context.MODE_PRIVATE)

        val dim = View(this).apply {
            setBackgroundColor(Color.argb(170, 0, 0, 0))
            alpha = 0f
            layoutParams = FrameLayout.LayoutParams(FrameLayout.LayoutParams.MATCH_PARENT, FrameLayout.LayoutParams.MATCH_PARENT)
        }
        root.addView(dim)
        dim.animate().alpha(1f).setDuration(300).start()

        var selectedId = AppTheme.themes[0].id
        val themeCards = mutableListOf<LinearLayout>()

        val sheetScroll = ScrollView(this)
        val sheetContent = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding((20 * dp).toInt(), (16 * dp).toInt(), (20 * dp).toInt(), (32 * dp).toInt())
        }
        sheetScroll.addView(sheetContent)

        // Handle
        sheetContent.addView(FrameLayout(this).apply {
            layoutParams = LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, (24 * dp).toInt())
            addView(View(this@MainActivity).apply {
                background = GradientDrawable().apply { cornerRadius = 3 * dp; setColor(Color.argb(80, 255, 255, 255)) }
                layoutParams = FrameLayout.LayoutParams((44 * dp).toInt(), (4 * dp).toInt(), Gravity.CENTER)
            })
        })

        sheetContent.addView(TextView(this).apply {
            text = "Выберите тему"; textSize = 24f; typeface = Typeface.DEFAULT_BOLD
            setTextColor(Color.WHITE)
            setPadding(0, (8 * dp).toInt(), 0, (4 * dp).toInt())
        })
        sheetContent.addView(TextView(this).apply {
            text = "Можно изменить позже в Настройках"; textSize = 13f
            setTextColor(Color.argb(140, 255, 255, 255))
            setPadding(0, 0, 0, (20 * dp).toInt())
        })

        AppTheme.themes.forEachIndexed { i, theme ->
            val card = LinearLayout(this).apply {
                orientation = LinearLayout.HORIZONTAL
                gravity = Gravity.CENTER_VERTICAL
                setPadding((16 * dp).toInt(), (16 * dp).toInt(), (16 * dp).toInt(), (16 * dp).toInt())
                layoutParams = LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT).apply {
                    bottomMargin = (10 * dp).toInt()
                }
                background = GradientDrawable().apply {
                    cornerRadius = 16 * dp
                    setColor(Color.argb(30, 255, 255, 255))
                    setStroke(1, Color.argb(60, 255, 255, 255))
                }
                isClickable = true; isFocusable = true
            }
            themeCards.add(card)

            card.addView(View(this).apply {
                layoutParams = LinearLayout.LayoutParams((40 * dp).toInt(), (40 * dp).toInt()).apply { marginEnd = (14 * dp).toInt() }
                background = GradientDrawable().apply { shape = GradientDrawable.OVAL; setColor(Color.parseColor(theme.accent)) }
            })

            val texts = LinearLayout(this).apply {
                orientation = LinearLayout.VERTICAL
                layoutParams = LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f)
            }
            texts.addView(TextView(this).apply {
                text = theme.name; textSize = 17f; typeface = Typeface.DEFAULT_BOLD
                setTextColor(Color.WHITE)
            })
            val dotsRow = LinearLayout(this).apply {
                orientation = LinearLayout.HORIZONTAL
                setPadding(0, (4 * dp).toInt(), 0, 0)
            }
            listOf(theme.bg, theme.surface, theme.accent, theme.textPrimary).forEach { col ->
                dotsRow.addView(View(this).apply {
                    layoutParams = LinearLayout.LayoutParams((12 * dp).toInt(), (12 * dp).toInt()).apply { marginEnd = (4 * dp).toInt() }
                    background = GradientDrawable().apply {
                        shape = GradientDrawable.OVAL
                        val hex = if (col.length == 9) "#${col.substring(3)}" else col
                        try { setColor(Color.parseColor(hex)) } catch (_: Exception) { setColor(Color.DKGRAY) }
                    }
                })
            }
            texts.addView(dotsRow)
            card.addView(texts)

            val check = TextView(this).apply {
                text = "✓"; textSize = 18f; typeface = Typeface.DEFAULT_BOLD
                setTextColor(Color.parseColor(theme.accent))
                gravity = Gravity.CENTER
                layoutParams = LinearLayout.LayoutParams((32 * dp).toInt(), LinearLayout.LayoutParams.WRAP_CONTENT)
                visibility = View.INVISIBLE
            }
            card.addView(check)

            card.setOnClickListener {
                selectedId = theme.id
                themeCards.forEachIndexed { j, c ->
                    val th = AppTheme.themes[j]
                    val sel = th.id == selectedId
                    c.background = GradientDrawable().apply {
                        cornerRadius = 16 * dp
                        if (sel) { setColor(hexAlpha(th.accent, 28)); setStroke((2 * dp).toInt(), Color.parseColor(th.accent)) }
                        else      { setColor(Color.argb(30, 255, 255, 255)); setStroke(1, Color.argb(60, 255, 255, 255)) }
                    }
                    val chk = c.getChildAt(c.childCount - 1) as? TextView
                    chk?.visibility = if (sel) View.VISIBLE else View.INVISIBLE
                }
            }
            sheetContent.addView(card)
        }

        sheetContent.addView(View(this).apply { layoutParams = LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, (8 * dp).toInt()) })

        var sheet: FrameLayout? = null
        val startBtn = Button(this).apply {
            text = "Начать"; textSize = 17f; isAllCaps = false; typeface = Typeface.DEFAULT_BOLD
            setTextColor(Color.parseColor("#111116"))
            background = GradientDrawable().apply { cornerRadius = 14 * dp; setColor(Color.WHITE) }
            layoutParams = LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, (56 * dp).toInt())
            setOnClickListener {
                AppTheme.apply(this@MainActivity, selectedId)
                prefs.edit().putBoolean("theme_chosen", true).apply()
                val s = sheet ?: return@setOnClickListener
                s.animate().translationY(sheetH.toFloat()).setDuration(280).withEndAction {
                    root.removeView(s); root.removeView(dim); recreate()
                }.start()
                dim.animate().alpha(0f).setDuration(280).start()
            }
        }
        sheetContent.addView(startBtn)

        sheet = FrameLayout(this).apply {
            background = GradientDrawable().apply {
                shape = GradientDrawable.RECTANGLE
                cornerRadii = floatArrayOf(28 * dp, 28 * dp, 28 * dp, 28 * dp, 0f, 0f, 0f, 0f)
                setColor(Color.parseColor("#111116"))
            }
            translationY = sheetH.toFloat()
            layoutParams = FrameLayout.LayoutParams(FrameLayout.LayoutParams.MATCH_PARENT, sheetH).apply { gravity = Gravity.BOTTOM }
        }
        sheet!!.addView(sheetScroll, FrameLayout.LayoutParams(FrameLayout.LayoutParams.MATCH_PARENT, FrameLayout.LayoutParams.MATCH_PARENT))
        root.addView(sheet)
        sheet!!.animate().translationY(0f).setDuration(380).setInterpolator(DecelerateInterpolator(2f)).start()
    }

    companion object {
        fun loadAvatarBitmap(ctx: Context): Bitmap? {
            val file = File(ctx.filesDir, "avatar.jpg")
            if (!file.exists()) return null
            return try {
                val opts = BitmapFactory.Options().apply { inJustDecodeBounds = true }
                BitmapFactory.decodeFile(file.absolutePath, opts)
                val size = 256
                opts.inSampleSize = maxOf(1, minOf(opts.outWidth / size, opts.outHeight / size))
                opts.inJustDecodeBounds = false
                BitmapFactory.decodeFile(file.absolutePath, opts)
            } catch (_: Exception) { null }
        }
    }
}
