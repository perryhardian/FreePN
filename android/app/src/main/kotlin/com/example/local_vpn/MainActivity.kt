package com.example.local_vpn

import android.app.Activity
import android.content.Intent
import android.net.VpnService
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val tunnelManager by lazy {
        WireGuardTunnelManager.getInstance(applicationContext)
    }

    private var channel: MethodChannel? = null
    private var pendingPermissionResult: MethodChannel.Result? = null
    private var pendingConfigText: String? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL_NAME).also {
            it.setMethodCallHandler(::handleMethodCall)
        }
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        channel?.setMethodCallHandler(null)
        channel = null
        pendingPermissionResult?.error(
            "ACTIVITY_UNAVAILABLE",
            "The Android activity closed before VPN permission completed. Try again.",
            null,
        )
        pendingPermissionResult = null
        pendingConfigText = null
        super.cleanUpFlutterEngine(flutterEngine)
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != VPN_PERMISSION_REQUEST_CODE) return

        val result = pendingPermissionResult ?: return
        val configText = pendingConfigText
        pendingPermissionResult = null
        pendingConfigText = null

        if (resultCode != Activity.RESULT_OK) {
            tunnelManager.markError()
            result.error(
                "VPN_PERMISSION_DENIED",
                "VPN permission was denied. Allow the VPN request and try again.",
                null,
            )
            return
        }

        continueConnect(configText, result)
    }

    private fun handleMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "connect" -> requestConnect(call.argument<String>("configText"), result)
            "disconnect" -> tunnelManager.disconnect(result)
            "getStatus" -> result.success(tunnelManager.statusValue)
            else -> result.notImplemented()
        }
    }

    private fun requestConnect(configText: String?, result: MethodChannel.Result) {
        if (pendingPermissionResult != null) {
            result.error(
                "VPN_REQUEST_IN_PROGRESS",
                "A VPN permission request is already in progress.",
                null,
            )
            return
        }

        val permissionIntent = VpnService.prepare(this)
        if (permissionIntent == null) {
            continueConnect(configText, result)
            return
        }

        pendingPermissionResult = result
        pendingConfigText = configText
        startActivityForResult(permissionIntent, VPN_PERMISSION_REQUEST_CODE)
    }

    private fun continueConnect(configText: String?, result: MethodChannel.Result) {
        if (configText.isNullOrBlank()) {
            tunnelManager.markError()
            result.error(
                "MISSING_VPN_CONFIGURATION",
                "VPN permission is ready, but no WireGuard configuration has been supplied yet.",
                null,
            )
            return
        }

        tunnelManager.connect(configText, result)
    }

    private companion object {
        const val CHANNEL_NAME = "local_vpn/vpn"
        const val VPN_PERMISSION_REQUEST_CODE = 42001
    }
}
