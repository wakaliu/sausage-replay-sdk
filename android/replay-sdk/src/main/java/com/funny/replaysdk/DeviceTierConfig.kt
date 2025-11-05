package com.funny.replaysdk

import android.content.Context
import com.funny.replaysdk.Logger
import org.json.JSONObject
import java.io.IOException

/**
 * 视频清晰度档位配置管理类
 * 负责加载和管理不同视频清晰度档位的录制参数配置
 */
object DeviceTierConfig {
    
    private const val TAG = "DeviceTierConfig"
    private const val CONFIG_FILE = "device_tier_config.json"
    
    private var configData: JSONObject? = null
    private var isLoaded = false
    
    /**
     * 加载配置文件
     */
    fun loadConfig(context: Context): Boolean {
        return try {
            val inputStream = context.assets.open(CONFIG_FILE)
            val jsonString = inputStream.bufferedReader().use { it.readText() }
            configData = JSONObject(jsonString)
            isLoaded = true
            Logger.d(TAG, "Device tier config loaded successfully")
            true
        } catch (e: IOException) {
            Logger.e(TAG, "Failed to load device tier config: ${e.message}", e)
            false
        } catch (e: Exception) {
            Logger.e(TAG, "Error parsing device tier config: ${e.message}", e)
            false
        }
    }
    
    /**
     * 获取视频清晰度档位配置
     */
    fun getPresetConfig(preset: Int): TierConfig? {
        if (!isLoaded || configData == null) {
            Logger.w(TAG, "Config not loaded, using default values")
            return getDefaultPresetConfig(preset)
        }
        
        return try {
            val presetName = when (preset) {
                VideoQualityPreset.BASIC -> "BASIC"
                VideoQualityPreset.STANDARD -> "STANDARD"
                VideoQualityPreset.SMOOTH -> "SMOOTH"
                VideoQualityPreset.HIGH_FPS -> "HIGH_FPS"
                VideoQualityPreset.ULTRA -> "ULTRA"
                else -> "STANDARD"
            }
            val presetJson = configData!!.getJSONObject("videoQualityPresets").getJSONObject(presetName)
            parseTierConfig(presetJson)
        } catch (e: Exception) {
            Logger.e(TAG, "Failed to get preset config for $preset: ${e.message}", e)
            getDefaultPresetConfig(preset)
        }
    }
    
    /**
     * 获取自适应策略配置
     */
    fun getAdaptiveStrategies(): AdaptiveStrategies? {
        if (!isLoaded || configData == null) {
            return getDefaultAdaptiveStrategies()
        }
        
        return try {
            val strategiesJson = configData!!.getJSONObject("adaptiveStrategies")
            parseAdaptiveStrategies(strategiesJson)
        } catch (e: Exception) {
            Logger.e(TAG, "Failed to get adaptive strategies: ${e.message}", e)
            getDefaultAdaptiveStrategies()
        }
    }
    
    /**
     * 检查配置是否已加载
     */
    fun isConfigLoaded(): Boolean = isLoaded
    
    /**
     * 重新加载配置
     */
    fun reloadConfig(context: Context): Boolean {
        isLoaded = false
        configData = null
        return loadConfig(context)
    }
    
    private fun parseTierConfig(tierJson: JSONObject): TierConfig {
        val maxRes = tierJson.getJSONObject("maxResolution")
        val targetFps = tierJson.getJSONObject("targetFps")
        val videoBitrate = tierJson.getJSONObject("videoBitrate")
        val audioBitrate = tierJson.getJSONObject("audioBitrate")
        val gifStrategy = tierJson.getJSONObject("gifStrategy")
        val gifMaxRes = gifStrategy.getJSONObject("maxResolution")
        val adaptiveThresholds = tierJson.getJSONObject("adaptiveThresholds")
        
        return TierConfig(
            name = tierJson.getString("name"),
            maxResolution = Resolution(
                width = maxRes.getInt("width"),
                height = maxRes.getInt("height")
            ),
            targetFps = FpsRange(
                min = targetFps.getInt("min"),
                max = targetFps.getInt("max"),
                default = targetFps.getInt("default")
            ),
            videoBitrate = BitrateRange(
                min = videoBitrate.getLong("min"),
                max = videoBitrate.getLong("max"),
                default = videoBitrate.getLong("default")
            ),
            audioBitrate = BitrateRange(
                min = audioBitrate.getLong("min"),
                max = audioBitrate.getLong("max"),
                default = audioBitrate.getLong("default")
            ),
            audioSampleRate = tierJson.getInt("audioSampleRate"),
            keyFrameInterval = tierJson.getInt("keyFrameInterval"),
            encodingProfile = tierJson.getString("encodingProfile"),
            bufferDepth = tierJson.getInt("bufferDepth"),
            threadCount = tierJson.getInt("threadCount"),
            gifStrategy = GifStrategy(
                enabled = gifStrategy.getBoolean("enabled"),
                maxFps = gifStrategy.getInt("maxFps"),
                maxResolution = Resolution(
                    width = gifMaxRes.getInt("width"),
                    height = gifMaxRes.getInt("height")
                ),
                maxDurationSeconds = gifStrategy.getInt("maxDurationSeconds")
            ),
            ioStrategy = tierJson.getString("ioStrategy"),
            logLevel = tierJson.getString("logLevel"),
            adaptiveThresholds = AdaptiveThresholds(
                frameDropRate = adaptiveThresholds.getDouble("frameDropRate"),
                encodingBlockTime = adaptiveThresholds.getLong("encodingBlockTime"),
                queueCongestionTime = adaptiveThresholds.getLong("queueCongestionTime"),
                recoveryStableTime = adaptiveThresholds.getLong("recoveryStableTime")
            )
        )
    }
    
