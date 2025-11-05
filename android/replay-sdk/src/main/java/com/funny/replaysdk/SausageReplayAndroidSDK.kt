package com.funny.replaysdk

import android.app.Activity
import android.app.Application
import android.content.Context
import android.content.pm.PackageManager
import android.media.projection.MediaProjectionManager
import android.os.Build
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import android.media.MediaRecorder
import android.hardware.display.DisplayManager
import android.hardware.display.VirtualDisplay
import android.util.DisplayMetrics
import java.io.File
import android.os.Environment
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import android.os.Handler
import android.os.Looper
import android.os.HandlerThread
import java.util.concurrent.atomic.AtomicReference
import java.security.MessageDigest
import java.io.FileInputStream

object VideoQualityPreset {
    const val BASIC = 0      // 720p30
    const val STANDARD = 1   // 1080p30
    const val SMOOTH = 2     // 720p60
    const val HIGH_FPS = 3   // 1080p60
    const val ULTRA = 4      // 1440p/60
}

object SausageReplayAndroidSDK {
    @JvmStatic
    fun initialize(context: Context, preset: Int = VideoQualityPreset.STANDARD, enableDebugLog: Boolean = true): Boolean {
        Logger.setEnabled(enableDebugLog)
        Logger.d("SausageReplayAndroidSDK", "Main initialize method called with preset: $preset, debug=$enableDebugLog")
        Logger.d("SausageReplayAndroidSDK", "Context: ${context.javaClass.simpleName}")
        try {
            Logger.d("SausageReplayAndroidSDK", "Initializing DeviceTierManager with preset...")
            if (!DeviceTierManager.initializeWithPreset(context, preset)) {
                Logger.e("SausageReplayAndroidSDK", "Failed to initialize device tier manager")
                return false
            }
            Logger.d("SausageReplayAndroidSDK", "DeviceTierManager initialized successfully")
            StateHolder.deviceTierValue = preset
            StateHolder.appContext = context.applicationContext
            Logger.d("SausageReplayAndroidSDK", "StateHolder updated with preset: $preset")
            Logger.i("SausageReplayAndroidSDK", "SDK initialized successfully with preset: $preset")
            return true
        } catch (e: Exception) {
            Logger.e("SausageReplayAndroidSDK", "Failed to initialize SDK: ${e.message}", e)
            return false
        }
    }

    @JvmStatic
    fun isPlatformSupported(): Boolean {
        // API 版本校验（需要 MediaProjection）
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.LOLLIPOP) return false

        // 检查是否存在 H.264 编码器（video/avc）
        return try {
            val infos = android.media.MediaCodecList(android.media.MediaCodecList.ALL_CODECS).codecInfos
            infos.any { info ->
                info.isEncoder && info.supportedTypes.any { it.equals("video/avc", ignoreCase = true) }
            }
        } catch (_: Throwable) {
            false
        }
    }

    @JvmStatic
    fun getVersion(): String = "1.0.0"
    
    
    // ========== 高级API：性能监控相关 ==========
    
    /**
     * 创建性能监控器（高级API）
     * 用户需要性能监控时手动调用
     */
    @JvmStatic
    fun createPerformanceMonitor(callback: PerformanceCallback? = null): PerformanceMonitor? {
        return DeviceTierManager.createPerformanceMonitor(callback)
    }
    
    /**
     * 获取当前设备档位信息（高级API）
     */
    @JvmStatic
    fun getDeviceTierInfo(): DeviceTierInfo? {
        val tier = DeviceTierManager.getCurrentTier()
        val config = DeviceTierManager.getCurrentTierConfig()
        return if (config != null) {
            DeviceTierInfo(tier, config)
        } else null
    }
    
    
    /**
     * 重新加载设备档位配置（高级API）
     * 用于运行时更新配置
     */
    @JvmStatic
    fun reloadDeviceTierConfig(): Boolean {
        val context = StateHolder.appContext ?: return false
        return DeviceTierConfig.reloadConfig(context)
    }

    @JvmStatic
    fun release() {
        // 停止所有录制操作
        if (StateHolder.status.get() != RecordingStatus.IDLE) {
            RecordingManager.stopRecording { /* 忽略回调 */ }
        }
        
        // 性能监控由用户手动管理，不自动停止
        
        // 清理所有资源
        StateHolder.clear()
        
        // 停止工作线程
        StateHolder.recordingWorker.quit()
        
        // 释放设备档位管理器
        DeviceTierManager.release()
        
        Logger.d("SausageReplayAndroidSDK", "SDK released successfully")
    }
}


object RecordingStatus {
    const val IDLE = 0
    const val RECORDING = 1
    const val STOPPING = 2
}

// 录制回调接口
interface RecordingCallback {
    fun onRecordingStarted()
    fun onRecordingProgress(durationMs: Long, fileSizeBytes: Long)
    fun onRecordingStopped(result: RecordingResult)
    fun onRecordingError(errorCode: Int, errorMessage: String?)
    fun onRecordingQualityAdjusted(quality: Int) {}
}

// Unity 桥接回调接口
// Unity 回调接口已迁移到 UnityCallbacks.kt

data class RecordingConfig(
    val maxDurationSeconds: Int = 1800, // 30分钟 (30 * 60 = 1800秒)
    val maxFileSizeBytes: Long = 300L * 1024 * 1024, // 300MB
    val includeAudio: Boolean = true,
    val targetBitrate: Int = 0,
    val targetFps: Int = 30,
    val performanceTier: Int = VideoQualityPreset.STANDARD
)

data class RecordingResult(
    val isSuccess: Boolean,
    val filePath: String? = null,  // 相对路径（相对于 persistentDataPath）
    val fileSize: Long = 0,
    val duration: Float = 0f,
    val fileMd5: String? = null,    // 文件 MD5 值
    val errorCode: Int = 0,
    val errorMessage: String? = null
)


