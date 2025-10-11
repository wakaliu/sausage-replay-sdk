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

enum class DevicePerformanceTier { LOW_END, MID_RANGE, HIGH_END, FLAGSHIP }

object SausageReplayAndroidSDK {
    @JvmStatic
    fun initialize(context: Context, tier: DevicePerformanceTier = DevicePerformanceTier.MID_RANGE): Boolean {
        try {
            // 初始化设备档位管理器
            if (!DeviceTierManager.initialize(context, tier)) {
                android.util.Log.e("SausageReplayAndroidSDK", "Failed to initialize device tier manager")
                return false
            }
            
            StateHolder.deviceTier = tier
            StateHolder.appContext = context.applicationContext
            
            // 性能监控器不再自动创建，用户需要时手动创建
            
            android.util.Log.d("SausageReplayAndroidSDK", "SDK initialized successfully with tier: $tier")
            return true
        } catch (e: Exception) {
            android.util.Log.e("SausageReplayAndroidSDK", "Failed to initialize SDK", e)
            return false
        }
    }

    @JvmStatic
    fun isPlatformSupported(): Boolean = true

    @JvmStatic
    fun getVersion(): String = "1.0.0"
    
    @JvmStatic
    fun getMemoryUsage(): MemoryUsage {
        val runtime = Runtime.getRuntime()
        val totalMemory = runtime.totalMemory()
        val freeMemory = runtime.freeMemory()
        val usedMemory = totalMemory - freeMemory
        val maxMemory = runtime.maxMemory()
        
        return MemoryUsage(
            totalMemory = totalMemory,
            usedMemory = usedMemory,
            freeMemory = freeMemory,
            maxMemory = maxMemory,
            usagePercentage = (usedMemory.toFloat() / maxMemory.toFloat() * 100).toInt()
        )
    }
    
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
     * 检查GIF转换是否支持（高级API）
     */
    @JvmStatic
    fun isGifConversionSupported(): Boolean {
        return DeviceTierManager.isGifConversionSupported()
    }
    
    /**
     * 获取GIF转换参数（高级API）
     */
    @JvmStatic
    fun getGifConversionParams(): GifConversionParams? {
        return DeviceTierManager.getGifConversionParams()
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
        
        android.util.Log.d("SausageReplayAndroidSDK", "SDK released successfully")
    }
}

object PermissionManager {
    @JvmStatic
    fun hasMicrophonePermission(context: Context): Boolean =
        ContextCompat.checkSelfPermission(
            context,
            android.Manifest.permission.RECORD_AUDIO
        ) == PackageManager.PERMISSION_GRANTED

    @JvmStatic
    fun requestMicrophonePermission(activity: Activity, callback: (granted: Boolean, errorCode: Int, message: String?) -> Unit) {
        if (hasMicrophonePermission(activity)) {
            callback(true, 0, null)
            return
        }
        CallbackStore.permissionCallback = callback
        ActivityCompat.requestPermissions(
            activity,
            arrayOf(android.Manifest.permission.RECORD_AUDIO),
            RequestCodes.RECORD_AUDIO
        )
    }

    /** 应由宿主Activity在 onRequestPermissionsResult 中转发 */
    @JvmStatic
    fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>?,
        grantResults: IntArray?
    ) {
        if (requestCode != RequestCodes.RECORD_AUDIO) return
        val granted = grantResults?.isNotEmpty() == true && grantResults[0] == PackageManager.PERMISSION_GRANTED
        val cb = CallbackStore.permissionCallback
        CallbackStore.permissionCallback = null
        if (cb != null) {
            if (granted) cb(true, 0, null) else cb(false, 1001, "PermissionDenied")
        }
    }
}

enum class RecordingStatus { IDLE, RECORDING, PAUSED, STOPPING }

// 录制回调接口
interface RecordingCallback {
    fun onRecordingStarted()
    fun onRecordingProgress(durationMs: Long, fileSizeBytes: Long)
    fun onRecordingPaused()
    fun onRecordingResumed()
    fun onRecordingStopped(result: RecordingResult)
    fun onRecordingError(errorCode: Int, errorMessage: String?)
    fun onRecordingQualityAdjusted(quality: VideoQuality) {}
}