    private fun parseAdaptiveStrategies(strategiesJson: JSONObject): AdaptiveStrategies {
        val bitrateReduction = strategiesJson.getJSONObject("bitrateReduction")
        val resolutionDegradation = strategiesJson.getJSONObject("resolutionDegradation")
        val fpsDegradation = strategiesJson.getJSONObject("fpsDegradation")
        
        val resolutionSteps = mutableListOf<Resolution>()
        val resolutionArray = resolutionDegradation.getJSONArray("steps")
        for (i in 0 until resolutionArray.length()) {
            val step = resolutionArray.getJSONObject(i)
            resolutionSteps.add(Resolution(
                width = step.getInt("width"),
                height = step.getInt("height")
            ))
        }
        
        val fpsSteps = mutableListOf<Int>()
        val fpsArray = fpsDegradation.getJSONArray("steps")
        for (i in 0 until fpsArray.length()) {
            fpsSteps.add(fpsArray.getInt(i))
        }
        
        return AdaptiveStrategies(
            bitrateReduction = BitrateReductionStrategy(
                step = bitrateReduction.getDouble("step"),
                minReduction = bitrateReduction.getDouble("minReduction"),
                maxReduction = bitrateReduction.getDouble("maxReduction")
            ),
            resolutionDegradation = ResolutionDegradationStrategy(resolutionSteps),
            fpsDegradation = FpsDegradationStrategy(fpsSteps)
        )
    }
    
    private fun getDefaultPresetConfig(preset: Int): TierConfig {
        return when (preset) {
            VideoQualityPreset.BASIC -> TierConfig(
                name = "基础清晰度",
                maxResolution = Resolution(1280, 720),
                targetFps = FpsRange(30, 30, 30),
                videoBitrate = BitrateRange(4000000, 5000000, 4500000),
                audioBitrate = BitrateRange(128000, 192000, 128000),
                audioSampleRate = 48000,
                keyFrameInterval = 1,
                encodingProfile = "HIGH",
                bufferDepth = 6,
                threadCount = 3,
                gifStrategy = GifStrategy(true, 10, Resolution(1280, 720), 15),
                ioStrategy = "SERIAL_MEDIUM_BUFFER",
                logLevel = "INFO",
                adaptiveThresholds = AdaptiveThresholds(0.03, 200, 500, 10)
            )
            VideoQualityPreset.STANDARD -> TierConfig(
                name = "标准清晰度",
                maxResolution = Resolution(1920, 1080),
                targetFps = FpsRange(30, 30, 30),
                videoBitrate = BitrateRange(7000000, 9000000, 8000000),
                audioBitrate = BitrateRange(128000, 192000, 128000),
                audioSampleRate = 48000,
                keyFrameInterval = 1,
                encodingProfile = "HIGH",
                bufferDepth = 6,
                threadCount = 3,
                gifStrategy = GifStrategy(true, 10, Resolution(1280, 720), 15),
                ioStrategy = "SERIAL_MEDIUM_BUFFER",
                logLevel = "INFO",
                adaptiveThresholds = AdaptiveThresholds(0.03, 200, 500, 10)
            )
            VideoQualityPreset.SMOOTH -> TierConfig(
                name = "流畅清晰度",
                maxResolution = Resolution(1280, 720),
                targetFps = FpsRange(60, 60, 60),
                videoBitrate = BitrateRange(6000000, 8000000, 7000000),
                audioBitrate = BitrateRange(128000, 192000, 128000),
                audioSampleRate = 48000,
                keyFrameInterval = 1,
                encodingProfile = "HIGH",
                bufferDepth = 8,
                threadCount = 4,
                gifStrategy = GifStrategy(true, 12, Resolution(1280, 720), 20),
                ioStrategy = "ASYNC_DOUBLE_BUFFER",
                logLevel = "DEBUG",
                adaptiveThresholds = AdaptiveThresholds(0.03, 200, 500, 10)
            )
            VideoQualityPreset.HIGH_FPS -> TierConfig(
                name = "高帧率清晰度",
                maxResolution = Resolution(1920, 1080),
                targetFps = FpsRange(60, 60, 60),
                videoBitrate = BitrateRange(12000000, 16000000, 14000000),
                audioBitrate = BitrateRange(128000, 192000, 128000),
                audioSampleRate = 48000,
                keyFrameInterval = 1,
                encodingProfile = "HIGH",
                bufferDepth = 10,
                threadCount = 4,
                gifStrategy = GifStrategy(true, 12, Resolution(1920, 1080), 20),
                ioStrategy = "ASYNC_DOUBLE_BUFFER",
                logLevel = "DEBUG",
                adaptiveThresholds = AdaptiveThresholds(0.03, 200, 500, 10)
            )
            VideoQualityPreset.ULTRA -> TierConfig(
                name = "超高清清晰度",
                maxResolution = Resolution(2560, 1440),
                targetFps = FpsRange(30, 60, 30),
                videoBitrate = BitrateRange(18000000, 22000000, 20000000),
                audioBitrate = BitrateRange(128000, 192000, 128000),
                audioSampleRate = 48000,
                keyFrameInterval = 1,
                encodingProfile = "HIGH",
                bufferDepth = 12,
                threadCount = 6,
                gifStrategy = GifStrategy(true, 15, Resolution(1920, 1080), 30),
                ioStrategy = "ASYNC_DOUBLE_BUFFER",
                logLevel = "DEBUG",
                adaptiveThresholds = AdaptiveThresholds(0.03, 200, 500, 10)
            )
            else -> TierConfig(
                name = "标准清晰度",
                maxResolution = Resolution(1920, 1080),
                targetFps = FpsRange(30, 30, 30),
                videoBitrate = BitrateRange(7000000, 9000000, 8000000),
                audioBitrate = BitrateRange(128000, 192000, 128000),
                audioSampleRate = 48000,
                keyFrameInterval = 1,
                encodingProfile = "HIGH",
                bufferDepth = 6,
                threadCount = 3,
                gifStrategy = GifStrategy(true, 10, Resolution(1280, 720), 15),
                ioStrategy = "SERIAL_MEDIUM_BUFFER",
                logLevel = "INFO",
                adaptiveThresholds = AdaptiveThresholds(0.03, 200, 500, 10)
            )
        }
    }
    
