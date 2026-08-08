package com.traffic.app

import android.content.Intent
import android.util.Log
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.Result

class AwgFlutterPlugin(private val activity: MainActivity) :
    MethodChannel.MethodCallHandler,
    EventChannel.StreamHandler {

    companion object {
        private const val TAG = "AwgFlutterPlugin"
        const val METHOD_CHANNEL = "com.traffic.app.awg/channel"
        const val EVENT_CHANNEL  = "com.traffic.app.awg/status"
    }

    private var eventSink: EventChannel.EventSink? = null

    fun onStatusChange(status: String) {
        activity.runOnUiThread {
            eventSink?.success(status)
        }
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "connect"    -> handleConnect(call, result)
            "disconnect" -> handleDisconnect(result)
            "getStatus"  -> result.success(currentStatus())
            "getStats"   -> result.success(getStats())
            "getVersion" -> result.success(safeVersion())
            else         -> result.notImplemented()
        }
    }

    @Suppress("UNCHECKED_CAST")
    private fun handleConnect(call: MethodCall, result: Result) {
        val args = call.arguments as? Map<String, Any?> ?: run {
            result.error("INVALID_ARGS", "Ожидается Map с конфигурацией", null)
            return
        }

        val vpnIntent = android.net.VpnService.prepare(activity)
        if (vpnIntent != null) {
            activity.pendingConnectArgs = args
            activity.startActivityForResult(vpnIntent, MainActivity.REQUEST_VPN_PERMISSION)
            result.success(null)
            return
        }

        startVpnService(args)
        result.success(null)
    }

    fun startVpnService(args: Map<String, Any?>) {
        val uapi = buildUapiConfig(args)
        if (uapi == null) {
            onStatusChange("error:Не удалось собрать конфигурацию")
            return
        }
        try {
            Log.d(TAG, "Запуск VPN")
            val splitMode = args["split_mode"] as? String ?: "none"
            @Suppress("UNCHECKED_CAST")
            val splitApps = (args["split_apps"] as? List<*>)?.filterIsInstance<String>() ?: emptyList()
            val intent = Intent(activity, AwgVpnService::class.java)
                .setAction(AwgVpnService.ACTION_CONNECT)
                .putExtra(AwgVpnService.EXTRA_CONFIG, uapi)
                .putExtra(AwgVpnService.EXTRA_SPLIT_MODE, splitMode)
                .putStringArrayListExtra(AwgVpnService.EXTRA_SPLIT_APPS, ArrayList(splitApps))
            activity.startForegroundService(intent)
        } catch (e: Throwable) {
            Log.e(TAG, "Не удалось запустить VPN сервис", e)
            onStatusChange("error:${e.message ?: e.javaClass.simpleName}")
        }
    }

    private fun handleDisconnect(result: Result) {
        val intent = Intent(activity, AwgVpnService::class.java)
            .setAction(AwgVpnService.ACTION_DISCONNECT)
        activity.startService(intent)
        result.success(null)
    }

    private fun currentStatus(): String =
        if (AwgVpnService.currentHandle >= 0) "connected" else "disconnected"

    private fun getStats(): Map<String, Long> {
        val (rx, tx) = AwgVpnService.getStats()
        return mapOf("rxBytes" to rx, "txBytes" to tx)
    }

    private fun safeVersion(): String = try {
        AwgGoBackend.version()
    } catch (e: Throwable) {
        "libawg.so не загружена (${e.javaClass.simpleName})"
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
        AwgVpnService.onStatus = { status -> onStatusChange(status) }
    }

    override fun onCancel(arguments: Any?) {
        eventSink = null
        AwgVpnService.onStatus = null
    }

    private fun buildUapiConfig(args: Map<String, Any?>): String? {
        val privateKey = args["privateKey"] as? String ?: return null
        val publicKey  = args["publicKey"]  as? String ?: return null
        val endpoint   = args["endpoint"]   as? String ?: return null
        val allowedIPs = args["allowedIPs"] as? String ?: return null
        val address    = args["address"]    as? String ?: "10.0.0.2/32"
        val dns        = args["dns"]        as? String ?: "1.1.1.1"
        val presharedKey = args["presharedKey"] as? String
        val keepalive  = (args["keepalive"] as? Int) ?: 25

        val jc   = args["jc"]   as? Int
        val jmin = args["jmin"] as? Int
        val jmax = args["jmax"] as? Int
        val s1   = args["s1"]   as? Int
        val s2   = args["s2"]   as? Int
        val h1   = args["h1"]   as? Int
        val h2   = args["h2"]   as? Int
        val h3   = args["h3"]   as? Int
        val h4   = args["h4"]   as? Int

        return buildString {
            appendLine("address=$address")
            appendLine("dns=$dns")
            appendLine("private_key=${AwgGoBackend.base64ToHex(privateKey)}")
            if (jc   != null) appendLine("jc=$jc")
            if (jmin != null) appendLine("jmin=$jmin")
            if (jmax != null) appendLine("jmax=$jmax")
            if (s1   != null) appendLine("s1=$s1")
            if (s2   != null) appendLine("s2=$s2")
            if (h1   != null) appendLine("h1=$h1")
            if (h2   != null) appendLine("h2=$h2")
            if (h3   != null) appendLine("h3=$h3")
            if (h4   != null) appendLine("h4=$h4")
            appendLine("public_key=${AwgGoBackend.base64ToHex(publicKey)}")
            if (presharedKey != null) appendLine("preshared_key=${AwgGoBackend.base64ToHex(presharedKey)}")
            appendLine("endpoint=$endpoint")
            for (ip in allowedIPs.split(",").map { it.trim() }.filter { it.isNotEmpty() }) {
                appendLine("allowed_ip=$ip")
            }
            if (keepalive > 0) appendLine("persistent_keepalive_interval=$keepalive")
        }.trimEnd()
    }
}
