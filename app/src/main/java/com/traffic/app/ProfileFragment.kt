package com.traffic.app

import android.app.Activity
import android.content.Context
import android.graphics.BitmapFactory
import android.graphics.Color
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.net.Uri
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.text.InputType
import android.view.Gravity
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.*
import androidx.activity.result.contract.ActivityResultContracts
import androidx.fragment.app.Fragment
import com.google.android.gms.auth.api.signin.GoogleSignIn
import com.google.android.gms.auth.api.signin.GoogleSignInOptions
import com.google.android.gms.common.api.ApiException
import java.io.File
import java.net.HttpURLConnection
import java.net.URL
import org.json.JSONObject

class ProfileFragment : Fragment() {

    private val prefs     get() = requireContext().getSharedPreferences("traffic_prefs", Context.MODE_PRIVATE)
    private val serverUrl get() = ServerUrlResolver.resolve(prefs)
    private val handler = Handler(Looper.getMainLooper())

    private var avatarBig: ImageView? = null
    private var nameInput: EditText? = null
    private var descInput: EditText? = null
    private var googleCard: LinearLayout? = null
    private var dp = 1f

    private val pickImage = registerForActivityResult(ActivityResultContracts.GetContent()) { uri: Uri? ->
        uri ?: return@registerForActivityResult
        copyImageToInternal(uri)
        reloadAvatarBig()
        (activity as? MainActivity)?.reloadAvatar()
        val email = prefs.getString("google_email", "") ?: ""
        if (email.isNotEmpty()) uploadAvatarToServer(email)
    }

    private val signInLauncher = registerForActivityResult(ActivityResultContracts.StartActivityForResult()) { result ->
        if (result.resultCode == Activity.RESULT_OK) {
            val task = GoogleSignIn.getSignedInAccountFromIntent(result.data)
            try {
                val account = task.getResult(ApiException::class.java)
                prefs.edit()
                    .putBoolean("google_signed_in", true)
                    .putString("google_name", account.displayName ?: "")
                    .putString("google_email", account.email ?: "")
                    .putString("google_photo", account.photoUrl?.toString() ?: "")
                    .apply()
                if (prefs.getString("profile_name", "").isNullOrEmpty()) {
                    nameInput?.setText(account.displayName ?: "")
                }
                val emailForUpload = account.email ?: ""
                // Фото только если своего ещё нет
                val photoUrl = account.photoUrl?.toString()
                val existingAvatar = File(requireContext().filesDir, "avatar.jpg")
                if (photoUrl != null && !existingAvatar.exists()) {
                    Thread {
                        try {
                            val bmp = BitmapFactory.decodeStream(URL(photoUrl).openStream())
                            saveAvatarBitmap(bmp)
                            if (emailForUpload.isNotEmpty()) uploadAvatarToServer(emailForUpload)
                            handler.post {
                                if (!isAdded) return@post
                                reloadAvatarBig()
                                (activity as? MainActivity)?.reloadAvatar()
                            }
                        } catch (_: Exception) {}
                    }.start()
                }
                restoreProfileFromServer(emailForUpload)
                rebuildGoogleCard()
            } catch (e: ApiException) {
                android.widget.Toast.makeText(
                    requireContext(),
                    "Ошибка входа (код ${e.statusCode}): нужно зарегистрировать приложение в Firebase",
                    android.widget.Toast.LENGTH_LONG
                ).show()
            }
        }
    }

