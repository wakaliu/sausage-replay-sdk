package com.funny.replaysdk

internal object ErrorCodes {
    // 通用与录制流程
    const val OK = 0
    const val RECORDING_ALREADY_IN_PROGRESS = 2000
    const val RECORDING_NOT_STARTED = 2001
    const val USER_DENIED = 2002
    const val CREATE_PROJECTION_FAILED = 2003
    const val START_FAILED = 2004
    const val START_TIMEOUT = 2005
    const val LAUNCH_PERMISSION_ACTIVITY_FAILED = 2006
    const val MEDIA_RECORDER_ERROR = 2010
    const val DURATION_TOO_SHORT = 2011

    // 调整参数
    const val ADJUST_QUALITY_FAILED = 3003

    fun messageFor(code: Int): String = when (code) {
        OK -> "OK"
        RECORDING_ALREADY_IN_PROGRESS -> "Recording already in progress"
        RECORDING_NOT_STARTED -> "Recording not started"
        USER_DENIED -> "User denied screen capture permission"
        CREATE_PROJECTION_FAILED -> "Failed to create MediaProjection"
        START_FAILED -> "Start recording failed"
        START_TIMEOUT -> "Recording start timeout"
        LAUNCH_PERMISSION_ACTIVITY_FAILED -> "Failed to launch permission activity"
        MEDIA_RECORDER_ERROR -> "MediaRecorder error"
        DURATION_TOO_SHORT -> "Recording too short"
        ADJUST_QUALITY_FAILED -> "Failed to adjust quality"
        else -> "Unknown error"
    }

    fun result(
        code: Int,
        extraMessage: String? = null,
        filePath: String? = null,
        fileSize: Long = 0L,
        duration: Float = 0f,
        fileMd5: String? = null
    ): RecordingResult {
        val base = messageFor(code)
        val msg = if (!extraMessage.isNullOrBlank()) "$base: $extraMessage" else base
        return RecordingResult(
            isSuccess = code == OK,
            filePath = filePath,
            fileSize = fileSize,
            duration = duration,
            fileMd5 = fileMd5,
            errorCode = code,
            errorMessage = if (code == OK) null else msg
        )
    }
}


