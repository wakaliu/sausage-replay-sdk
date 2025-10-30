# Sausage Replay SDK - 高级API使用指南

## 概述

Sausage Replay SDK 提供了丰富的高级API，用于性能监控、设备档位管理、自适应控制等功能。这些API不会自动启动，需要用户按需调用。

## 高级API列表

### 1. 性能监控API

#### 创建性能监控器
```kotlin
// 创建性能监控器
val monitor = SausageReplayAndroidSDK.createPerformanceMonitor(object : PerformanceCallback {
    override fun onPerformanceMetrics(metrics: PerformanceMetrics) {
        Log.d("Performance", "Frame drop rate: ${metrics.frameDropRate}")
        Log.d("Performance", "Current FPS: ${metrics.currentFps}")
        Log.d("Performance", "Queue depth: ${metrics.queueDepth}")
    }
    
    override fun onBitrateReduction(reduction: Double) {
        Log.i("Performance", "Bitrate reduced by ${(reduction * 100).toInt()}%")
        // 处理比特率降低事件
    }
    
    override fun onBitrateRecovery(reduction: Double) {
        Log.i("Performance", "Bitrate recovered to ${(reduction * 100).toInt()}%")
    }
    
    override fun onResolutionDegradation(resolution: Resolution) {
        Log.i("Performance", "Resolution degraded to ${resolution.width}x${resolution.height}")
        // 处理分辨率降级事件
    }
    
    override fun onResolutionRecovery(resolution: Resolution) {
        Log.i("Performance", "Resolution recovered to ${resolution.width}x${resolution.height}")
    }
    
    override fun onFpsDegradation(fps: Int) {
        Log.i("Performance", "FPS degraded to $fps")
        // 处理FPS降级事件
    }
    
    override fun onFpsRecovery(fps: Int) {
        Log.i("Performance", "FPS recovered to $fps")
    }
})

// 启动性能监控
monitor?.startMonitoring()

// 停止性能监控
monitor?.stopMonitoring()
```

#### 手动记录性能指标
```kotlin
// 记录帧信息
monitor?.recordFrame(dropped = false)  // 正常帧
monitor?.recordFrame(dropped = true)   // 丢帧

// 记录编码阻塞时间
monitor?.recordEncodingBlockTime(blockTimeMs = 150)

// 更新队列深度
monitor?.updateQueueDepth(depth = 5)

// 获取当前性能指标
val metrics = monitor?.getCurrentMetrics()
metrics?.let {
    Log.d("Performance", "Current metrics: $it")
}
```

### 2. 设备档位管理API

#### 获取设备档位信息
```kotlin
// 获取当前设备档位信息
val tierInfo = SausageReplayAndroidSDK.getDeviceTierInfo()
tierInfo?.let {
    Log.d("DeviceTier", "Current tier: ${it.tier}")
    Log.d("DeviceTier", "Tier name: ${it.config.name}")
    Log.d("DeviceTier", "Max resolution: ${it.config.maxResolution.width}x${it.config.maxResolution.height}")
    Log.d("DeviceTier", "Target FPS: ${it.config.targetFps.default}")
    Log.d("DeviceTier", "Video bitrate: ${it.config.videoBitrate.default}")
    Log.d("DeviceTier", "GIF supported: ${it.config.gifStrategy.enabled}")
}
```

#### 检查GIF转换支持
```kotlin
// 检查当前设备是否支持GIF转换
val isGifSupported = SausageReplayAndroidSDK.isGifConversionSupported()
if (isGifSupported) {
    Log.d("GIF", "GIF conversion is supported on this device")
    
    // 获取GIF转换参数
    val gifParams = SausageReplayAndroidSDK.getGifConversionParams()
    gifParams?.let {
        Log.d("GIF", "Max FPS: ${it.maxFps}")
        Log.d("GIF", "Max resolution: ${it.maxResolution.width}x${it.maxResolution.height}")
        Log.d("GIF", "Max duration: ${it.maxDurationSeconds}s")
    }
} else {
    Log.d("GIF", "GIF conversion is not supported on this device")
}
```

#### 重新加载配置
```kotlin
// 重新加载设备档位配置（用于运行时更新配置）
val success = SausageReplayAndroidSDK.reloadDeviceTierConfig()
if (success) {
    Log.d("Config", "Device tier config reloaded successfully")
} else {
    Log.e("Config", "Failed to reload device tier config")
}
```

### 3. 内存使用监控API

#### 获取内存使用情况
```kotlin
// 获取当前内存使用情况
val memoryUsage = SausageReplayAndroidSDK.getMemoryUsage()
Log.d("Memory", "Total memory: ${memoryUsage.totalMemory / (1024 * 1024)}MB")
Log.d("Memory", "Used memory: ${memoryUsage.usedMemory / (1024 * 1024)}MB")
Log.d("Memory", "Free memory: ${memoryUsage.freeMemory / (1024 * 1024)}MB")
Log.d("Memory", "Max memory: ${memoryUsage.maxMemory / (1024 * 1024)}MB")
Log.d("Memory", "Usage percentage: ${memoryUsage.usagePercentage}%")
```

## 使用场景示例

