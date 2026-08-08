package com.traffic.app

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Intent
import android.content.pm.ServiceInfo
import android.net.VpnService
import android.os.Build
import android.os.ParcelFileDescriptor
import android.util.Log
import androidx.core.app.NotificationCompat
import java.util.Timer
import java.util.TimerTask

class AwgVpnService : VpnService() {

    companion object {
        private const val TAG = "AwgVpnService"
        const val ACTION_CONNECT    = "com.traffic.app.awg.CONNECT"
        const val ACTION_DISCONNECT = "com.traffic.app.awg.DISCONNECT"
        const val EXTRA_CONFIG      = "awg_config"

        private const val NOTIFICATION_CHANNEL = "awg_vpn"
        private const val NOTIFICATION_ID = 1002

        var onStatus: ((String) -> Unit)? = null
        var currentHandle: Int = -1
            private set

        fun getStats(): Pair<Long, Long> {
            val h = currentHandle
            if (h < 0) return Pair(0L, 0L)
            return AwgGoBackend.parseTrafficStats(AwgGoBackend.getConfig(h))
        }
    }

    private var tunFd: ParcelFileDescriptor? = null
    private var statsTimer: Timer? = null
    private var lastRx: Long = 0
    private var lastTx: Long = 0
    private var startRx: Long = 0
    private var startTx: Long = 0
    private var lastStatTime: Long = 0

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        return when (intent?.action) {
            ACTION_CONNECT -> {
                val config = intent.getStringExtra(EXTRA_CONFIG)
                if (config != null) startTunnel(config)
                START_STICKY
            }
            ACTION_DISCONNECT -> {
                stopTunnel()
                stopSelf()
                START_NOT_STICKY
            }
            else -> START_NOT_STICKY
        }
    }

    private fun startTunnel(uapiConfig: String) {
        try {
            onStatus?.invoke("connecting")
            @Suppress("NewApi")
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
                startForeground(NOTIFICATION_ID, buildNotification("Подключение..."),
                    ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE)
            } else {
                startForeground(NOTIFICATION_ID, buildNotification("Подключение...", ""))
            }

            val address = uapiConfig.lines()
                .firstOrNull { it.startsWith("address=") }
                ?.substringAfter("=") ?: "10.0.0.2/32"
            val dns = uapiConfig.lines()
                .firstOrNull { it.startsWith("dns=") }
                ?.substringAfter("=") ?: "1.1.1.1"

            val uapiForWg = uapiConfig.lines()
                .filter { !it.startsWith("address=") && !it.startsWith("dns=") }
                .joinToString("\n")

            val builder = Builder()
                .setSession("EOS VPN")
                .setMtu(1420)

            for (addr in address.split(",").map { it.trim() }) {
                if (addr.contains('/')) {
                    val (ip, prefix) = addr.split('/')
                    builder.addAddress(ip, prefix.toInt())
                } else {
                    builder.addAddress(addr, 32)
                }
            }

            for (d in dns.split(",").map { it.trim() }) {
                try { builder.addDnsServer(d) } catch (_: Exception) {}
            }

            val allowedIps = uapiForWg.lines()
                .filter { it.startsWith("allowed_ip=") }
                .map { it.substringAfter("=").trim() }

            if (allowedIps.isEmpty() ||
                allowedIps.any { it == "0.0.0.0/0" || it == "0.0.0.0/1" }) {
                builder.addRoute("0.0.0.0", 0)
                builder.addRoute("::", 0)
            } else {
                for (ip in allowedIps) {
                    try {
                        val (net, prefix) = ip.split('/')
                        builder.addRoute(net, prefix.toInt())
                    } catch (_: Exception) {}
                }
            }

            try { builder.addDisallowedApplication(packageName) } catch (_: Exception) {}

            val pfd = builder.establish()
                ?: throw IllegalStateException("VpnService.Builder.establish() вернул null")

            tunFd = pfd

            val handle = AwgGoBackend.turnOn("awg0", pfd.fd, uapiForWg)
            if (handle < 0) throw IllegalStateException("awgTurnOn вернул ошибку: $handle")

            currentHandle = handle

            val v4 = AwgGoBackend.getSocketV4(handle)
            val v6 = AwgGoBackend.getSocketV6(handle)
            if (v4 >= 0) protect(v4)
            if (v6 >= 0) protect(v6)

            updateNotification("Подключено")
            onStatus?.invoke("connected")
            Log.i(TAG, "Туннель запущен, handle=$handle")

            startStatsTimer()

        } catch (e: Throwable) {
            Log.e(TAG, "Ошибка запуска туннеля", e)
            onStatus?.invoke("error:${e.message ?: e.javaClass.simpleName}")
            stopSelf()
        }
    }

    private fun stopTunnel() {
        try {
            statsTimer?.cancel()
            statsTimer = null
            val h = currentHandle
            currentHandle = -1
            tunFd?.close()
            tunFd = null
            if (h >= 0) {
                AwgGoBackend.turnOff(h)
            }
            onStatus?.invoke("disconnected")
            Log.i(TAG, "Туннель остановлен, handle был $h")
        } catch (e: Throwable) {
            Log.e(TAG, "Ошибка остановки туннеля", e)
        } finally {
            stopForeground(STOP_FOREGROUND_REMOVE)
        }
    }

    override fun onDestroy() {
        stopTunnel()
        super.onDestroy()
    }

    private fun startStatsTimer() {
        statsTimer?.cancel()
        val h0 = currentHandle
        if (h0 >= 0) {
            val (rx0, tx0) = AwgGoBackend.parseTrafficStats(AwgGoBackend.getConfig(h0))
            startRx = rx0; startTx = tx0
            lastRx = rx0; lastTx = tx0
        } else {
            startRx = 0; startTx = 0; lastRx = 0; lastTx = 0
        }
        lastStatTime = System.currentTimeMillis()
        statsTimer = Timer()
        statsTimer?.scheduleAtFixedRate(object : TimerTask() {
            override fun run() {
                val h = currentHandle
                if (h < 0) return
                try {
                    val (rx, tx) = AwgGoBackend.parseTrafficStats(AwgGoBackend.getConfig(h))
                    val now = System.currentTimeMillis()
                    val dt = ((now - lastStatTime).toFloat() / 1000f).coerceAtLeast(0.1f)
                    val rxSpeed = ((rx - lastRx) / dt).toLong().coerceAtLeast(0)
                    val txSpeed = ((tx - lastTx) / dt).toLong().coerceAtLeast(0)
                    lastRx = rx; lastTx = tx; lastStatTime = now
                    val totalRx = (rx - startRx).coerceAtLeast(0)
                    val totalTx = (tx - startTx).coerceAtLeast(0)
                    updateNotification(
                        "↑ ${formatSpeed(txSpeed)}  ↓ ${formatSpeed(rxSpeed)}",
                        "Передано: ↑ ${formatBytes(totalTx)}  ↓ ${formatBytes(totalRx)}"
                    )
                } catch (_: Throwable) {}
            }
        }, 2000, 2000)
    }

    private fun formatSpeed(bytesPerSec: Long): String = when {
        bytesPerSec >= 1_048_576 -> "%.1f MB/s".format(bytesPerSec / 1_048_576.0)
        bytesPerSec >= 1024      -> "%.1f KB/s".format(bytesPerSec / 1024.0)
        else                     -> "$bytesPerSec B/s"
    }

    private fun formatBytes(bytes: Long): String = when {
        bytes >= 1_073_741_824 -> "%.2f GB".format(bytes / 1_073_741_824.0)
        bytes >= 1_048_576     -> "%.1f MB".format(bytes / 1_048_576.0)
        bytes >= 1024          -> "%.1f KB".format(bytes / 1024.0)
        else                   -> "$bytes B"
    }

    private fun buildNotification(line1: String, line2: String = ""): Notification {
        ensureNotificationChannel()
        val mainIntent = PendingIntent.getActivity(
            this, 0,
            Intent(this, MainActivity::class.java),
            PendingIntent.FLAG_IMMUTABLE
        )
        val disconnectIntent = PendingIntent.getService(
            this, 2,
            Intent(this, AwgVpnService::class.java).setAction(ACTION_DISCONNECT),
            PendingIntent.FLAG_IMMUTABLE
        )
        val bigText = if (line2.isNotEmpty()) "$line1\n$line2" else line1

        return NotificationCompat.Builder(this, NOTIFICATION_CHANNEL)
            .setSmallIcon(R.drawable.ic_notification)
            .setContentTitle("EOS VPN")
            .setContentText(line1)
            .setStyle(NotificationCompat.BigTextStyle().bigText(bigText))
            .setContentIntent(mainIntent)
            .addAction(android.R.drawable.ic_menu_close_clear_cancel, "Отключить", disconnectIntent)
            .setOngoing(true)
            .build()
    }

    private fun updateNotification(line1: String, line2: String = "") {
        val nm = getSystemService(NOTIFICATION_SERVICE) as NotificationManager
        nm.notify(NOTIFICATION_ID, buildNotification(line1, line2))
    }

    private fun ensureNotificationChannel() {
        val nm = getSystemService(NOTIFICATION_SERVICE) as NotificationManager
        if (nm.getNotificationChannel(NOTIFICATION_CHANNEL) == null) {
            val channel = NotificationChannel(
                NOTIFICATION_CHANNEL,
                "EOS VPN",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Статус VPN-соединения"
                setShowBadge(false)
            }
            nm.createNotificationChannel(channel)
        }
    }
}
