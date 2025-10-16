package com.funny.replaysdk

import android.content.Context
import android.util.Log
import org.json.JSONObject
import java.io.IOException

/**
 * 设备档位配置管理类
 * 负责加载和管理不同设备档位的录制参数配置
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
            Log.d(TAG, "Device tier config loaded successfully")
            true
        } catch (e: IOException) {
            Log.e(TAG, "Failed to load device tier config", e)
            false
        } catch (e: Exception) {
            Log.e(TAG, "Error parsing device tier config", e)
            false
        }
    }
    
    /**
     * 获取设备档位配置
     */
    fun getTierConfig(tier: Int): TierConfig? {
        if (!isLoaded || configData == null) {
            Log.w(TAG, "Config not loaded, using default values")
            return getDefaultTierConfig(tier)
        }
        
        return try {
            val tierName = when (tier) {
                DevicePerformanceTier.LOW_END -> "LOW_END"
                DevicePerformanceTier.MID_RANGE -> "MID_RANGE"
                DevicePerformanceTier.HIGH_END -> "HIGH_END"
                DevicePerformanceTier.FLAGSHIP -> "FLAGSHIP"
                else -> "MID_RANGE"
            }
            val tierJson = configData!!.getJSONObject("deviceTiers").getJSONObject(tierName)
            parseTierConfig(tierJson)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to get tier config for $tier", e)
            getDefaultTierConfig(tier)
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
            Log.e(TAG, "Failed to get adaptive strategies", e)
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
    
    private fun getDefaultTierConfig(tier: Int): TierConfig {
        return when (tier) {
            DevicePerformanceTier.LOW_END -> TierConfig(
                name = "低端机",
                maxResolution = Resolution(1280, 720),
                targetFps = FpsRange(25, 30, 30),
                videoBitrate = BitrateRange(4000000, 6000000, 5000000),
                audioBitrate = BitrateRange(128000, 192000, 128000),
                audioSampleRate = 44100,
                keyFrameInterval = 2,
                encodingProfile = "MAIN",
                bufferDepth = 3,
                threadCount = 2,
                gifStrategy = GifStrategy(false, 8, Resolution(854, 480), 10),
                ioStrategy = "SERIAL_SMALL_BUFFER",
                logLevel = "WARN",
                adaptiveThresholds = AdaptiveThresholds(0.03, 200, 500, 10)
            )
            DevicePerformanceTier.MID_RANGE -> TierConfig(
                name = "中端机",
                maxResolution = Resolution(1920, 1080),
                targetFps = FpsRange(30, 30, 30),
                videoBitrate = BitrateRange(8000000, 12000000, 10000000),
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
            DevicePerformanceTier.HIGH_END -> TierConfig(
                name = "高端机",
                maxResolution = Resolution(1920, 1080),
                targetFps = FpsRange(30, 60, 30),
                videoBitrate = BitrateRange(12000000, 18000000, 15000000),
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
            DevicePerformanceTier.FLAGSHIP -> TierConfig(
                name = "旗舰机",
                maxResolution = Resolution(1920, 1080),
                targetFps = FpsRange(30, 60, 30),
                videoBitrate = BitrateRange(15000000, 25000000, 20000000),
                audioBitrate = BitrateRange(128000, 192000, 128000),
                audioSampleRate = 48000,
                keyFrameInterval = 1,
                encodingProfile = "HIGH",
                bufferDepth = 14,
                threadCount = 6,
                gifStrategy = GifStrategy(true, 15, Resolution(1920, 1080), 30),
                ioStrategy = "ASYNC_DOUBLE_BUFFER",
                logLevel = "DEBUG",
                adaptiveThresholds = AdaptiveThresholds(0.03, 200, 500, 10)
            )
            else -> TierConfig(
                name = "中端机",
                maxResolution = Resolution(1920, 1080),
                targetFps = FpsRange(30, 30, 30),
                videoBitrate = BitrateRange(8000000, 12000000, 10000000),
                audioBitrate = BitrateRange(128000, 192000, 128000),
                audioSampleRate = 44100,
                keyFrameInterval = 1,
                encodingProfile = "HIGH",
                bufferDepth = 8,
                threadCount = 4,
                gifStrategy = GifStrategy(true, 12, Resolution(1280, 720), 20),
                ioStrategy = "ASYNC_SINGLE_BUFFER",
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
 * 设备档位配置数据类
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
