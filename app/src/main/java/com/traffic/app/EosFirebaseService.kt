package com.traffic.app

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import androidx.core.app.NotificationCompat
import com.google.firebase.messaging.FirebaseMessagingService
import com.google.firebase.messaging.RemoteMessage
import java.net.HttpURLConnection
import java.net.URL

class EosFirebaseService : FirebaseMessagingService() {

    companion object {
        const val CHANNEL_ID = "eos_chat"

        fun createNotificationChannel(ctx: Context) {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                val channel = NotificationChannel(CHANNEL_ID, "Чат", NotificationManager.IMPORTANCE_HIGH).apply {
                    description = "Сообщения из чатов EOS"
                }
                (ctx.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager)
                    .createNotificationChannel(channel)
            }
        }

        fun sendTokenToServer(ctx: Context) {
            val prefs     = ctx.getSharedPreferences("traffic_prefs", Context.MODE_PRIVATE)
            val token     = prefs.getString("fcm_token", "") ?: return
            val sender    = prefs.getString("profile_name", "") ?: return
            val serverUrl = prefs.getString("server_url", "http://eos-traffic.ddns.net:5000") ?: return
            if (token.isEmpty() || sender.isEmpty()) return
            Thread {
                try {
                    val conn = URL("$serverUrl/fcm_token").openConnection() as HttpURLConnection
                    conn.requestMethod = "POST"; conn.doOutput = true
                    conn.setRequestProperty("Content-Type", "application/json; charset=utf-8")
                    conn.connectTimeout = 8000; conn.readTimeout = 8000
                    val body = "{\"sender\":\"${sender.replace("\"","")}\",\"token\":\"${token.replace("\"","")}\"}"
                    conn.outputStream.write(body.toByteArray(Charsets.UTF_8))
                    conn.responseCode; conn.disconnect()
                } catch (_: Exception) {}
            }.start()
        }
    }

    override fun onNewToken(token: String) {
        val prefs = getSharedPreferences("traffic_prefs", Context.MODE_PRIVATE)
        prefs.edit().putString("fcm_token", token).apply()
        sendTokenToServer(this)
    }

    override fun onMessageReceived(message: RemoteMessage) {
        val title = message.notification?.title ?: message.data["sender"] ?: "EOS"
        val body  = message.notification?.body  ?: message.data["text"]   ?: ""
        if (body.isEmpty()) return
        val chatChannel = message.data["channel"] ?: "general"
        showNotification(title, body, chatChannel)
    }

    private fun showNotification(title: String, body: String, chatChannel: String) {
        createNotificationChannel(this)
        val intent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_CLEAR_TOP
            putExtra("open_chat", chatChannel)
        }
        val pi = PendingIntent.getActivity(this, chatChannel.hashCode(), intent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)
        val notif = NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_dialog_email)
            .setContentTitle(title)
            .setContentText(body)
            .setAutoCancel(true)
            .setContentIntent(pi)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .build()
        (getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager)
            .notify(System.currentTimeMillis().toInt(), notif)
    }
}