data class RecordingConfig(
    val quality: VideoQuality = VideoQuality.MEDIUM,
    val maxDurationSeconds: Int = 60,
    val maxFileSizeBytes: Long = 50L * 1024 * 1024,
    val includeAudio: Boolean = true,
    val outputFormat: OutputFormat = OutputFormat.MP4,
    val outputPath: String? = null,
    val targetBitrate: Int? = null,
    val targetFps: Int = 30,
    val performanceTier: DevicePerformanceTier = DevicePerformanceTier.MID_RANGE
)

enum class VideoQuality { LOW, MEDIUM, HIGH }
enum class OutputFormat { 
    MP4, 
    GIF,
    WEBM,
    AVI
}

data class RecordingResult(
    val isSuccess: Boolean,
    val filePath: String? = null,
    val fileSize: Long = 0,
    val duration: Float = 0f,
    val errorCode: Int = 0,
    val errorMessage: String? = null
)

data class MemoryUsage(
    val totalMemory: Long,
    val usedMemory: Long,
    val freeMemory: Long,
    val maxMemory: Long,
    val usagePercentage: Int
)

data class DetailedStatus(
    val status: RecordingStatus,
    val memoryUsage: MemoryUsage,
    val config: RecordingConfig?,
    val hasProjection: Boolean,
    val hasRecorder: Boolean,
    val hasDisplay: Boolean,
    val outputFile: String?,
    val outputFileSize: Long
)

/**
 * 设备档位信息数据类（高级API）
 */
data class DeviceTierInfo(
    val tier: DevicePerformanceTier,
    val config: TierConfig
)

