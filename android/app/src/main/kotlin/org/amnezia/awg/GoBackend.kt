package org.amnezia.awg

object GoBackend {
    init {
        System.loadLibrary("awg")
    }

    external fun awgTurnOn(name: String, tunFd: Int, settings: String): Int
    external fun awgTurnOff(handle: Int)
    external fun awgGetSocketV4(handle: Int): Int
    external fun awgGetSocketV6(handle: Int): Int
    external fun awgGetConfig(handle: Int): String?
    external fun awgVersion(): String?
}