data class DetailedStatus(
    val status: Int,
    val hasProjection: Boolean,
    val hasRecorder: Boolean,
    val hasDisplay: Boolean,
    val outputFile: String?,
    val outputFileSize: Long,
    val deviceTier: Int? = null,
    val deviceTierName: String? = null,
    val maxResolution: String? = null,
    val currentResolution: String? = null,
    val currentBitrate: Long? = null
)

/**
 * 设备档位信息数据类（高级API）
 */
data class DeviceTierInfo(
    val tier: Int,
    val config: TierConfig
)

object RecordingManager {
    // Unity 回调引用
    private var unityRecordingCallback: UnityRecordingCallback? = null
    
    @JvmStatic
    fun setUnityRecordingCallback(callback: UnityRecordingCallback) {
        unityRecordingCallback = callback
    }
    
    // 统一分发 Unity 回调并打印日志
    private fun dispatchUnityCallback(event: String, block: (UnityRecordingCallback) -> Unit) {
        val cb = unityRecordingCallback
        if (cb == null) {
            Logger.d("UnityCallback", "$event skipped: no Unity callback set")
            return
        }
        Logger.d("UnityCallback", "$event dispatching...")
        try {
            block(cb)
            Logger.d("UnityCallback", "$event dispatched")
        } catch (t: Throwable) {
            Logger.w("UnityCallback", "$event error: ${t.message}")
        }
    }
    
    
    /**
     * 根据视频清晰度档位自动生成录制配置
     */
    private fun generateRecordingConfigFromPreset(): RecordingConfig {
        val preset = StateHolder.deviceTierValue
        
        Logger.d("RecordingManager", "Generating config for video quality preset: $preset")
        
        // 从配置文件获取档位配置
        val tierConfig = DeviceTierManager.getCurrentTierConfig()
        if (tierConfig != null) {
            Logger.d("RecordingManager", "Using config from file: ${tierConfig.name}")
            
            return RecordingConfig(
                maxDurationSeconds = 1800, // 30分钟 (30 * 60 = 1800秒)
                maxFileSizeBytes = 300L * 1024 * 1024, // 300MB
                includeAudio = true,
                targetBitrate = tierConfig.videoBitrate.default.toInt(),
                targetFps = tierConfig.targetFps.default,
                performanceTier = preset
            )
        } else {
            Logger.w("RecordingManager", "Failed to get tier config, using default values")
            
            // 降级到默认配置
            return RecordingConfig(
                maxDurationSeconds = 1800, // 30分钟 (30 * 60 = 1800秒)
                maxFileSizeBytes = 300L * 1024 * 1024, // 300MB
                includeAudio = true,
                targetBitrate = 8000000,
                targetFps = 30,
                performanceTier = VideoQualityPreset.STANDARD
            )
        }
    }
    
    @JvmStatic
    fun startRecording(activity: Activity): Boolean {
        return startRecording(activity, null)
    }
    
    @JvmStatic
    fun startRecording(activity: Activity, callback: RecordingCallback? = null): Boolean {
        return StateHolder.recordingWorker.enqueueTaskWithResult {
            if (StateHolder.status.get() != RecordingStatus.IDLE) {
                StateHolder.mainHandler.post {
                    callback?.onRecordingError(
                        ErrorCodes.RECORDING_ALREADY_IN_PROGRESS,
                        ErrorCodes.messageFor(ErrorCodes.RECORDING_ALREADY_IN_PROGRESS)
                    )
                }
                return@enqueueTaskWithResult false
            }
            
            // 根据视频清晰度档位自动生成录制配置
            val config = generateRecordingConfigFromPreset()
            Logger.d("RecordingManager", "Auto-generated config: $config")
            
            StateHolder.status.set(RecordingStatus.STOPPING) // 临时占位，避免重复点击
            StateHolder.currentConfig = config
            StateHolder.recordingCallback = callback
            val mpm = activity.getSystemService(Context.MEDIA_PROJECTION_SERVICE) as MediaProjectionManager
            CallbackStore.screenCaptureCallback = null // 清理上一次
            
            // 设置超时机制：10秒后如果状态还是STOPPING，自动重置为IDLE
            StateHolder.mainHandler.postAtTime({
                if (StateHolder.status.get() == RecordingStatus.STOPPING) {
                    Logger.w("RecordingManager", "Recording start timeout, resetting to IDLE")
                    StateHolder.status.set(RecordingStatus.IDLE)
                    try {
                        val cb = StateHolder.recordingCallback
                        if (cb != null) cb.onRecordingError(ErrorCodes.START_TIMEOUT, ErrorCodes.messageFor(ErrorCodes.START_TIMEOUT))
                        else unityRecordingCallback?.onRecordingError(ErrorCodes.START_TIMEOUT, ErrorCodes.messageFor(ErrorCodes.START_TIMEOUT))
                    } catch (_: Throwable) {}
                }
            }, TIMEOUT_TOKEN, System.currentTimeMillis() + 10000)
            
            // 使用代理授权 Activity 发起授权，避免依赖宿主主 Activity 的 onActivityResult 转发
            try {
                val intent = android.content.Intent(activity, ScreenCapturePermissionActivity::class.java)
                activity.startActivity(intent)
            } catch (e: Exception) {
                Logger.e("RecordingManager", "Failed to launch ScreenCapturePermissionActivity: ${e.message}", e)
                StateHolder.status.set(RecordingStatus.IDLE)
                StateHolder.mainHandler.post {
                    val msg = e.message
                    val finalMsg = ErrorCodes.messageFor(ErrorCodes.LAUNCH_PERMISSION_ACTIVITY_FAILED) + (if (!msg.isNullOrBlank()) ": ${msg}" else "")
                    val cb = StateHolder.recordingCallback
                    if (cb != null) cb.onRecordingError(ErrorCodes.LAUNCH_PERMISSION_ACTIVITY_FAILED, finalMsg)
                    else dispatchUnityCallback("onRecordingError") { it.onRecordingError(ErrorCodes.LAUNCH_PERMISSION_ACTIVITY_FAILED, finalMsg) }
                }
                return@enqueueTaskWithResult false
            }
            true
        }
    }
    