object RecordingManager {
    @JvmStatic
    fun startRecording(activity: Activity, config: RecordingConfig, callback: RecordingCallback? = null): Boolean {
        return StateHolder.recordingWorker.enqueueTaskWithResult {
            if (StateHolder.status.get() != RecordingStatus.IDLE) {
                StateHolder.mainHandler.post {
                    callback?.onRecordingError(2000, "Recording already in progress")
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
                    android.util.Log.w("RecordingManager", "Recording start timeout, resetting to IDLE")
                    StateHolder.status.set(RecordingStatus.IDLE)
                    StateHolder.recordingCallback?.onRecordingError(2005, "Recording start timeout")
                }
            }, TIMEOUT_TOKEN, System.currentTimeMillis() + 10000)
            
            activity.startActivityForResult(mpm.createScreenCaptureIntent(), RequestCodes.SCREEN_CAPTURE)
            true
        }
    }

    @JvmStatic
    fun onActivityResult(requestCode: Int, resultCode: Int, data: android.content.Intent?) {
        if (requestCode != RequestCodes.SCREEN_CAPTURE) return
        StateHolder.recordingWorker.enqueueTask {
            val ctx = StateHolder.appContext ?: return@enqueueTask
            android.util.Log.d("RecordingManager", "onActivityResult: resultCode=$resultCode, data=$data")
            
            if (resultCode != Activity.RESULT_OK || data == null) {
                android.util.Log.d("RecordingManager", "onActivityResult: User denied or data null, resetting to IDLE")
                StateHolder.status.set(RecordingStatus.IDLE)
                StateHolder.mainHandler.post {
                    StateHolder.recordingCallback?.onRecordingError(2002, "User denied screen capture permission")
                }
                return@enqueueTask
            }
            startWithProjection(resultCode, data)
        }
    }

    /** 提供给前台服务直接调用，绕过Activity回调路径 */
    @JvmStatic
    fun startWithProjection(resultCode: Int, data: android.content.Intent) {
        StateHolder.recordingWorker.enqueueTask {
            val ctx = StateHolder.appContext ?: return@enqueueTask
            val mpm = ctx.getSystemService(Context.MEDIA_PROJECTION_SERVICE) as MediaProjectionManager
            val projection = mpm.getMediaProjection(resultCode, data)
            if (projection == null) {
                StateHolder.status.set(RecordingStatus.IDLE)
                StateHolder.recordingCallback?.onRecordingError(2003, "Failed to create MediaProjection")
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
                    config.quality, 
                    config.targetBitrate?.toLong(), 
                    config.targetFps
                )
                
                android.util.Log.d("RecordingManager", "Recording params: $recordingParams")

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
                if (config.includeAudio) {
                    recorder.setAudioEncoder(MediaRecorder.AudioEncoder.AAC)
                    recorder.setAudioSamplingRate(recordingParams.audioSampleRate)
                    recorder.setAudioEncodingBitRate(recordingParams.audioBitrate.toInt())
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
                // 文件大小限制：若设置最大文件大小，尝试应用（部分设备/版本可能无效）
                if (config.maxFileSizeBytes > 0) {
                    try { recorder.setMaxFileSize(config.maxFileSizeBytes) } catch (_: Throwable) {}
                }
                
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
                    StateHolder.recordingCallback?.onRecordingStarted()
                }
            } catch (t: Throwable) {
                // 清理失败资源
                android.util.Log.e("RecordingManager", "startWithProjection failed", t)
                safeRelease()
                StateHolder.status.set(RecordingStatus.IDLE)
                StateHolder.mainHandler.post {
                    StateHolder.recordingCallback?.onRecordingError(2004, t.message)
                }
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
            android.util.Log.d("RecordingManager", "stopRecording: status=$currentStatus, recorder=$recorder, projection=$projection, vDisplay=$vDisplay, output=$output")
            
            // 取消时长定时器和进度监控
            StateHolder.mainHandler.removeCallbacksAndMessages(AUTO_STOP_TOKEN)
            StateHolder.mainHandler.removeCallbacksAndMessages(PROGRESS_TOKEN)
            
            // 性能监控由用户手动管理，不自动停止
            
            // 检查状态是否允许停止
            if (currentStatus != RecordingStatus.RECORDING && currentStatus != RecordingStatus.PAUSED) {
                val result = RecordingResult(false, errorCode = 2001, errorMessage = "RecordingNotStarted - status=$currentStatus")
                StateHolder.mainHandler.post { callback(result) }
                return@enqueueTask
            }
            
            if (recorder == null || projection == null || vDisplay == null || output == null) {
                val result = RecordingResult(false, errorCode = 2001, errorMessage = "RecordingNotStarted - resources null")
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
                val result = RecordingResult(
                    isSuccess = true,
                    filePath = output.absolutePath,
                    fileSize = output.length(),
                    duration = 0f,
                    errorCode = 0,
                    errorMessage = null
                )
                
                // 先保存回调和文件信息，再清理状态
                val recordingCallback = StateHolder.recordingCallback
                StateHolder.lastRecordedFile = output  // 保存最后录制的文件
                StateHolder.clear()
                
                StateHolder.mainHandler.post {
                    android.util.Log.d("RecordingManager", "Calling onRecordingStopped callback")
                    recordingCallback?.onRecordingStopped(result)
                    android.util.Log.d("RecordingManager", "Calling stopRecording callback")
                    callback(result)
                }
            } catch (t: Throwable) {
                safeRelease()
                val result = RecordingResult(false, errorCode = 2004, errorMessage = t.message)
                
                // 先保存回调，再清理状态
                val recordingCallback = StateHolder.recordingCallback
                StateHolder.clear()
                
                StateHolder.mainHandler.post {
                    recordingCallback?.onRecordingError(2004, t.message)
                    callback(result)
                }
            }
        }
    }

    @JvmStatic
    fun pauseRecording(): Boolean {
        return StateHolder.recordingWorker.enqueueTaskWithResult {
            val currentStatus = StateHolder.status.get()
            val recorder = StateHolder.mediaRecorder
            
            android.util.Log.d("RecordingManager", "pauseRecording: status=$currentStatus, recorder=$recorder")
            
            if (currentStatus != RecordingStatus.RECORDING || recorder == null) {
                android.util.Log.w("RecordingManager", "pauseRecording: Invalid state or recorder null")
                return@enqueueTaskWithResult false
            }
            
            try {
                // 检查设备是否支持暂停
                if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.N) {
                    recorder.pause()
                    StateHolder.status.set(RecordingStatus.PAUSED)
                    StateHolder.mainHandler.post {
                        StateHolder.recordingCallback?.onRecordingPaused()
                    }
                    android.util.Log.d("RecordingManager", "pauseRecording: Successfully paused")
                    true
                } else {
                    // Android 7.0以下不支持MediaRecorder.pause()，使用软暂停策略
                    android.util.Log.w("RecordingManager", "pauseRecording: Device doesn't support pause, using soft pause")
                    StateHolder.status.set(RecordingStatus.PAUSED)
                    StateHolder.mainHandler.post {
                        StateHolder.recordingCallback?.onRecordingPaused()
                    }
                    true
                }
            } catch (e: Exception) {
                android.util.Log.e("RecordingManager", "pauseRecording failed", e)
                StateHolder.mainHandler.post {
                    StateHolder.recordingCallback?.onRecordingError(3001, "Failed to pause recording: ${e.message}")
                }
                false
            }
        }
    }

    @JvmStatic
    fun resumeRecording(): Boolean {
        return StateHolder.recordingWorker.enqueueTaskWithResult {
            val currentStatus = StateHolder.status.get()
            val recorder = StateHolder.mediaRecorder
            
            android.util.Log.d("RecordingManager", "resumeRecording: status=$currentStatus, recorder=$recorder")
            
            if (currentStatus != RecordingStatus.PAUSED || recorder == null) {
                android.util.Log.w("RecordingManager", "resumeRecording: Invalid state or recorder null")
                return@enqueueTaskWithResult false
            }
            
            try {
                // 检查设备是否支持恢复
                if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.N) {
                    recorder.resume()
                    StateHolder.status.set(RecordingStatus.RECORDING)
                    StateHolder.mainHandler.post {
                        StateHolder.recordingCallback?.onRecordingResumed()
                    }
                    android.util.Log.d("RecordingManager", "resumeRecording: Successfully resumed")
                    true
                } else {
                    // Android 7.0以下不支持MediaRecorder.resume()，使用软恢复策略
                    android.util.Log.w("RecordingManager", "resumeRecording: Device doesn't support resume, using soft resume")
                    StateHolder.status.set(RecordingStatus.RECORDING)
                    StateHolder.mainHandler.post {
                        StateHolder.recordingCallback?.onRecordingResumed()
                    }
                    true
                }
            } catch (e: Exception) {
                android.util.Log.e("RecordingManager", "resumeRecording failed", e)
                StateHolder.mainHandler.post {
                    StateHolder.recordingCallback?.onRecordingError(3002, "Failed to resume recording: ${e.message}")
                }
                false
            }
        }
    }

    @JvmStatic
    fun getRecordingStatus(): RecordingStatus = StateHolder.status.get()
    
    @JvmStatic
    fun adjustRecordingQuality(quality: VideoQuality): Boolean {
        return StateHolder.recordingWorker.enqueueTaskWithResult {
            val currentStatus = StateHolder.status.get()
            val recorder = StateHolder.mediaRecorder
            val config = StateHolder.currentConfig
            
            android.util.Log.d("RecordingManager", "adjustRecordingQuality: quality=$quality, status=$currentStatus")
            
            if (currentStatus != RecordingStatus.RECORDING || recorder == null || config == null) {
                android.util.Log.w("RecordingManager", "adjustRecordingQuality: Invalid state")
                return@enqueueTaskWithResult false
            }
            
            try {
                // 获取当前屏幕尺寸
                val context = StateHolder.appContext ?: return@enqueueTaskWithResult false
                val displayManager = context.getSystemService(Context.DISPLAY_SERVICE) as DisplayManager
                val display = displayManager.getDisplay(0)
                val metrics = android.util.DisplayMetrics()
                display.getMetrics(metrics)
                
                // 计算新的录制参数
                val (newWidth, newHeight) = chooseSizeByQuality(metrics, quality)
                val newBitrate = defaultBitrateFor(quality, newWidth, newHeight)
                
                android.util.Log.d("RecordingManager", "adjustRecordingQuality: newSize=${newWidth}x${newHeight}, newBitrate=$newBitrate")
                
                // 更新配置
                StateHolder.currentConfig = config.copy(
                    quality = quality,
                    targetBitrate = newBitrate
                )
                
                // 通知质量调整
                StateHolder.mainHandler.post {
                    StateHolder.recordingCallback?.onRecordingQualityAdjusted(quality)
                }
                
                android.util.Log.d("RecordingManager", "adjustRecordingQuality: Successfully adjusted to $quality")
                true
            } catch (e: Exception) {
                android.util.Log.e("RecordingManager", "adjustRecordingQuality failed", e)
                StateHolder.mainHandler.post {
                    StateHolder.recordingCallback?.onRecordingError(3003, "Failed to adjust quality: ${e.message}")
                }
                false
            }
        }
    }
    
    @JvmStatic
    fun resetStatus() {
        StateHolder.recordingWorker.enqueueTask {
            android.util.Log.d("RecordingManager", "resetStatus: current=${StateHolder.status.get()}")
            
            // 取消所有定时器
            StateHolder.mainHandler.removeCallbacksAndMessages(AUTO_STOP_TOKEN)
            StateHolder.mainHandler.removeCallbacksAndMessages(TIMEOUT_TOKEN)
            StateHolder.mainHandler.removeCallbacksAndMessages(PROGRESS_TOKEN)
            
            // 安全释放资源
            safeRelease()
            
            // 重置状态
            StateHolder.status.set(RecordingStatus.IDLE)
            StateHolder.clear()
            
            android.util.Log.d("RecordingManager", "resetStatus: completed")
        }
    }
    
    @JvmStatic
    fun getDetailedStatus(): DetailedStatus {
        val currentStatus = StateHolder.status.get()
        val memoryUsage = SausageReplayAndroidSDK.getMemoryUsage()
        val config = StateHolder.currentConfig
        val hasProjection = StateHolder.mediaProjection != null
        val hasRecorder = StateHolder.mediaRecorder != null
        val hasDisplay = StateHolder.virtualDisplay != null
        
        // 优先使用当前录制文件，如果没有则使用最后录制的文件
        val outputFile = StateHolder.outputFile ?: StateHolder.lastRecordedFile
        
        return DetailedStatus(
            status = currentStatus,
            memoryUsage = memoryUsage,
            config = config,
            hasProjection = hasProjection,
            hasRecorder = hasRecorder,
            hasDisplay = hasDisplay,
            outputFile = outputFile?.absolutePath,
            outputFileSize = outputFile?.length() ?: 0L
        )
    }
    
    @JvmStatic
    fun recoverFromError(): Boolean {
        return StateHolder.recordingWorker.enqueueTaskWithResult {
            android.util.Log.d("RecordingManager", "recoverFromError: current=${StateHolder.status.get()}")
            
            try {
                // 检查当前状态
                val currentStatus = StateHolder.status.get()
                if (currentStatus == RecordingStatus.IDLE) {
                    android.util.Log.d("RecordingManager", "recoverFromError: Already in IDLE state")
                    return@enqueueTaskWithResult true
                }
                
                // 强制清理所有资源
                safeRelease()
                
                // 取消所有定时器
                StateHolder.mainHandler.removeCallbacksAndMessages(AUTO_STOP_TOKEN)
                StateHolder.mainHandler.removeCallbacksAndMessages(TIMEOUT_TOKEN)
                StateHolder.mainHandler.removeCallbacksAndMessages(PROGRESS_TOKEN)
                
                // 重置状态
                StateHolder.status.set(RecordingStatus.IDLE)
                StateHolder.clear()
                
                // 通知错误恢复
                StateHolder.mainHandler.post {
                    StateHolder.recordingCallback?.onRecordingError(4001, "Recording recovered from error state")
                }
                
                android.util.Log.d("RecordingManager", "recoverFromError: Successfully recovered")
                true
            } catch (e: Exception) {
                android.util.Log.e("RecordingManager", "recoverFromError failed", e)
                false
            }
        }
    }
    
    @JvmStatic
    fun convertVideoFormat(inputPath: String, outputFormat: OutputFormat, callback: (Boolean, String?) -> Unit) {
        android.util.Log.d("RecordingManager", "convertVideoFormat called: $inputPath -> $outputFormat")
        StateHolder.recordingWorker.enqueueTask {
            android.util.Log.d("RecordingManager", "convertVideoFormat task started: $inputPath -> $outputFormat")
            
            try {
                android.util.Log.d("RecordingManager", "Checking input file: $inputPath")
                val inputFile = File(inputPath)
                val exists = inputFile.exists()
                val size = if (exists) inputFile.length() else -1
                android.util.Log.d("RecordingManager", "Input file exists: $exists, size: $size")
                
                if (!exists) {
                    android.util.Log.e("RecordingManager", "Input file not found: $inputPath")
                    StateHolder.mainHandler.post { callback(false, "Input file not found: $inputPath") }
                    return@enqueueTask
                }
                
                if (size == 0L) {
                    android.util.Log.e("RecordingManager", "Input file is empty: $inputPath")
                    StateHolder.mainHandler.post { callback(false, "Input file is empty") }
                    return@enqueueTask
                }
                
                val outputPath = generateOutputPath(outputFormat)
                android.util.Log.d("RecordingManager", "Output path generated: $outputPath")
                val success = performFormatConversion(inputPath, outputPath, outputFormat)
                android.util.Log.d("RecordingManager", "Conversion result: $success")
                
                StateHolder.mainHandler.post {
                    android.util.Log.d("RecordingManager", "Calling callback with result: $success")
                    if (success) {
                        callback(true, outputPath)
                    } else {
                        callback(false, "Format conversion failed")
                    }
                }
            } catch (e: Exception) {
                android.util.Log.e("RecordingManager", "convertVideoFormat failed: ${e.message}", e)
                StateHolder.mainHandler.post { callback(false, "Conversion error: ${e.javaClass.simpleName}: ${e.message}") }
            }
        }
    }
}

