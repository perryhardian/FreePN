package com.example.local_vpn

import android.content.Context
import android.content.pm.ApplicationInfo
import android.util.Log

/** Only pass fixed event names, state names, or our own error codes here. */
class VpnDiagnostics(context: Context) {
    private val enabled =
        (context.applicationInfo.flags and ApplicationInfo.FLAG_DEBUGGABLE) != 0

    fun event(name: String) {
        if (enabled) Log.d(TAG, name)
    }

    fun error(code: String) {
        // Exception messages and configuration text can contain key material.
        if (enabled) Log.w(TAG, code)
    }

    private companion object {
        const val TAG = "FreePN"
    }
}