    @JvmStatic
    fun startRecording(activity: Activity, config: RecordingConfig, callback: RecordingCallback? = null): Boolean {
        return StateHolder.recordingWorker.enqueueTaskWithResult {
            if (StateHolder.status.get() != RecordingStatus.IDLE) {
                StateHolder.mainHandler.post {
                    callback?.onRecordingError(
                        ErrorCodes.RECORDING_ALREADY_IN_PROGRESS,
                        ErrorCodes.messageFor(ErrorCodes.RECORDING_ALREADY_IN_PROGRESS)
                    )
                }
                return@enqueueTaskWithResult false
            }
            StateHolder.status.set(RecordingStatus.STOPPING) // 临时占位，避免重复点击
            StateHolder.currentConfig = config
            StateHolder.recordingCallback = callback
            val mpm = activity.getSystemService(Context.MEDIA_PROJECTION_SERVICE) as MediaProjectionManager
            CallbackStore.screenCaptureCallback = null // 清理上一次
            
            // 设置超时机制：10秒后如果状态还是STOPPING，自动重置为IDLE
            StateHolder.mainHandler.postAtTime({
                if (StateHolder.status.get() == RecordingStatus.STOPPING) {
                    Logger.w("RecordingManager", "Recording start timeout, resetting to IDLE")
                    StateHolder.status.set(RecordingStatus.IDLE)
                    val cb = StateHolder.recordingCallback
                    if (cb != null) cb.onRecordingError(ErrorCodes.START_TIMEOUT, ErrorCodes.messageFor(ErrorCodes.START_TIMEOUT))
                    else dispatchUnityCallback("onRecordingError") { it.onRecordingError(ErrorCodes.START_TIMEOUT, ErrorCodes.messageFor(ErrorCodes.START_TIMEOUT)) }
                }
            }, TIMEOUT_TOKEN, System.currentTimeMillis() + 10000)
            
            // 华为等机型更稳：授权前预启动前台服务
            try {
                RecordingForegroundService.start(activity.applicationContext)
            } catch (t: Throwable) {
                Logger.w("RecordingManager", "Pre-start foreground service failed: ${t.message}")
            }

            try {
                val intent = android.content.Intent(activity, ScreenCapturePermissionActivity::class.java)
                activity.startActivity(intent)
            } catch (e: Exception) {
                Logger.e("RecordingManager", "Failed to launch ScreenCapturePermissionActivity: ${e.message}", e)
                StateHolder.status.set(RecordingStatus.IDLE)
                StateHolder.mainHandler.post {
                    val msg = e.message
                    val finalMsg = ErrorCodes.messageFor(ErrorCodes.LAUNCH_PERMISSION_ACTIVITY_FAILED) + (if (!msg.isNullOrBlank()) ": ${msg}" else "")
                    try {
                        val cb = StateHolder.recordingCallback
                        if (cb != null) cb.onRecordingError(ErrorCodes.LAUNCH_PERMISSION_ACTIVITY_FAILED, finalMsg)
                        else dispatchUnityCallback("onRecordingError") { it.onRecordingError(ErrorCodes.LAUNCH_PERMISSION_ACTIVITY_FAILED, finalMsg) }
                    } catch (_: Throwable) {}
                }
                return@enqueueTaskWithResult false
            }
            true
        }
    }

    @JvmStatic
    fun onActivityResult(requestCode: Int, resultCode: Int, data: android.content.Intent?) {
        if (requestCode != RequestCodes.SCREEN_CAPTURE) return
        StateHolder.recordingWorker.enqueueTask {
            val ctx = StateHolder.appContext ?: return@enqueueTask
            Logger.d("RecordingManager", "onActivityResult: resultCode=$resultCode, data=$data")
            
            if (resultCode != Activity.RESULT_OK || data == null) {
                Logger.d("RecordingManager", "onActivityResult: User denied or data null, resetting to IDLE")
                StateHolder.status.set(RecordingStatus.IDLE)
                StateHolder.mainHandler.post {
                    try {
                        val cb = StateHolder.recordingCallback
                        if (cb != null) cb.onRecordingError(ErrorCodes.USER_DENIED, ErrorCodes.messageFor(ErrorCodes.USER_DENIED))
                        else dispatchUnityCallback("onRecordingError") { it.onRecordingError(ErrorCodes.USER_DENIED, ErrorCodes.messageFor(ErrorCodes.USER_DENIED)) }
                    } catch (_: Throwable) {}
                }
                return@enqueueTask
            }
            // Android 14+ 要求在使用 MediaProjection 前启动带 mediaProjection 类型的前台服务
            try {
                RecordingForegroundService.start(ctx)
            } catch (t: Throwable) {
                Logger.w("RecordingManager", "Failed to start foreground service: ${t.message}")
            }
            startWithProjection(resultCode, data)
        }
    }