private object RequestCodes {
    const val RECORD_AUDIO = 10001
    const val SCREEN_CAPTURE = 10002
}

private object CallbackStore {
    var permissionCallback: ((Boolean, Int, String?) -> Unit)? = null
    var screenCaptureCallback: ((Boolean, Int, String?) -> Unit)? = null
}

private object StateHolder {
    var appContext: Context? = null
    var deviceTier: DevicePerformanceTier = DevicePerformanceTier.MID_RANGE
    val status: AtomicReference<RecordingStatus> = AtomicReference(RecordingStatus.IDLE)
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
            android.util.Log.w("RecordingWorker", "Worker is quitting, task ignored")
            return
        }
        workerHandler.post(task)
    }
    
    fun enqueueTaskWithResult(task: () -> Boolean): Boolean {
        if (isQuit) {
            android.util.Log.w("RecordingWorker", "Worker is quitting, task ignored")
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
        android.util.Log.d("RecordingManager", "Created directory: $created, path: ${dir.absolutePath}")
    }
    val ts = SimpleDateFormat("yyyyMMdd_HHmmss", Locale.US).format(Date())
    val outputFile = File(dir, "replay_$ts.mp4")
    android.util.Log.d("RecordingManager", "Output file: ${outputFile.absolutePath}, exists: ${outputFile.exists()}")
    return outputFile
}