    override fun onCreateView(inflater: LayoutInflater, container: ViewGroup?, savedInstanceState: Bundle?): View {
        val ctx = requireContext()
        val t   = AppTheme.current
        dp = ctx.resources.displayMetrics.density

        val scroll = ScrollView(ctx).apply { background = bgDrawable(t) }
        val layout = LinearLayout(ctx).apply {
            orientation = LinearLayout.VERTICAL
            setPadding((20 * dp).toInt(), (24 * dp).toInt() + statusBarHeight(ctx), (20 * dp).toInt(), (48 * dp).toInt())
        }
        scroll.addView(layout)

        // ── Шапка ─────────────────────────────────────────────────────────────
        val headerRow = LinearLayout(ctx).apply {
            orientation = LinearLayout.HORIZONTAL; gravity = Gravity.CENTER_VERTICAL
            layoutParams = LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT)
        }
        headerRow.addView(TextView(ctx).apply {
            text = "Профиль"; textSize = 22f; typeface = Typeface.DEFAULT_BOLD
            setTextColor(Color.parseColor(t.textPrimary))
            layoutParams = LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f)
        })
        headerRow.addView(miniAvatarView(ctx, dp, t) { (activity as? MainActivity)?.openDrawer() })
        headerRow.addView(Button(ctx).apply {
            text = "✕"; textSize = 20f
            setTextColor(Color.parseColor(t.textSecondary))
            setBackgroundColor(Color.TRANSPARENT)
            layoutParams = LinearLayout.LayoutParams((44 * dp).toInt(), (44 * dp).toInt()).apply { marginStart = (8 * dp).toInt() }
            setOnClickListener { requireActivity().onBackPressed() }
        })
        layout.addView(headerRow)

        // ── Google Sign-In карточка ────────────────────────────────────────────
        googleCard = LinearLayout(ctx).apply {
            orientation = LinearLayout.VERTICAL
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT
            ).apply { topMargin = (20 * dp).toInt() }
        }
        layout.addView(googleCard)
        rebuildGoogleCard()

        // ── Большой аватар ────────────────────────────────────────────────────
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

        layout.addView(Button(ctx).apply {
            text = "Сменить фото"; textSize = 15f; setTextColor(Color.parseColor(t.textPrimary))
            isAllCaps = false; background = cardDrawable(t, 12f, dp)
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT, (52 * dp).toInt()
            ).also { it.topMargin = (20 * dp).toInt() }
            setOnClickListener { pickImage.launch("image/*") }
        })

        divider(layout, ctx, t, dp)

        layout.addView(label(ctx, "Имя", t, dp))
        nameInput = editField(ctx, "Ваше имя", InputType.TYPE_CLASS_TEXT or InputType.TYPE_TEXT_FLAG_CAP_WORDS, t, dp)
        nameInput!!.setText(prefs.getString("profile_name", ""))
        layout.addView(nameInput)

        layout.addView(label(ctx, "Описание", t, dp))
        descInput = editField(ctx, "Расскажите о себе...",
            InputType.TYPE_CLASS_TEXT or InputType.TYPE_TEXT_FLAG_MULTI_LINE or InputType.TYPE_TEXT_FLAG_CAP_SENTENCES, t, dp)
        descInput!!.apply { minLines = 3; maxLines = 5; gravity = Gravity.TOP }
        descInput!!.setText(prefs.getString("profile_desc", ""))
        layout.addView(descInput)

        divider(layout, ctx, t, dp)

        layout.addView(Button(ctx).apply {
            text = "Сохранить"; textSize = 17f; setTextColor(Color.parseColor(t.bg))
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

    private fun rebuildGoogleCard() {
        val card = googleCard ?: return
        val ctx = context ?: return
        val t = AppTheme.current
        card.removeAllViews()

        val isSignedIn = prefs.getBoolean("google_signed_in", false)

        val container = LinearLayout(ctx).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            setPadding((16 * dp).toInt(), (14 * dp).toInt(), (16 * dp).toInt(), (14 * dp).toInt())
            background = cardDrawable(t, 16f, dp)
            layoutParams = LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT)
        }

        if (isSignedIn) {
            val name  = prefs.getString("google_name", "") ?: ""
            val email = prefs.getString("google_email", "") ?: ""

            // Google logo
            container.addView(TextView(ctx).apply {
                text = "G"; textSize = 20f; typeface = Typeface.DEFAULT_BOLD; gravity = Gravity.CENTER
                setTextColor(Color.parseColor("#4285F4"))
                background = GradientDrawable().apply {
                    shape = GradientDrawable.OVAL; setColor(Color.argb(30, 66, 133, 244))
                }
                layoutParams = LinearLayout.LayoutParams((40 * dp).toInt(), (40 * dp).toInt()).apply {
                    marginEnd = (12 * dp).toInt()
                }
            })

            val textCol = LinearLayout(ctx).apply {
                orientation = LinearLayout.VERTICAL
                layoutParams = LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f)
            }
            textCol.addView(TextView(ctx).apply {
                text = name; textSize = 15f; typeface = Typeface.DEFAULT_BOLD
                setTextColor(Color.parseColor(t.textPrimary))
            })
            textCol.addView(TextView(ctx).apply {
                text = email; textSize = 12f
                setTextColor(Color.parseColor(t.textSecondary))
                setPadding(0, (2 * dp).toInt(), 0, 0)
            })
            container.addView(textCol)

            container.addView(Button(ctx).apply {
                text = "Выйти"; textSize = 13f; isAllCaps = false
                setTextColor(Color.parseColor(t.textSecondary))
                background = GradientDrawable().apply {
                    shape = GradientDrawable.RECTANGLE; cornerRadius = 8f * dp
                    setColor(Color.argb(40, 255, 255, 255))
                }
                layoutParams = LinearLayout.LayoutParams(LinearLayout.LayoutParams.WRAP_CONTENT, (36 * dp).toInt())
                setOnClickListener { signOut() }
            })
        } else {
            // Google logo
            container.addView(TextView(ctx).apply {
                text = "G"; textSize = 20f; typeface = Typeface.DEFAULT_BOLD; gravity = Gravity.CENTER
                setTextColor(Color.parseColor("#4285F4"))
                background = GradientDrawable().apply {
                    shape = GradientDrawable.OVAL; setColor(Color.argb(30, 66, 133, 244))
                }
                layoutParams = LinearLayout.LayoutParams((40 * dp).toInt(), (40 * dp).toInt()).apply {
                    marginEnd = (12 * dp).toInt()
                }
            })

            container.addView(TextView(ctx).apply {
                text = "Войти через Google"; textSize = 15f; typeface = Typeface.DEFAULT_BOLD
                setTextColor(Color.parseColor(t.textPrimary))
                layoutParams = LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f)
            })

            container.isClickable = true; container.isFocusable = true
            container.setOnClickListener { startGoogleSignIn() }
        }

        card.addView(container)
    }

    private fun startGoogleSignIn() {
        val gso = GoogleSignInOptions.Builder(GoogleSignInOptions.DEFAULT_SIGN_IN)
            .requestIdToken(getString(R.string.default_web_client_id))
            .requestEmail()
            .requestProfile()
            .build()
        val client = GoogleSignIn.getClient(requireActivity(), gso)
        signInLauncher.launch(client.signInIntent)
    }

    private fun signOut() {
        val gso = GoogleSignInOptions.Builder(GoogleSignInOptions.DEFAULT_SIGN_IN).build()
        GoogleSignIn.getClient(requireActivity(), gso).signOut().addOnCompleteListener {
            prefs.edit()
                .putBoolean("google_signed_in", false)
                .remove("google_name").remove("google_email").remove("google_photo")
                .apply()
            rebuildGoogleCard()
        }
    }

    private fun saveProfile(btn: Button) {
        val name = nameInput?.text?.toString()?.trim() ?: ""
        val desc = descInput?.text?.toString()?.trim() ?: ""
        prefs.edit().putString("profile_name", name).putString("profile_desc", desc).apply()
        val email = prefs.getString("google_email", "") ?: ""
        if (email.isNotEmpty() && name.isNotEmpty()) {
            syncProfileToServer(email, name)
            uploadAvatarToServer(email)
        }
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
                shape = GradientDrawable.OVAL; setColor(hexAlpha(t.accent, 30))
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

    private fun saveAvatarBitmap(bmp: android.graphics.Bitmap) {
        try {
            val file = File(requireContext().filesDir, "avatar.jpg")
            file.outputStream().use { out -> bmp.compress(android.graphics.Bitmap.CompressFormat.JPEG, 90, out) }
        } catch (_: Exception) {}
    }

    private fun label(ctx: Context, text: String, t: ThemeDef, dp: Float) = TextView(ctx).apply {
        this.text = text.uppercase(); textSize = 10f; letterSpacing = 0.1f; typeface = Typeface.DEFAULT_BOLD
        setTextColor(Color.parseColor(t.textSecondary))
        setPadding(0, (20 * dp).toInt(), 0, (6 * dp).toInt())
    }

    private fun editField(ctx: Context, hint: String, type: Int, t: ThemeDef, dp: Float) = EditText(ctx).apply {
        inputType = type; this.hint = hint
        setTextColor(Color.parseColor(t.textPrimary))
        setHintTextColor(hexAlpha(t.textSecondary, 90))
        background = GradientDrawable().apply {
            shape = GradientDrawable.RECTANGLE; cornerRadius = 10f * dp
            setColor(hexAlpha(t.bg, 220)); setStroke(1, Color.parseColor(t.cardBorder))
        }
        setPadding((16 * dp).toInt(), (14 * dp).toInt(), (16 * dp).toInt(), (14 * dp).toInt())
        textSize = 15f
        layoutParams = LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT)
    }

    private fun divider(layout: LinearLayout, ctx: Context, t: ThemeDef, dp: Float) {
        layout.addView(View(ctx).apply {
            setBackgroundColor(Color.parseColor(t.cardBorder))
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT, 1
            ).also { it.topMargin = (24 * dp).toInt() }
        })
    }

    private fun syncProfileToServer(email: String, name: String) {
        val url = serverUrl
        Thread {
            try {
                val conn = URL("$url/profile").openConnection() as HttpURLConnection
                conn.requestMethod = "POST"; conn.doOutput = true
                conn.setRequestProperty("Content-Type", "application/json; charset=utf-8")
                conn.connectTimeout = 8000; conn.readTimeout = 8000
                val safeEmail = email.replace("\"", "")
                val safeName  = name.replace("\"", "").replace("\\", "")
                val body = "{\"google_email\":\"$safeEmail\",\"display_name\":\"$safeName\"}".toByteArray(Charsets.UTF_8)
                conn.outputStream.write(body)
                conn.responseCode; conn.disconnect()
            } catch (_: Exception) {}
        }.start()
    }

    private fun uploadAvatarToServer(email: String) {
        val url  = serverUrl
        val name = prefs.getString("profile_name", "") ?: ""
        val ctx  = context ?: return
        Thread {
            try {
                val avatarFile = File(ctx.filesDir, "avatar.jpg")
                if (!avatarFile.exists()) return@Thread
                val boundary = "----Boundary${System.currentTimeMillis()}"
                val conn = URL("$url/avatar").openConnection() as HttpURLConnection
                conn.requestMethod = "POST"; conn.doOutput = true
                conn.setRequestProperty("Content-Type", "multipart/form-data; boundary=$boundary")
                conn.connectTimeout = 8000; conn.readTimeout = 8000
                val out = conn.outputStream
                if (name.isNotEmpty())
                    out.write("--$boundary\r\nContent-Disposition: form-data; name=\"sender\"\r\n\r\n$name\r\n".toByteArray())
                out.write("--$boundary\r\nContent-Disposition: form-data; name=\"google_email\"\r\n\r\n$email\r\n".toByteArray())
                out.write("--$boundary\r\nContent-Disposition: form-data; name=\"file\"; filename=\"avatar.jpg\"\r\nContent-Type: image/jpeg\r\n\r\n".toByteArray())
                out.write(avatarFile.readBytes())
                out.write("\r\n--$boundary--\r\n".toByteArray())
                out.flush(); conn.responseCode; conn.disconnect()
            } catch (_: Exception) {}
        }.start()
    }

    private fun restoreProfileFromServer(email: String) {
        if (email.isEmpty()) return
        val url = serverUrl
        val ctx = context ?: return
        Thread {
            try {
                val json = JSONObject(URL("$url/profile/$email").readText())
                val serverName = json.optString("display_name", "")
                if (serverName.isNotEmpty() && prefs.getString("profile_name", "").isNullOrEmpty()) {
                    prefs.edit().putString("profile_name", serverName).apply()
                    handler.post { if (isAdded) nameInput?.setText(serverName) }
                }
            } catch (_: Exception) {}
            try {
                if (!File(ctx.filesDir, "avatar.jpg").exists()) {
                    val bytes = URL("$url/avatar/email/$email").readBytes()
                    File(ctx.filesDir, "avatar.jpg").writeBytes(bytes)
                    handler.post {
                        if (!isAdded) return@post
                        reloadAvatarBig()
                        (activity as? MainActivity)?.reloadAvatar()
                    }
                }
            } catch (_: Exception) {}
        }.start()
    }
}
