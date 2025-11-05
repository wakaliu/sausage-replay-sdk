package com.funny.replaysdk

import android.content.Context
import android.util.DisplayMetrics
import com.funny.replaysdk.Logger
import java.util.concurrent.atomic.AtomicReference

/**
 * 视频清晰度档位管理器
 * 负责视频清晰度档位配置管理和自适应控制
 */
object DeviceTierManager {
    
    private const val TAG = "DeviceTierManager"
    
    private var currentTier = AtomicReference(1) // 默认使用 STANDARD 档位
    private var tierConfig: TierConfig? = null
    private var adaptiveStrategies: AdaptiveStrategies? = null
    private var performanceMonitor: PerformanceMonitor? = null
    private var isInitialized = false
    
    
    /**
     * 使用视频清晰度档位初始化设备档位管理器
     * @param context 应用上下文
     * @param preset 视频清晰度档位整型值 (0=BASIC, 1=STANDARD, 2=SMOOTH, 3=HIGH_FPS, 4=ULTRA)
     * @return 是否初始化成功
     */
    fun initializeWithPreset(context: Context, preset: Int): Boolean {
        return try {
            Logger.d(TAG, "initializeWithPreset called with preset: $preset")
            
            // 加载配置文件
            if (!DeviceTierConfig.loadConfig(context)) {
                Logger.w(TAG, "Failed to load config, using default values")
            }
            
            // 直接使用视频清晰度档位
            currentTier.set(preset)
            tierConfig = DeviceTierConfig.getPresetConfig(preset)
            adaptiveStrategies = DeviceTierConfig.getAdaptiveStrategies()
            
            Logger.i(TAG, "Device tier manager initialized with preset: $preset")
            isInitialized = true
            true
        } catch (e: Exception) {
            Logger.e(TAG, "Failed to initialize device tier manager with preset: $preset", e)
            false
        }
    }
    
    /**
     * 获取当前设备档位
     */
    fun getCurrentTier(): Int = currentTier.get()
    
    /**
     * 获取当前档位配置
     */
    fun getCurrentTierConfig(): TierConfig? = tierConfig
    
    /**
     * 获取自适应策略
     */
    fun getAdaptiveStrategies(): AdaptiveStrategies? = adaptiveStrategies
    
    /**
     * 创建性能监控器
     */
    fun createPerformanceMonitor(callback: PerformanceCallback? = null): PerformanceMonitor? {
        val config = tierConfig ?: return null
        val strategies = adaptiveStrategies ?: return null
        
        return PerformanceMonitor(config, strategies, callback)
    }
    
    /**
     * 根据档位配置计算录制参数
     */
    fun calculateRecordingParams(
        screenMetrics: DisplayMetrics,
        customBitrate: Long? = null,
        customFps: Int? = null
    ): RecordingParams {
        val config = tierConfig ?: throw IllegalStateException("Device tier manager not initialized")
        
        // 计算分辨率（按屏幕比例不超过 maxResolution）
        val resolution = calculateResolution(screenMetrics, config)
        
        // 计算比特率
        val bitrate = customBitrate ?: config.videoBitrate.default
        
        // 计算FPS
        val fps = customFps ?: config.targetFps.default
        
        // 计算音频参数
        val audioBitrate = config.audioBitrate.default
        val audioSampleRate = config.audioSampleRate
        
        return RecordingParams(
            resolution = resolution,
            videoBitrate = bitrate,
            audioBitrate = audioBitrate,
            fps = fps,
            audioSampleRate = audioSampleRate,
            keyFrameInterval = config.keyFrameInterval,
            encodingProfile = config.encodingProfile,
            bufferDepth = config.bufferDepth,
            threadCount = config.threadCount
        )
    }
    
    
    /**
     * 应用自适应调整
     */
    fun applyAdaptiveAdjustment(
        baseParams: RecordingParams,
        bitrateReduction: Double = 0.0,
        resolutionIndex: Int = 0,
        fpsIndex: Int = 0
    ): RecordingParams {
        val strategies = adaptiveStrategies ?: return baseParams
        
        // 应用比特率调整
        val adjustedBitrate = if (bitrateReduction > 0) {
            (baseParams.videoBitrate * (1.0 - bitrateReduction)).toLong()
        } else {
            baseParams.videoBitrate
        }
        
        // 应用分辨率调整
        val adjustedResolution = if (resolutionIndex > 0 && resolutionIndex < strategies.resolutionDegradation.steps.size) {
            strategies.resolutionDegradation.steps[resolutionIndex]
        } else {
            baseParams.resolution
        }
        
        // 应用FPS调整
        val adjustedFps = if (fpsIndex > 0 && fpsIndex < strategies.fpsDegradation.steps.size) {
            strategies.fpsDegradation.steps[fpsIndex]
        } else {
            baseParams.fps
        }
        
        return baseParams.copy(
            resolution = adjustedResolution,
            videoBitrate = adjustedBitrate,
            fps = adjustedFps
        )
    }
    
    
    /**
     * 计算分辨率
     */
    private fun calculateResolution(
        screenMetrics: DisplayMetrics,
        config: TierConfig
    ): Resolution {
        val screenWidth = screenMetrics.widthPixels
        val screenHeight = screenMetrics.heightPixels
        val maxWidth = config.maxResolution.width
        val maxHeight = config.maxResolution.height
        
        // 以不超过 max 分辨率为前提，按屏幕高适配，保持宽高比
        val targetHeight = maxHeight
        
        // 保持宽高比
        val aspectRatio = screenWidth.toFloat() / screenHeight.toFloat()
        val targetWidth = (targetHeight * aspectRatio).toInt()
        
        // 确保是偶数（编码要求）
        val finalWidth = (targetWidth / 2) * 2
        val finalHeight = (targetHeight / 2) * 2
        
        return Resolution(
            width = finalWidth.coerceAtMost(maxWidth),
            height = finalHeight.coerceAtMost(maxHeight)
        )
    }
    
    /**
     * 计算比特率
     */
    // 码率直接使用配置默认值或调用者覆盖
    
    /**
     * 检查是否已初始化
     */
    fun isInitialized(): Boolean = isInitialized
    
    /**
     * 释放资源
     */
    fun release() {
        performanceMonitor?.stopMonitoring()
        performanceMonitor = null
        tierConfig = null
        adaptiveStrategies = null
        isInitialized = false
        Logger.d(TAG, "Device tier manager released")
    }
}

/**
 * 录制参数数据类
 */
data class RecordingParams(
    val resolution: Resolution,
    val videoBitrate: Long,
    val audioBitrate: Long,
    val fps: Int,
    val audioSampleRate: Int,
    val keyFrameInterval: Int,
    val encodingProfile: String,
    val bufferDepth: Int,
    val threadCount: Int
)