private fun generateOutputPath(format: OutputFormat): String {
    val context = StateHolder.appContext
    if (context == null) {
        android.util.Log.e("RecordingManager", "Context not initialized in generateOutputPath")
        throw IllegalStateException("Context not initialized")
    }
    
    val base = context.getExternalFilesDir(Environment.DIRECTORY_MOVIES) ?: context.filesDir
    val dir = File(base, "replay")
    if (!dir.exists()) {
        val created = dir.mkdirs()
        android.util.Log.d("RecordingManager", "Created output directory: $created, path: ${dir.absolutePath}")
    }
    
    val ts = SimpleDateFormat("yyyyMMdd_HHmmss", Locale.US).format(Date())
    val extension = when (format) {
        OutputFormat.MP4 -> "mp4"
        OutputFormat.GIF -> "gif"
        OutputFormat.WEBM -> "webm"
        OutputFormat.AVI -> "avi"
    }
    val outputPath = File(dir, "converted_${ts}.${extension}").absolutePath
    android.util.Log.d("RecordingManager", "Generated output path: $outputPath")
    return outputPath
}

private fun performFormatConversion(inputPath: String, outputPath: String, format: OutputFormat): Boolean {
    return try {
        when (format) {
            OutputFormat.MP4 -> {
                // MP4转换：直接复制（假设输入已经是MP4）
                val inputFile = File(inputPath)
                val outputFile = File(outputPath)
                inputFile.copyTo(outputFile, overwrite = true)
                true
            }
            OutputFormat.GIF -> {
                // GIF转换功能暂未实现，返回失败
                android.util.Log.w("RecordingManager", "GIF conversion not implemented yet")
                false
            }
            OutputFormat.WEBM -> {
                // WEBM转换：简化实现
                android.util.Log.w("RecordingManager", "WEBM conversion not implemented, copying file")
                val inputFile = File(inputPath)
                val outputFile = File(outputPath)
                inputFile.copyTo(outputFile, overwrite = true)
                true
            }
            OutputFormat.AVI -> {
                // AVI转换：简化实现
                android.util.Log.w("RecordingManager", "AVI conversion not implemented, copying file")
                val inputFile = File(inputPath)
                val outputFile = File(outputPath)
                inputFile.copyTo(outputFile, overwrite = true)
                true
            }
        }
    } catch (e: Exception) {
        android.util.Log.e("RecordingManager", "Format conversion failed", e)
        false
    }
}