    /** 提供给前台服务直接调用，绕过Activity回调路径 */
    @JvmStatic
    fun startWithProjection(resultCode: Int, data: android.content.Intent) {
        StateHolder.recordingWorker.enqueueTask {
            val ctx = StateHolder.appContext ?: return@enqueueTask
            
            // 添加参数验证，防止崩溃
            if (resultCode != Activity.RESULT_OK || data == null) {
                Logger.w("RecordingManager", "startWithProjection: Invalid parameters - resultCode=$resultCode, data=$data")
                StateHolder.status.set(RecordingStatus.IDLE)
                StateHolder.mainHandler.post {
                    try {
                        val cb = StateHolder.recordingCallback
                        if (cb != null) cb.onRecordingError(ErrorCodes.USER_DENIED, ErrorCodes.messageFor(ErrorCodes.USER_DENIED))
                        else dispatchUnityCallback("onRecordingError") { it.onRecordingError(ErrorCodes.USER_DENIED, ErrorCodes.messageFor(ErrorCodes.USER_DENIED)) }
                    } catch (_: Throwable) {}
                }
                return@enqueueTask
            }
            
            // 确保前台服务已启动（华为等设备要求严格）
            try {
                RecordingForegroundService.start(ctx)
                // 给前台服务一点启动时间，特别是华为设备
                Thread.sleep(200)
            } catch (t: Throwable) {
                Logger.w("RecordingManager", "Failed to ensure foreground service: ${t.message}")
            }
            
            val mpm = ctx.getSystemService(Context.MEDIA_PROJECTION_SERVICE) as MediaProjectionManager
            val projection = mpm.getMediaProjection(resultCode, data)
            if (projection == null) {
                StateHolder.status.set(RecordingStatus.IDLE)
                try {
                    val cb = StateHolder.recordingCallback
                    if (cb != null) cb.onRecordingError(ErrorCodes.CREATE_PROJECTION_FAILED, ErrorCodes.messageFor(ErrorCodes.CREATE_PROJECTION_FAILED))
                    else dispatchUnityCallback("onRecordingError") { it.onRecordingError(ErrorCodes.CREATE_PROJECTION_FAILED, ErrorCodes.messageFor(ErrorCodes.CREATE_PROJECTION_FAILED)) }
                } catch (_: Throwable) {}
                return@enqueueTask
            }
            
            // 构建输出文件
            val output = buildOutputFile(ctx)
            val config = StateHolder.currentConfig ?: RecordingConfig()
            
            try {
                // 使用设备档位管理器计算录制参数
                val metrics = ctx.resources.displayMetrics
                val recordingParams = DeviceTierManager.calculateRecordingParams(
                    metrics,
                    if (config.targetBitrate > 0) config.targetBitrate.toLong() else null,
                    config.targetFps
                )
                
                Logger.d("RecordingManager", "Recording params: $recordingParams")

                val recorder = MediaRecorder()
                recorder.setVideoSource(MediaRecorder.VideoSource.SURFACE)
                if (config.includeAudio) {
                    recorder.setAudioSource(MediaRecorder.AudioSource.MIC)
                }
                recorder.setOutputFormat(MediaRecorder.OutputFormat.MPEG_4)
                recorder.setOutputFile(output.absolutePath)
                recorder.setVideoEncoder(MediaRecorder.VideoEncoder.H264)
                recorder.setVideoFrameRate(recordingParams.fps)
                recorder.setVideoEncodingBitRate(recordingParams.videoBitrate.toInt())
                recorder.setVideoSize(recordingParams.resolution.width, recordingParams.resolution.height)

                // 捕获底层错误，避免 native 崩溃扩散
                recorder.setOnErrorListener { _, what, extra ->
                    Logger.e("RecordingManager", "MediaRecorder error: what=$what extra=$extra")
                    StateHolder.mainHandler.post {
                        val msg = "MediaRecorder error: $what/$extra"
                        try {
                            val cb = StateHolder.recordingCallback
                            if (cb != null) cb.onRecordingError(ErrorCodes.MEDIA_RECORDER_ERROR, msg)
                            else dispatchUnityCallback("onRecordingError") { it.onRecordingError(ErrorCodes.MEDIA_RECORDER_ERROR, msg) }
                        } catch (_: Throwable) {}
                    }
                    try { recorder.reset() } catch (_: Throwable) {}
                    try { recorder.release() } catch (_: Throwable) {}
                    try { StateHolder.virtualDisplay?.release() } catch (_: Throwable) {}
                    try { StateHolder.mediaProjection?.stop() } catch (_: Throwable) {}
                    try { RecordingForegroundService.stop(ctx) } catch (_: Throwable) {}
                    StateHolder.clear()
                    StateHolder.status.set(RecordingStatus.IDLE)
                }
                
                // 设置关键帧间隔，提升视频质量（使用反射兼容旧版本）
                if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.N) {
                    try {
                        val method = MediaRecorder::class.java.getMethod("setVideoEncodingIFrameInterval", Int::class.javaPrimitiveType)
                        method.invoke(recorder, recordingParams.keyFrameInterval)
                        Logger.d("RecordingManager", "Set I-frame interval to ${recordingParams.keyFrameInterval}")
                    } catch (e: Exception) {
                        Logger.w("RecordingManager", "Failed to set I-frame interval: ${e.message}")
                    }
                }
                
                if (config.includeAudio) {
                    recorder.setAudioEncoder(MediaRecorder.AudioEncoder.AAC)
                    recorder.setAudioSamplingRate(recordingParams.audioSampleRate)
                    recorder.setAudioEncodingBitRate(recordingParams.audioBitrate.toInt())
                }
                
                // 尝试设置高质量编码参数（Android 7.0+）
                if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.N) {
                    try {
                        // 设置编码配置文件
                        when (recordingParams.encodingProfile) {
                            "HIGH" -> {
                                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                                    recorder.setVideoEncodingProfileLevel(
                                        android.media.MediaCodecInfo.CodecProfileLevel.AVCProfileHigh,
                                        android.media.MediaCodecInfo.CodecProfileLevel.AVCLevel4
                                    )
                                }
                            }
                            "MAIN" -> {
                                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                                    recorder.setVideoEncodingProfileLevel(
                                        android.media.MediaCodecInfo.CodecProfileLevel.AVCProfileMain,
                                        android.media.MediaCodecInfo.CodecProfileLevel.AVCLevel4
                                    )
                                }
                            }
                            "BASELINE" -> {
                                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                                    recorder.setVideoEncodingProfileLevel(
                                        android.media.MediaCodecInfo.CodecProfileLevel.AVCProfileBaseline,
                                        android.media.MediaCodecInfo.CodecProfileLevel.AVCLevel4
                                    )
                                }
                            }
                        }
                    } catch (e: Exception) {
                    Logger.w("RecordingManager", "Failed to set encoding profile: ${e.message}")
                    }
                }
                
                // 在 prepare 之前设置最大文件大小（部分设备要求时序严格）
                if (config.maxFileSizeBytes > 0) {
                    try { recorder.setMaxFileSize(config.maxFileSizeBytes) } catch (t: Throwable) {
                        Logger.w("RecordingManager", "setMaxFileSize not supported: ${t.message}")
                    }
                }

                // 在信息事件触发时（如到达最大时长/大小）进行平滑停止
                recorder.setOnInfoListener { _, what, extra ->
                    Logger.w("RecordingManager", "MediaRecorder info: what=$what extra=$extra")
                    if (what == MediaRecorder.MEDIA_RECORDER_INFO_MAX_FILESIZE_REACHED ||
                        what == MediaRecorder.MEDIA_RECORDER_INFO_MAX_DURATION_REACHED) {
                        StateHolder.mainHandler.post {
                            try { stopRecording { _ -> } } catch (_: Throwable) {}
                        }
                    }
                }

                recorder.prepare()

                val surface = recorder.surface
                val vDisplay = projection.createVirtualDisplay(
                    "replay-vd",
                    recordingParams.resolution.width,
                    recordingParams.resolution.height,
                    metrics.densityDpi,
                    DisplayManager.VIRTUAL_DISPLAY_FLAG_AUTO_MIRROR,
                    surface,
                    null,
                    null
                )

                recorder.start()
                
                StateHolder.mediaProjection = projection
                StateHolder.mediaRecorder = recorder
                StateHolder.virtualDisplay = vDisplay
                StateHolder.outputFile = output
                StateHolder.status.set(RecordingStatus.RECORDING)
                
                // 性能监控不再自动启动，用户需要时手动启动
                
                // 取消启动超时定时器
                StateHolder.mainHandler.removeCallbacksAndMessages(TIMEOUT_TOKEN)
                // 安排最大时长自动停止
                scheduleMaxDuration(config.maxDurationSeconds)
                // 启动进度监控
                startProgressMonitoring()
                // 通知录制开始
                StateHolder.mainHandler.post {
                    try {
                        val cb = StateHolder.recordingCallback
                        if (cb != null) cb.onRecordingStarted() else dispatchUnityCallback("onRecordingStarted") { it.onRecordingStarted() }
                    } catch (t: Throwable) {
                        Logger.w("RecordingManager", "callback error(onRecordingStarted): ${t.message}")
                    }
                }
            } catch (t: Throwable) {
                // 清理失败资源
                Logger.e("RecordingManager", "startWithProjection failed: ${t.message}", t)
                safeRelease()
                StateHolder.status.set(RecordingStatus.IDLE)
                StateHolder.mainHandler.post {
                    val finalMsg = ErrorCodes.messageFor(ErrorCodes.START_FAILED) + (t.message?.let { ": $it" } ?: "")
                    try {
                        val cb = StateHolder.recordingCallback
                        if (cb != null) cb.onRecordingError(ErrorCodes.START_FAILED, finalMsg)
                        else dispatchUnityCallback("onRecordingError") { it.onRecordingError(ErrorCodes.START_FAILED, finalMsg) }
                    } catch (_: Throwable) {}
                }
                try { RecordingForegroundService.stop(ctx) } catch (_: Throwable) {}
            }
        }
    }

    @JvmStatic
    fun stopRecording(callback: (RecordingResult) -> Unit) {
        StateHolder.recordingWorker.enqueueTask {
            val recorder = StateHolder.mediaRecorder
            val projection = StateHolder.mediaProjection
            val vDisplay = StateHolder.virtualDisplay
            val output = StateHolder.outputFile
            val currentStatus = StateHolder.status.get()
            
            // 添加调试日志
            Logger.d("RecordingManager", "stopRecording: status=$currentStatus, recorder=$recorder, projection=$projection, vDisplay=$vDisplay, output=$output")
            
            // 取消时长定时器和进度监控
            StateHolder.mainHandler.removeCallbacksAndMessages(AUTO_STOP_TOKEN)
            StateHolder.mainHandler.removeCallbacksAndMessages(PROGRESS_TOKEN)
            
            // 性能监控由用户手动管理，不自动停止
            
            // 检查状态是否允许停止
            if (currentStatus != RecordingStatus.RECORDING) {
                val result = ErrorCodes.result(ErrorCodes.RECORDING_NOT_STARTED, "status=$currentStatus")
                StateHolder.mainHandler.post { callback(result) }
                return@enqueueTask
            }
            
            if (recorder == null || projection == null || vDisplay == null || output == null) {
                val result = ErrorCodes.result(ErrorCodes.RECORDING_NOT_STARTED, "resources null")
                StateHolder.mainHandler.post { callback(result) }
                return@enqueueTask
            }
            try {
                StateHolder.status.set(RecordingStatus.STOPPING)
                recorder.stop()
                recorder.reset()
                vDisplay.release()
                projection.stop()
                recorder.release()
                // 停止前台服务
                try { RecordingForegroundService.stop(StateHolder.appContext!!) } catch (_: Throwable) {}
                // 读取文件时长（毫秒）
                val absolutePath = output.absolutePath
                var durationSec = 0f
                try {
                    val retriever = android.media.MediaMetadataRetriever()
                    retriever.setDataSource(absolutePath)
                    val durMs = retriever.extractMetadata(android.media.MediaMetadataRetriever.METADATA_KEY_DURATION)?.toLongOrNull() ?: 0L
                    retriever.release()
                    durationSec = (durMs / 1000f)
                } catch (t: Throwable) {
                    Logger.w("RecordingManager", "Failed to read duration: ${t.message}")
                }
                // 若时长不足 1 秒，删除文件并返回错误
                if (durationSec < 1f) {
                    kotlin.runCatching { output.delete() }
                    val code = ErrorCodes.DURATION_TOO_SHORT
                    val msg = ErrorCodes.messageFor(code)
                    val recordingCallback = StateHolder.recordingCallback
                    StateHolder.clear()
                    StateHolder.mainHandler.post {
                        try { recordingCallback?.onRecordingError(code, msg) } catch (_: Throwable) {}
                        dispatchUnityCallback("onRecordingError") { it.onRecordingError(code, msg) }
                        try { callback(RecordingResult(false, null, 0, 0f, null, code, msg)) } catch (_: Throwable) {}
                    }
                    return@enqueueTask
                }

                // 计算相对路径
                val relativePath = calculateRelativePath(absolutePath, StateHolder.appContext!!)
                if (relativePath == null) {
                    Logger.w("RecordingManager", "Failed to calculate relative path, using absolute path as fallback")
                }
                
                // 计算文件 MD5
                Logger.d("RecordingManager", "Calculating MD5 for file: $absolutePath")
                val fileMd5 = calculateFileMd5(output)
                if (fileMd5 == null) {
                    Logger.w("RecordingManager", "Failed to calculate MD5, continuing without MD5")
                } else {
                    Logger.d("RecordingManager", "File MD5: $fileMd5")
                }

                val result = RecordingResult(
                    isSuccess = true,
                    filePath = relativePath,  // 使用相对路径
                    fileSize = output.length(),
                    duration = durationSec,
                    fileMd5 = fileMd5,
                    errorCode = 0,
                    errorMessage = null
                )
                
                // 先保存回调和文件信息，再清理状态
                val recordingCallback = StateHolder.recordingCallback
                StateHolder.lastRecordedFile = output  // 保存最后录制的文件
                StateHolder.clear()
                
                StateHolder.mainHandler.post {
                    Logger.d("RecordingManager", "Calling onRecordingStopped callback")
                    try {
                        val cb = recordingCallback
                        if (cb != null) {
                            cb.onRecordingStopped(result)
                        } else {
                            dispatchUnityCallback("onRecordingStopped") {
                                it.onRecordingStopped(
                                    result.isSuccess,
                                    result.filePath,
                                    result.fileSize,
                                    result.duration,
                                    result.fileMd5,
                                    result.errorCode,
                                    result.errorMessage
                                )
                            }
                        }
                    } catch (t: Throwable) {
                        Logger.w("RecordingManager", "callback error(onRecordingStopped): ${t.message}")
                    }
                    Logger.d("RecordingManager", "Calling stopRecording callback")
                    try { callback(result) } catch (_: Throwable) {}
                }
            } catch (t: Throwable) {
                safeRelease()
                try { RecordingForegroundService.stop(StateHolder.appContext!!) } catch (_: Throwable) {}
                val result = ErrorCodes.result(ErrorCodes.START_FAILED, t.message)
                
                // 先保存回调，再清理状态
                val recordingCallback = StateHolder.recordingCallback
                StateHolder.clear()
                
                StateHolder.mainHandler.post {
                    try { recordingCallback?.onRecordingError(ErrorCodes.START_FAILED, ErrorCodes.messageFor(ErrorCodes.START_FAILED) + (t.message?.let { ": $it" } ?: "")) } catch (_: Throwable) {}
                    callback(result)
                }
            }
        }
    }

    /**
     * Unity 无参停止录制重载，匹配桥接调用签名 ()V。
     * 结果通过全局 unityRecordingCallback 回调给 Unity。
     */
    @JvmStatic
    fun stopRecording() {
        stopRecording { /* 结果已通过 unityRecordingCallback 回传，这里无需额外处理 */ }
    }




    @JvmStatic
    fun getRecordingStatus(): Int = StateHolder.status.get()
    
    // 录制中质量调整能力已移除，保留通过 initialize 切换 preset 影响下一次录制
    
    @JvmStatic
    fun resetStatus() {
        StateHolder.recordingWorker.enqueueTask {
            Logger.d("RecordingManager", "resetStatus: current=${StateHolder.status.get()}")
            
            // 取消所有定时器
            StateHolder.mainHandler.removeCallbacksAndMessages(AUTO_STOP_TOKEN)
            StateHolder.mainHandler.removeCallbacksAndMessages(TIMEOUT_TOKEN)
            StateHolder.mainHandler.removeCallbacksAndMessages(PROGRESS_TOKEN)
            
            // 安全释放资源
            safeRelease()
            
            // 重置状态
            StateHolder.status.set(RecordingStatus.IDLE)
            StateHolder.clear()
            
            Logger.d("RecordingManager", "resetStatus: completed")
        }
    }
    
    @JvmStatic
    fun getDetailedStatus(): DetailedStatus {
        val currentStatus = StateHolder.status.get()
        val hasProjection = StateHolder.mediaProjection != null
        val hasRecorder = StateHolder.mediaRecorder != null
        val hasDisplay = StateHolder.virtualDisplay != null
        
        // 优先使用当前录制文件，如果没有则使用最后录制的文件
        val outputFile = StateHolder.outputFile ?: StateHolder.lastRecordedFile
        
        // 获取设备档位信息
        val deviceTierInfo = SausageReplayAndroidSDK.getDeviceTierInfo()
        val deviceTier = deviceTierInfo?.tier
        val deviceTierName = deviceTierInfo?.config?.name
        val maxResolution = deviceTierInfo?.config?.let { "${it.maxResolution.width}x${it.maxResolution.height}" }
        
        // 获取当前录制参数（基于设备档位自动生成的配置）
        var currentResolution: String? = null
        var currentBitrate: Long? = null
        if (StateHolder.appContext != null) {
            try {
                val metrics = StateHolder.appContext!!.resources.displayMetrics
                val deviceTierValue = StateHolder.deviceTierValue
                val tierConfig = DeviceTierManager.getCurrentTierConfig()
                
                val recordingParams = DeviceTierManager.calculateRecordingParams(
                    metrics,
                    null, // 使用默认比特率
                    tierConfig?.targetFps?.default
                )
                currentResolution = "${recordingParams.resolution.width}x${recordingParams.resolution.height}"
                currentBitrate = recordingParams.videoBitrate
            } catch (e: Exception) {
                Logger.w("RecordingManager", "Failed to calculate current recording params: ${e.message}")
            }
        }
        
        return DetailedStatus(
            status = currentStatus,
            hasProjection = hasProjection,
            hasRecorder = hasRecorder,
            hasDisplay = hasDisplay,
            outputFile = outputFile?.absolutePath,
            outputFileSize = outputFile?.length() ?: 0L,
            deviceTier = deviceTier,
            deviceTierName = deviceTierName,
            maxResolution = maxResolution,
            currentResolution = currentResolution,
            currentBitrate = currentBitrate
        )
    }

    // Unity 桥接重载方法 - 返回 JSON 字符串
    @JvmStatic
    fun getDetailedStatusJson(): String {
        val status = getDetailedStatus()
        return try {
            org.json.JSONObject().apply {
                put("status", status.status)
                put("hasProjection", status.hasProjection)
                put("hasRecorder", status.hasRecorder)
                put("hasDisplay", status.hasDisplay)
                put("outputFile", status.outputFile ?: "")
                put("outputFileSize", status.outputFileSize)
                put("deviceTier", status.deviceTier ?: -1)
                put("deviceTierName", status.deviceTierName ?: "")
                put("maxResolution", status.maxResolution ?: "")
                put("currentResolution", status.currentResolution ?: "")
                put("currentBitrate", status.currentBitrate ?: 0)
            }.toString()
        } catch (e: Exception) {
            Logger.e("RecordingManager", "Failed to serialize DetailedStatus to JSON: ${e.message}", e)
            "{}"
        }
    }
    
    
    
    /**
     * 开始进度监控
     */
    private fun startProgressMonitoring() {
        val startTime = System.currentTimeMillis()
        val progressRunnable = object : Runnable {
            override fun run() {
                val currentStatus = StateHolder.status.get()
                if (currentStatus == RecordingStatus.RECORDING) {
                    val durationMs = System.currentTimeMillis() - startTime
                    val outputFile = StateHolder.outputFile
                    var fileSizeBytes = 0L
                    
                    // 尝试获取文件大小，添加错误处理
                    try {
                        if (outputFile != null && outputFile.exists()) {
                            fileSizeBytes = outputFile.length()
                        }
                    } catch (e: Exception) {
                        Logger.w("RecordingManager", "Failed to get file size: ${e.message}")
                    }
                    
                    // 性能监控由用户手动管理，不自动记录帧信息
                    
                    // 添加调试日志
                    Logger.d("RecordingManager", "Progress: duration=${durationMs}ms, fileSize=${fileSizeBytes}bytes, file=${outputFile?.absolutePath}")
                    
                    StateHolder.mainHandler.post {
                        try {
                            val cb = StateHolder.recordingCallback
                            if (cb != null) cb.onRecordingProgress(durationMs, fileSizeBytes)
                            else dispatchUnityCallback("onRecordingProgress") { it.onRecordingProgress(durationMs, fileSizeBytes) }
                        } catch (_: Throwable) {}
                    }
                    
                    // 将进度回调频率降为 1s，降低 Unity 主线程压力
                    StateHolder.mainHandler.postDelayed(this, 1000)
                } else {
                    // 录制结束，停止进度监控
                    Logger.d("RecordingManager", "Progress monitoring stopped, status=$currentStatus")
                }
            }
        }
        StateHolder.mainHandler.post(progressRunnable)
    }

}


