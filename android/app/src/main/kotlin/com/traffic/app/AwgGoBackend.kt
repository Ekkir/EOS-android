package com.traffic.app

import android.util.Base64

object AwgGoBackend {

    private val awg get() = org.amnezia.awg.GoBackend

    fun turnOn(ifName: String, tunFd: Int, settings: String): Int =
        awg.awgTurnOn(ifName, tunFd, settings)

    fun turnOff(handle: Int) = awg.awgTurnOff(handle)

    fun getConfig(handle: Int): String? = awg.awgGetConfig(handle)

    fun getSocketV4(handle: Int): Int = awg.awgGetSocketV4(handle)

    fun getSocketV6(handle: Int): Int = awg.awgGetSocketV6(handle)

    fun version(): String = awg.awgVersion() ?: "unknown"

    fun base64ToHex(base64Key: String): String {
        val bytes = Base64.decode(base64Key.trim(), Base64.DEFAULT)
        return bytes.joinToString("") { "%02x".format(it) }
    }

    fun parseTrafficStats(config: String?): Pair<Long, Long> {
        if (config == null) return Pair(0L, 0L)
        var rx = 0L
        var tx = 0L
        for (line in config.lines()) {
            when {
                line.startsWith("rx_bytes=") -> rx += line.substringAfter("=").toLongOrNull() ?: 0L
                line.startsWith("tx_bytes=") -> tx += line.substringAfter("=").toLongOrNull() ?: 0L
            }
        }
        return Pair(rx, tx)
    }
}
