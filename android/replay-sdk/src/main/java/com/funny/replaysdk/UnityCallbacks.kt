package com.funny.replaysdk

// Unity 桥接回调接口（录制）
interface UnityRecordingCallback {
    fun onRecordingStarted()
    fun onRecordingProgress(durationMs: Long, fileSizeBytes: Long)
    fun onRecordingStopped(
        success: Boolean,
        filePath: String?,
        fileSize: Long,
        duration: Float,
        errorCode: Int,
        errorMessage: String?
    )
    fun onRecordingError(errorCode: Int, errorMessage: String?)
    fun onRecordingQualityAdjusted(quality: Int)
}