private object RequestCodes {
    const val SCREEN_CAPTURE = 10002
}

private object CallbackStore {
    var screenCaptureCallback: ((Boolean, Int, String?) -> Unit)? = null
}

private object StateHolder {
    var appContext: Context? = null
    var deviceTier: Int = VideoQualityPreset.STANDARD
    var deviceTierValue: Int = 1  // 清晰度档位标识 (0=BASIC, 1=STANDARD, 2=SMOOTH, 3=HIGH_FPS, 4=ULTRA)
    val status: AtomicReference<Int> = AtomicReference(RecordingStatus.IDLE)
    var currentConfig: RecordingConfig? = null
    var mediaProjection: android.media.projection.MediaProjection? = null
    var mediaRecorder: MediaRecorder? = null
    var virtualDisplay: VirtualDisplay? = null
    var outputFile: File? = null
    var recordingCallback: RecordingCallback? = null
    val mainHandler: Handler = Handler(Looper.getMainLooper())
    
    // 保存最后录制的文件信息，用于状态查询
    var lastRecordedFile: File? = null
    
    // 工作线程和任务队列
    val recordingWorker: RecordingWorker by lazy { RecordingWorker() }
    
    fun clear() {
        // 不要清理appContext，因为转换功能需要它
        // appContext = null
        status.set(RecordingStatus.IDLE)
        currentConfig = null
        mediaProjection = null
        mediaRecorder = null
        virtualDisplay = null
        outputFile = null
        recordingCallback = null
    }
}

