package com.example.local_vpn

import android.content.Context
import android.os.Handler
import android.os.Looper
import com.wireguard.android.backend.GoBackend
import com.wireguard.android.backend.Tunnel
import com.wireguard.config.BadConfigException
import com.wireguard.config.Config
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayInputStream
import java.nio.charset.StandardCharsets
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

class WireGuardTunnelManager private constructor(context: Context) {
    private val appContext = context.applicationContext
    private val mainHandler = Handler(Looper.getMainLooper())
    private val executor: ExecutorService = Executors.newSingleThreadExecutor()

    @Volatile
    private var status = Status.DISCONNECTED

    private val backend by lazy { GoBackend(appContext) }

    private val tunnel =
        object : Tunnel {
            override fun getName(): String = TUNNEL_NAME

            override fun onStateChange(newState: Tunnel.State) {
                status =
                    when (newState) {
                        Tunnel.State.UP -> Status.CONNECTED
                        Tunnel.State.DOWN -> Status.DISCONNECTED
                        Tunnel.State.TOGGLE -> status
                    }
            }
        }

    val statusValue: String
        get() = status.platformValue

    fun markError() {
        status = Status.ERROR
    }

    fun connect(configText: String, result: MethodChannel.Result) {
        if (status == Status.CONNECTING || status == Status.DISCONNECTING) {
            result.error(
                "VPN_OPERATION_IN_PROGRESS",
                "Another VPN operation is already in progress.",
                null,
            )
            return
        }
        if (status == Status.CONNECTED) {
            result.success(Status.CONNECTED.platformValue)
            return
        }

        status = Status.CONNECTING
        executor.execute {
            try {
                val config = parseConfig(configText)
                val finalState = backend.setState(tunnel, Tunnel.State.UP, config)
                status =
                    if (finalState == Tunnel.State.UP) {
                        Status.CONNECTED
                    } else {
                        Status.ERROR
                    }

                if (status == Status.CONNECTED) {
                    completeSuccess(result, status.platformValue)
                } else {
                    completeError(
                        result,
                        "TUNNEL_START_FAILED",
                        "WireGuard did not report an active tunnel.",
                    )
                }
            } catch (_: BadConfigException) {
                status = Status.ERROR
                completeError(
                    result,
                    "INVALID_VPN_CONFIGURATION",
                    "The WireGuard configuration is invalid. Check the addresses, endpoint, and keys.",
                )
            } catch (_: SecurityException) {
                status = Status.ERROR
                completeError(
                    result,
                    "VPN_PERMISSION_DENIED",
                    "Android did not allow this app to create a VPN tunnel.",
                )
            } catch (_: LinkageError) {
                status = Status.ERROR
                completeError(
                    result,
                    "WIREGUARD_LIBRARY_UNAVAILABLE",
                    "The WireGuard native library could not be loaded on this device.",
                )
            } catch (_: Exception) {
                status = Status.ERROR
                completeError(
                    result,
                    "TUNNEL_START_FAILED",
                    "The WireGuard tunnel could not be started. Check the endpoint and configuration.",
                )
            }
        }
    }

    fun disconnect(result: MethodChannel.Result) {
        if (status == Status.CONNECTING || status == Status.DISCONNECTING) {
            result.error(
                "VPN_OPERATION_IN_PROGRESS",
                "Another VPN operation is already in progress.",
                null,
            )
            return
        }
        if (status == Status.DISCONNECTED) {
            result.success(Status.DISCONNECTED.platformValue)
            return
        }

        status = Status.DISCONNECTING
        executor.execute {
            try {
                backend.setState(tunnel, Tunnel.State.DOWN, null)
                status = Status.DISCONNECTED
                completeSuccess(result, status.platformValue)
            } catch (_: Exception) {
                status = Status.ERROR
                completeError(
                    result,
                    "TUNNEL_STOP_FAILED",
                    "The WireGuard tunnel could not be stopped. Try again.",
                )
            }
        }
    }

    private fun parseConfig(configText: String): Config {
        val bytes = configText.toByteArray(StandardCharsets.UTF_8)
        return ByteArrayInputStream(bytes).use { input -> Config.parse(input) }
    }

    private fun completeSuccess(result: MethodChannel.Result, value: String) {
        mainHandler.post { result.success(value) }
    }

    private fun completeError(
        result: MethodChannel.Result,
        code: String,
        message: String,
    ) {
        mainHandler.post { result.error(code, message, null) }
    }

    private enum class Status(val platformValue: String) {
        DISCONNECTED("disconnected"),
        CONNECTING("connecting"),
        CONNECTED("connected"),
        DISCONNECTING("disconnecting"),
        ERROR("error"),
    }

    companion object {
        private const val TUNNEL_NAME = "local_vpn"

        @Volatile
        private var instance: WireGuardTunnelManager? = null

        fun getInstance(context: Context): WireGuardTunnelManager {
            return instance ?: synchronized(this) {
                instance ?: WireGuardTunnelManager(context).also { instance = it }
            }
        }
    }
}