    private fun getDefaultAdaptiveStrategies(): AdaptiveStrategies {
        return AdaptiveStrategies(
            bitrateReduction = BitrateReductionStrategy(0.15, 0.1, 0.3),
            resolutionDegradation = ResolutionDegradationStrategy(listOf(
                Resolution(1920, 1080),
                Resolution(1280, 720),
                Resolution(854, 480)
            )),
            fpsDegradation = FpsDegradationStrategy(listOf(60, 30, 25, 20))
        )
    }
}

/**
 * 视频清晰度档位配置数据类
 */
data class TierConfig(
    val name: String,
    val maxResolution: Resolution,
    val targetFps: FpsRange,
    val videoBitrate: BitrateRange,
    val audioBitrate: BitrateRange,
    val audioSampleRate: Int,
    val keyFrameInterval: Int,
    val encodingProfile: String,
    val bufferDepth: Int,
    val threadCount: Int,
    val gifStrategy: GifStrategy,
    val ioStrategy: String,
    val logLevel: String,
    val adaptiveThresholds: AdaptiveThresholds
)

/**
 * 分辨率数据类
 */
data class Resolution(
    val width: Int,
    val height: Int
)

/**
 * FPS范围数据类
 */
data class FpsRange(
    val min: Int,
    val max: Int,
    val default: Int
)

/**
 * 比特率范围数据类
 */
data class BitrateRange(
    val min: Long,
    val max: Long,
    val default: Long
)

/**
 * GIF策略数据类
 */
data class GifStrategy(
    val enabled: Boolean,
    val maxFps: Int,
    val maxResolution: Resolution,
    val maxDurationSeconds: Int
)

/**
 * 自适应阈值数据类
 */
data class AdaptiveThresholds(
    val frameDropRate: Double,
    val encodingBlockTime: Long,
    val queueCongestionTime: Long,
    val recoveryStableTime: Long
)

/**
 * 自适应策略数据类
 */
data class AdaptiveStrategies(
    val bitrateReduction: BitrateReductionStrategy,
    val resolutionDegradation: ResolutionDegradationStrategy,
    val fpsDegradation: FpsDegradationStrategy
)

/**
 * 比特率降低策略
 */
data class BitrateReductionStrategy(
    val step: Double,
    val minReduction: Double,
    val maxReduction: Double
)

/**
 * 分辨率降级策略
 */
data class ResolutionDegradationStrategy(
    val steps: List<Resolution>
)

/**
 * FPS降级策略
 */
data class FpsDegradationStrategy(
    val steps: List<Int>
)
