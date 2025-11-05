package com.funny.replaysdk

internal object Logger {
    @Volatile private var enabled: Boolean = true

    fun setEnabled(value: Boolean) { enabled = value }

    fun d(tag: String, msg: String) { if (enabled) android.util.Log.d(tag, msg) }
    fun i(tag: String, msg: String) { if (enabled) android.util.Log.i(tag, msg) }
    fun w(tag: String, msg: String) {
        if (enabled) android.util.Log.w(tag, msg)
    }
    fun w(tag: String, msg: String, tr: Throwable) {
        if (enabled) android.util.Log.w(tag, msg, tr)
    }
    fun e(tag: String, msg: String) {
        if (enabled) android.util.Log.e(tag, msg)
    }
    fun e(tag: String, msg: String, tr: Throwable) {
        if (enabled) android.util.Log.e(tag, msg, tr)
    }
}


