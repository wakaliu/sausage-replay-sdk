package com.funny.replaysdk

import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.util.Log
import java.util.concurrent.atomic.AtomicLong
import java.util.concurrent.atomic.AtomicInteger
import java.util.concurrent.atomic.AtomicBoolean

/**
 * 性能监控类
 * 负责监控录制过程中的各种性能指标
 */
class PerformanceMonitor(
    private val tierConfig: TierConfig,
    private val adaptiveStrategies: AdaptiveStrategies,
    private val callback: PerformanceCallback? = null
) {
    
    companion object {
        private const val TAG = "PerformanceMonitor"
        private const val MONITOR_INTERVAL_MS = 1000L // 1秒监控一次
        private const val ADAPTIVE_CHECK_INTERVAL_MS = 5000L // 5秒检查一次自适应
    }
    
    private val handler = Handler(Looper.getMainLooper())
    private val isMonitoring = AtomicBoolean(false)
    
    // 性能指标
    private val totalFrames = AtomicLong(0)
    private val droppedFrames = AtomicLong(0)
    private val encodingBlockTime = AtomicLong(0)
    private val queueDepth = AtomicInteger(0)
    private val lastFrameTime = AtomicLong(0)
    private val startTime = AtomicLong(0)
    
    // 自适应状态
    private var currentBitrateReduction = 0.0
    private var currentResolutionIndex = 0
    private var currentFpsIndex = 0
    private var lastAdaptiveTime = 0L
    private var stablePerformanceTime = 0L
    
    // 监控任务
    private val monitorRunnable = object : Runnable {
        override fun run() {
            if (isMonitoring.get()) {
                collectMetrics()
                checkAdaptiveConditions()
                handler.postDelayed(this, MONITOR_INTERVAL_MS)
            }
        }
    }
    
    /**
     * 开始监控
     */
    fun startMonitoring() {
        if (isMonitoring.compareAndSet(false, true)) {
            startTime.set(SystemClock.elapsedRealtime())
            lastFrameTime.set(startTime.get())
            lastAdaptiveTime = startTime.get()
            stablePerformanceTime = startTime.get()
            
            Log.d(TAG, "Performance monitoring started for tier: ${tierConfig.name}")
            handler.post(monitorRunnable)
        }
    }
    
    /**
     * 停止监控
     */
    fun stopMonitoring() {
        if (isMonitoring.compareAndSet(true, false)) {
            handler.removeCallbacks(monitorRunnable)
            Log.d(TAG, "Performance monitoring stopped")
        }
    }
    
    /**
     * 记录帧信息
     */
    fun recordFrame(dropped: Boolean = false) {
        totalFrames.incrementAndGet()
        if (dropped) {
            droppedFrames.incrementAndGet()
        }
        lastFrameTime.set(SystemClock.elapsedRealtime())
    }
    
    /**
     * 记录编码阻塞时间
     */
    fun recordEncodingBlockTime(blockTimeMs: Long) {
        encodingBlockTime.set(blockTimeMs)
    }
    
    /**
     * 更新队列深度
     */
    fun updateQueueDepth(depth: Int) {
        queueDepth.set(depth)
    }
    
    /**
     * 获取当前性能指标
     */
    fun getCurrentMetrics(): PerformanceMetrics {
        val currentTime = SystemClock.elapsedRealtime()
        val elapsedTime = currentTime - startTime.get()
        val totalFramesCount = totalFrames.get()
        val droppedFramesCount = droppedFrames.get()
        
        val frameDropRate = if (totalFramesCount > 0) {
            droppedFramesCount.toDouble() / totalFramesCount.toDouble()
        } else 0.0
        
        val currentFps = if (elapsedTime > 0) {
            (totalFramesCount * 1000.0 / elapsedTime).toInt()
        } else 0
        
        return PerformanceMetrics(
            frameDropRate = frameDropRate,
            currentFps = currentFps,
            encodingBlockTime = encodingBlockTime.get(),
            queueDepth = queueDepth.get(),
            totalFrames = totalFramesCount,
            droppedFrames = droppedFramesCount,
            elapsedTime = elapsedTime,
            currentBitrateReduction = currentBitrateReduction,
            currentResolutionIndex = currentResolutionIndex,
            currentFpsIndex = currentFpsIndex
        )
    }
    
    /**
     * 收集性能指标
     */
    private fun collectMetrics() {
        val metrics = getCurrentMetrics()
        Log.d(TAG, "Performance metrics: frameDropRate=${metrics.frameDropRate}, " +
                "fps=${metrics.currentFps}, blockTime=${metrics.encodingBlockTime}, " +
                "queueDepth=${metrics.queueDepth}")
        
        callback?.onPerformanceMetrics(metrics)
    }
    
    /**
     * 检查自适应条件
     */
    private fun checkAdaptiveConditions() {
        val currentTime = SystemClock.elapsedRealtime()
        val metrics = getCurrentMetrics()
        
        // 检查是否需要降级
        val needsDegradation = checkDegradationConditions(metrics)
        
        if (needsDegradation) {
            performDegradation(metrics)
            lastAdaptiveTime = currentTime
            stablePerformanceTime = currentTime
        } else {
            // 检查是否可以恢复
            if (currentTime - stablePerformanceTime > tierConfig.adaptiveThresholds.recoveryStableTime * 1000) {
                performRecovery(metrics)
                stablePerformanceTime = currentTime
            }
        }
    }
    
    /**
     * 检查降级条件
     */
    private fun checkDegradationConditions(metrics: PerformanceMetrics): Boolean {
        val thresholds = tierConfig.adaptiveThresholds
        
        return metrics.frameDropRate > thresholds.frameDropRate ||
                metrics.encodingBlockTime > thresholds.encodingBlockTime ||
                (metrics.queueDepth > tierConfig.bufferDepth * 2 && 
                 SystemClock.elapsedRealtime() - lastAdaptiveTime > thresholds.queueCongestionTime)
    }
    
    /**
     * 执行降级策略
     */
    private fun performDegradation(metrics: PerformanceMetrics) {
        Log.w(TAG, "Performing performance degradation due to poor metrics: $metrics")
        
        // 优先级1: 降低比特率
        if (currentBitrateReduction < adaptiveStrategies.bitrateReduction.maxReduction) {
            val newReduction = (currentBitrateReduction + adaptiveStrategies.bitrateReduction.step)
                .coerceAtMost(adaptiveStrategies.bitrateReduction.maxReduction)
            currentBitrateReduction = newReduction
            callback?.onBitrateReduction(newReduction)
            Log.i(TAG, "Reduced bitrate by ${(newReduction * 100).toInt()}%")
            return
        }
        
        // 优先级2: 降低分辨率
        if (currentResolutionIndex < adaptiveStrategies.resolutionDegradation.steps.size - 1) {
            currentResolutionIndex++
            val newResolution = adaptiveStrategies.resolutionDegradation.steps[currentResolutionIndex]
            callback?.onResolutionDegradation(newResolution)
            Log.i(TAG, "Degraded resolution to ${newResolution.width}x${newResolution.height}")
            return
        }
        
        // 优先级3: 降低FPS
        if (currentFpsIndex < adaptiveStrategies.fpsDegradation.steps.size - 1) {
            currentFpsIndex++
            val newFps = adaptiveStrategies.fpsDegradation.steps[currentFpsIndex]
            callback?.onFpsDegradation(newFps)
            Log.i(TAG, "Degraded FPS to $newFps")
            return
        }
        
        Log.w(TAG, "All degradation strategies exhausted, performance may be poor")
    }
    
    /**
     * 执行恢复策略
     */
    private fun performRecovery(metrics: PerformanceMetrics) {
        Log.i(TAG, "Performing performance recovery due to stable metrics: $metrics")
        
        // 恢复FPS
        if (currentFpsIndex > 0) {
            currentFpsIndex--
            val newFps = adaptiveStrategies.fpsDegradation.steps[currentFpsIndex]
            callback?.onFpsRecovery(newFps)
            Log.i(TAG, "Recovered FPS to $newFps")
            return
        }
        
        // 恢复分辨率
        if (currentResolutionIndex > 0) {
            currentResolutionIndex--
            val newResolution = adaptiveStrategies.resolutionDegradation.steps[currentResolutionIndex]
            callback?.onResolutionRecovery(newResolution)
            Log.i(TAG, "Recovered resolution to ${newResolution.width}x${newResolution.height}")
            return
        }
        
        // 恢复比特率
        if (currentBitrateReduction > 0) {
            val newReduction = (currentBitrateReduction - adaptiveStrategies.bitrateReduction.step)
                .coerceAtLeast(0.0)
            currentBitrateReduction = newReduction
            callback?.onBitrateRecovery(newReduction)
            Log.i(TAG, "Recovered bitrate reduction to ${(newReduction * 100).toInt()}%")
        }
    }
    
    /**
     * 重置自适应状态
     */
    fun resetAdaptiveState() {
        currentBitrateReduction = 0.0
        currentResolutionIndex = 0
        currentFpsIndex = 0
        stablePerformanceTime = SystemClock.elapsedRealtime()
        Log.d(TAG, "Adaptive state reset")
    }
}

/**
 * 性能指标数据类
 */
data class PerformanceMetrics(
    val frameDropRate: Double,
    val currentFps: Int,
    val encodingBlockTime: Long,
    val queueDepth: Int,
    val totalFrames: Long,
    val droppedFrames: Long,
    val elapsedTime: Long,
    val currentBitrateReduction: Double,
    val currentResolutionIndex: Int,
    val currentFpsIndex: Int
)

/**
 * 性能回调接口
 */
interface PerformanceCallback {
    fun onPerformanceMetrics(metrics: PerformanceMetrics)
    fun onBitrateReduction(reduction: Double)
    fun onBitrateRecovery(reduction: Double)
    fun onResolutionDegradation(resolution: Resolution)
    fun onResolutionRecovery(resolution: Resolution)
    fun onFpsDegradation(fps: Int)
    fun onFpsRecovery(fps: Int)
}