// 录制工作线程
private class RecordingWorker {
    private val workerThread = HandlerThread("RecordingWorker").apply { start() }
    private val workerHandler = Handler(workerThread.looper)
    private var isQuit = false
    
    fun enqueueTask(task: () -> Unit) {
        if (isQuit) {
            Logger.w("RecordingWorker", "Worker is quitting, task ignored")
            return
        }
        workerHandler.post(task)
    }
    
    fun enqueueTaskWithResult(task: () -> Boolean): Boolean {
        if (isQuit) {
            Logger.w("RecordingWorker", "Worker is quitting, task ignored")
            return false
        }
        
        var result = false
        val latch = java.util.concurrent.CountDownLatch(1)
        workerHandler.post {
            result = task()
            latch.countDown()
        }
        try {
            latch.await()
        } catch (e: InterruptedException) {
            Thread.currentThread().interrupt()
        }
        return result
    }
    
    fun quit() {
        isQuit = true
        workerHandler.removeCallbacksAndMessages(null)
        workerThread.quitSafely()
        try {
            workerThread.join(1000) // 等待最多1秒
        } catch (e: InterruptedException) {
            Thread.currentThread().interrupt()
        }
    }
}

private fun safeRelease() {
    try { StateHolder.virtualDisplay?.release() } catch (_: Throwable) {}
    try { StateHolder.mediaProjection?.stop() } catch (_: Throwable) {}
    try { StateHolder.mediaRecorder?.reset() } catch (_: Throwable) {}
    try { StateHolder.mediaRecorder?.release() } catch (_: Throwable) {}
    StateHolder.virtualDisplay = null
    StateHolder.mediaProjection = null
    StateHolder.mediaRecorder = null
}