### 场景1：性能分析和优化
```kotlin
class PerformanceAnalyzer {
    private var monitor: PerformanceMonitor? = null
    
    fun startAnalysis() {
        // 创建性能监控器
        monitor = SausageReplayAndroidSDK.createPerformanceMonitor(object : PerformanceCallback {
            override fun onPerformanceMetrics(metrics: PerformanceMetrics) {
                // 分析性能指标
                analyzePerformance(metrics)
            }
            
            override fun onBitrateReduction(reduction: Double) {
                // 记录性能降级事件
                recordPerformanceDegradation("bitrate", reduction.toString())
            }
            
            override fun onResolutionDegradation(resolution: Resolution) {
                // 记录分辨率降级事件
                recordPerformanceDegradation("resolution", "${resolution.width}x${resolution.height}")
            }
            
            override fun onFpsDegradation(fps: Int) {
                // 记录FPS降级事件
                recordPerformanceDegradation("fps", fps.toString())
            }
            
            // 其他回调方法...
        })
        
        // 启动监控
        monitor?.startMonitoring()
    }
    
    fun stopAnalysis() {
        monitor?.stopMonitoring()
        monitor = null
    }
    
    private fun analyzePerformance(metrics: PerformanceMetrics) {
        // 分析性能指标
        if (metrics.frameDropRate > 0.05) {
            Log.w("Performance", "High frame drop rate detected: ${metrics.frameDropRate}")
        }
        
        if (metrics.encodingBlockTime > 300) {
            Log.w("Performance", "High encoding block time: ${metrics.encodingBlockTime}ms")
        }
    }
    
    private fun recordPerformanceDegradation(type: String, value: String) {
        Log.i("Performance", "Performance degraded: $type = $value")
        // 可以发送到分析服务或保存到本地
    }
}
```

### 场景2：设备能力检测
```kotlin
class DeviceCapabilityChecker {
    fun checkDeviceCapabilities() {
        // 获取设备档位信息
        val tierInfo = SausageReplayAndroidSDK.getDeviceTierInfo()
        tierInfo?.let {
            Log.d("Device", "Device tier: ${it.tier}")
            Log.d("Device", "Tier name: ${it.config.name}")
            
            // 检查录制能力
            val maxResolution = it.config.maxResolution
            val maxFps = it.config.targetFps.max
            val maxBitrate = it.config.videoBitrate.max
            
            Log.d("Device", "Max recording resolution: ${maxResolution.width}x${maxResolution.height}")
            Log.d("Device", "Max recording FPS: $maxFps")
            Log.d("Device", "Max recording bitrate: ${maxBitrate / 1000000}Mbps")
            
            // 检查GIF转换能力
            if (it.config.gifStrategy.enabled) {
                Log.d("Device", "GIF conversion supported")
                Log.d("Device", "Max GIF FPS: ${it.config.gifStrategy.maxFps}")
                Log.d("Device", "Max GIF resolution: ${it.config.gifStrategy.maxResolution.width}x${it.config.gifStrategy.maxResolution.height}")
            } else {
                Log.d("Device", "GIF conversion not supported")
            }
        }
    }
}
```

### 场景3：录制质量监控
```kotlin
class RecordingQualityMonitor {
    private var monitor: PerformanceMonitor? = null
    private var qualityMetrics = mutableListOf<PerformanceMetrics>()
    
    fun startQualityMonitoring() {
        monitor = SausageReplayAndroidSDK.createPerformanceMonitor(object : PerformanceCallback {
            override fun onPerformanceMetrics(metrics: PerformanceMetrics) {
                // 收集质量指标
                qualityMetrics.add(metrics)
                
                // 实时质量评估
                evaluateQuality(metrics)
            }
            
            // 其他回调方法...
        })
        
        monitor?.startMonitoring()
    }
    
    fun stopQualityMonitoring(): QualityReport {
        monitor?.stopMonitoring()
        
        // 生成质量报告
        return generateQualityReport()
    }
    
    private fun evaluateQuality(metrics: PerformanceMetrics) {
        val quality = when {
            metrics.frameDropRate < 0.01 && metrics.currentFps >= 28 -> "Excellent"
            metrics.frameDropRate < 0.03 && metrics.currentFps >= 25 -> "Good"
            metrics.frameDropRate < 0.05 && metrics.currentFps >= 20 -> "Fair"
            else -> "Poor"
        }
        
        Log.d("Quality", "Recording quality: $quality")
    }
    
    private fun generateQualityReport(): QualityReport {
        // 分析收集的指标，生成质量报告
        // ...
        return QualityReport(/* 报告数据 */)
    }
}

data class QualityReport(
    val averageFrameDropRate: Double,
    val averageFps: Double,
    val qualityLevel: String,
    val recommendations: List<String>
)
```

## 注意事项

### 1. 性能影响
- 性能监控会消耗一定的CPU和内存资源
- 建议只在需要时启用，不需要时及时停止
- 监控频率可以根据需要调整

### 2. 生命周期管理
- 性能监控器需要手动管理生命周期
- 在Activity/Fragment销毁时记得停止监控
- 避免内存泄漏

### 3. 线程安全
- 所有API都是线程安全的
- 回调会在主线程执行
- 可以在任何线程调用API

### 4. 错误处理
- API可能返回null，需要检查
- 配置加载可能失败，需要处理异常
- 监控器创建可能失败，需要检查返回值

## 最佳实践

1. **按需启用**：只在需要性能分析时启用监控
2. **及时清理**：使用完毕后及时停止监控和清理资源
3. **错误处理**：始终检查API返回值，处理可能的异常
4. **日志记录**：合理使用日志，避免过度输出影响性能
5. **配置管理**：根据实际需求调整配置文件中的参数