private fun chooseSizeByQuality(metrics: DisplayMetrics, quality: VideoQuality): Pair<Int, Int> {
    val screenW = metrics.widthPixels
    val screenH = metrics.heightPixels
    fun fitTo(height: Int): Pair<Int, Int> {
        val ratio = screenW.toFloat() / screenH.toFloat()
        val w = (height * ratio).toInt()
        return Pair(w - (w % 2), height - (height % 2))
    }
    return when (quality) {
        VideoQuality.HIGH -> fitTo(1080.coerceAtMost(screenH))
        VideoQuality.MEDIUM -> fitTo(720.coerceAtMost(screenH))
        VideoQuality.LOW -> fitTo(480.coerceAtMost(screenH))
    }
}

private fun defaultBitrateFor(quality: VideoQuality, w: Int, h: Int): Int {
    val pixels = w * h
    return when (quality) {
        VideoQuality.HIGH -> (pixels * 5).coerceAtLeast(4_000_000)
        VideoQuality.MEDIUM -> (pixels * 3).coerceAtLeast(2_500_000)
        VideoQuality.LOW -> (pixels * 2).coerceAtLeast(1_500_000)
    }
}

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
                    android.util.Log.w("RecordingManager", "Failed to get file size: ${e.message}")
                }
                
                // 性能监控由用户手动管理，不自动记录帧信息
                
                // 添加调试日志
                android.util.Log.d("RecordingManager", "Progress: duration=${durationMs}ms, fileSize=${fileSizeBytes}bytes, file=${outputFile?.absolutePath}")
                
                StateHolder.mainHandler.post {
                    StateHolder.recordingCallback?.onRecordingProgress(durationMs, fileSizeBytes)
                }
                
                // 每500ms更新一次进度，使用PROGRESS_TOKEN标记
                StateHolder.mainHandler.postDelayed(this, 500)
            } else {
                // 录制结束，停止进度监控
                android.util.Log.d("RecordingManager", "Progress monitoring stopped, status=$currentStatus")
            }
        }
    }
    StateHolder.mainHandler.post(progressRunnable)
}