private fun buildOutputFile(context: Context): File {
    val base = context.getExternalFilesDir(Environment.DIRECTORY_MOVIES) ?: context.filesDir
    val dir = File(base, "replay")
    if (!dir.exists()) {
        val created = dir.mkdirs()
        Logger.d("RecordingManager", "Created directory: $created, path: ${dir.absolutePath}")
    }
    val ts = SimpleDateFormat("yyyyMMdd_HHmmss", Locale.US).format(Date())
    val outputFile = File(dir, "replay_$ts.mp4")
    Logger.d("RecordingManager", "Output file: ${outputFile.absolutePath}, exists: ${outputFile.exists()}")
    return outputFile
}

/**
 * 计算文件的相对路径（相对于 persistentDataPath）
 * 返回格式：Movies/replay/replay_xxx.mp4 或 files/replay/replay_xxx.mp4
 * 
 * 注意：Unity 的 persistentDataPath 通常对应：
 * - 外部存储：/storage/emulated/0/Android/data/<包名>/files/
 * - 内部存储：/data/data/<包名>/files/
 * 
 * 因此，如果文件在 getExternalFilesDir(MOVIES) 下，相对路径应为 "Movies/replay/replay_xxx.mp4"
 * 如果文件在 filesDir 下，相对路径应为 "replay/replay_xxx.mp4"（需要从 filesDir 的父目录计算）
 */
