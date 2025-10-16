package com.funny.replaysdk

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.media.projection.MediaProjectionManager
import android.os.Bundle

/**
 * 透明代理 Activity：发起屏幕捕获授权并把结果回传给 RecordingManager
 */
class ScreenCapturePermissionActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        try {
            val mpm = getSystemService(Context.MEDIA_PROJECTION_SERVICE) as MediaProjectionManager
            val intent = mpm.createScreenCaptureIntent()
            startActivityForResult(intent, 10002)
        } catch (t: Throwable) {
            android.util.Log.e("ScreenCapturePermission", "launch capture intent failed: ${t.message}", t)
            finish()
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        try {
            RecordingManager.onActivityResult(requestCode, resultCode, data)
        } catch (t: Throwable) {
            android.util.Log.w("ScreenCapturePermission", "forward onActivityResult failed: ${t.message}")
        } finally {
            finish()
        }
    }
}