private fun calculateRelativePath(absolutePath: String, context: Context): String? {
    // 外部存储：/storage/emulated/0/Android/data/<包名>/files/Movies/replay/replay_xxx.mp4
    val externalFilesDir = context.getExternalFilesDir(Environment.DIRECTORY_MOVIES)
    if (externalFilesDir != null && absolutePath.startsWith(externalFilesDir.absolutePath)) {
        // 文件在 Movies 目录下，需要从 getExternalFilesDir(null) 开始计算相对路径
        val baseExternalDir = context.getExternalFilesDir(null)
        if (baseExternalDir != null && absolutePath.startsWith(baseExternalDir.absolutePath)) {
            val relative = absolutePath.removePrefix(baseExternalDir.absolutePath).trimStart('/')
            Logger.d("RecordingManager", "Calculated relative path (external): $relative")
            return relative
        }
    }
    
    // 内部存储：/data/data/<包名>/files/Movies/replay/replay_xxx.mp4
    val filesDir = context.filesDir
    if (absolutePath.startsWith(filesDir.absolutePath)) {
        // 对于内部存储，persistentDataPath 就是 filesDir
        val relative = absolutePath.removePrefix(filesDir.absolutePath).trimStart('/')
        Logger.d("RecordingManager", "Calculated relative path (internal): $relative")
        return relative
    }
    
    Logger.w("RecordingManager", "Cannot calculate relative path for: $absolutePath")
    return null
}

/**
 * 计算文件的 MD5 值
 */
private fun calculateFileMd5(file: File): String? {
    return try {
        val md = MessageDigest.getInstance("MD5")
        val inputStream = FileInputStream(file)
        val buffer = ByteArray(8192)
        var bytesRead: Int
        while (inputStream.read(buffer).also { bytesRead = it } != -1) {
            md.update(buffer, 0, bytesRead)
        }
        inputStream.close()
        val digest = md.digest()
        digest.joinToString("") { "%02x".format(it) }
    } catch (e: Exception) {
        Logger.e("RecordingManager", "Failed to calculate MD5: ${e.message}", e)
        null
    }
}


// 旧的按质量枚举计算分辨率/码率的方法已移除

private const val AUTO_STOP_TOKEN = 0x9999
private const val TIMEOUT_TOKEN = 0x9998
private const val PROGRESS_TOKEN = 0x9997
private fun scheduleMaxDuration(maxSeconds: Int) {
    if (maxSeconds <= 0) return
    StateHolder.mainHandler.postAtTime({
        // 到时自动调用停止
        RecordingManager.stopRecording { /* 忽略回调，这里只做强制结束 */ }
    }, AUTO_STOP_TOKEN, System.currentTimeMillis() + maxSeconds * 1000L)
}



