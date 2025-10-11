# 设备档位自适应系统使用说明

## 系统概述

设备档位自适应系统是Sausage Replay SDK的核心功能之一，它能够根据设备性能自动调整录制参数，确保在不同档位的设备上都能获得最佳的录制体验。

## 核心组件

### 1. 配置文件系统 (`device_tier_config.json`)

配置文件位于 `android/replay-sdk/src/main/assets/device_tier_config.json`，包含：

- **设备档位配置**：LOW_END、MID_RANGE、HIGH_END、FLAGSHIP
- **自适应策略**：比特率调整、分辨率降级、FPS降级
- **性能阈值**：丢帧率、编码阻塞时间、队列拥塞时间等

### 2. 设备档位管理器 (`DeviceTierManager`)

负责：
- 设备档位检测和配置加载
- 录制参数计算
- 自适应调整应用
- GIF转换支持检查

### 3. 性能监控器 (`PerformanceMonitor`)

负责：
- 实时性能指标收集
- 自适应条件检查
- 降级和恢复策略执行

### 4. 配置管理 (`DeviceTierConfig`)

负责：
- 配置文件加载和解析
- 档位配置获取
- 默认配置提供

## 设备档位说明

### LOW_END (低端机)
- **分辨率上限**: 854x480
- **FPS**: 25-30
- **视频比特率**: 1.5-3 Mbps
- **音频比特率**: 96-128 kbps
- **GIF支持**: 默认禁用
- **线程数**: 2
- **缓冲深度**: 3

### MID_RANGE (中端机) - 默认
- **分辨率上限**: 1280x720
- **FPS**: 30
- **视频比特率**: 3-6 Mbps
- **音频比特率**: 96-128 kbps
- **GIF支持**: 启用，最大10fps
- **线程数**: 3
- **缓冲深度**: 6

### HIGH_END (高端机)
- **分辨率上限**: 1920x1080
- **FPS**: 30
- **视频比特率**: 6-10 Mbps
- **音频比特率**: 128 kbps
- **GIF支持**: 启用，最大12fps
- **线程数**: 4
- **缓冲深度**: 10

### FLAGSHIP (旗舰机)
- **分辨率上限**: 1920x1080
- **FPS**: 30-60
- **视频比特率**: 8-12 Mbps
- **音频比特率**: 128 kbps
- **GIF支持**: 启用，最大15fps
- **线程数**: 6
- **缓冲深度**: 14

## 自适应策略

### 1. 比特率调整
- **触发条件**: 丢帧率 > 3% 或编码阻塞 > 200ms
- **调整幅度**: 每次降低10-20%
- **最大降低**: 30%

### 2. 分辨率降级
- **触发条件**: 比特率调整无效时
- **降级步骤**: 1080p → 720p → 480p
- **恢复条件**: 性能稳定10秒后

### 3. FPS降级
- **触发条件**: 分辨率降级无效时
- **降级步骤**: 60fps → 30fps → 25fps → 20fps
- **恢复条件**: 性能稳定10秒后

## 使用方法

### 1. 基础使用（自动档位检测）
```kotlin
// 初始化SDK，自动检测设备档位
SausageReplayAndroidSDK.initialize(context)

// 手动指定设备档位
SausageReplayAndroidSDK.initialize(context, DevicePerformanceTier.HIGH_END)
```

### 2. 获取档位信息（高级API）
```kotlin
// 获取设备档位信息
val tierInfo = SausageReplayAndroidSDK.getDeviceTierInfo()
tierInfo?.let {
    Log.d("Device", "Current tier: ${it.tier}")
    Log.d("Device", "Tier name: ${it.config.name}")
    Log.d("Device", "Max resolution: ${it.config.maxResolution.width}x${it.config.maxResolution.height}")
}

// 检查GIF转换支持
val isGifSupported = SausageReplayAndroidSDK.isGifConversionSupported()
if (isGifSupported) {
    val gifParams = SausageReplayAndroidSDK.getGifConversionParams()
    // 使用GIF转换参数
}
```

### 3. 性能监控（高级API，按需使用）
```kotlin
// 创建性能监控器（不会自动启动）
val monitor = SausageReplayAndroidSDK.createPerformanceMonitor(object : PerformanceCallback {
    override fun onPerformanceMetrics(metrics: PerformanceMetrics) {
        // 处理性能指标
        Log.d("Performance", "Frame drop rate: ${metrics.frameDropRate}")
    }
    
    override fun onBitrateReduction(reduction: Double) {
        // 处理比特率降低
        Log.i("Performance", "Bitrate reduced by ${(reduction * 100).toInt()}%")
    }
    
    override fun onResolutionDegradation(resolution: Resolution) {
        // 处理分辨率降级
        Log.i("Performance", "Resolution degraded to ${resolution.width}x${resolution.height}")
    }
    
    override fun onFpsDegradation(fps: Int) {
        // 处理FPS降级
        Log.i("Performance", "FPS degraded to $fps")
    }
    
    // 其他回调方法...
})

// 手动启动性能监控
monitor?.startMonitoring()

// 手动停止性能监控
monitor?.stopMonitoring()
```

### 4. 配置管理（高级API）
```kotlin
// 重新加载设备档位配置
val success = SausageReplayAndroidSDK.reloadDeviceTierConfig()
if (success) {
    Log.d("Config", "Configuration reloaded successfully")
}
```

## 配置修改

### 修改设备档位参数
编辑 `device_tier_config.json` 文件中的相应档位配置：

```json
{
  "deviceTiers": {
    "MID_RANGE": {
      "maxResolution": {
        "width": 1280,
        "height": 720
      },
      "targetFps": {
        "min": 30,
        "max": 30,
        "default": 30
      },
      "videoBitrate": {
        "min": 3000000,
        "max": 6000000,
        "default": 4000000
      }
    }
  }
}
```

### 修改自适应策略
```json
{
  "adaptiveStrategies": {
    "bitrateReduction": {
      "step": 0.15,
      "minReduction": 0.1,
      "maxReduction": 0.3
    },
    "resolutionDegradation": {
      "steps": [
        {"width": 1920, "height": 1080},
        {"width": 1280, "height": 720},
        {"width": 854, "height": 480}
      ]
    }
  }
}
```

## 性能指标

### 监控指标
- **丢帧率**: 录制过程中的丢帧比例
- **当前FPS**: 实际录制帧率
- **编码阻塞时间**: 编码器阻塞时间
- **队列深度**: 编码队列长度
- **总帧数**: 已处理的总帧数
- **丢帧数**: 已丢失的帧数

### 阈值设置
- **丢帧率阈值**: 3%
- **编码阻塞时间**: 200ms
- **队列拥塞时间**: 500ms
- **恢复稳定时间**: 10秒

## 日志输出

系统会输出详细的日志信息：

```
D/DeviceTierManager: Device tier manager initialized: 中端机 (MID_RANGE)
D/RecordingManager: Recording params: RecordingParams(resolution=Resolution(width=1280, height=720), videoBitrate=4000000, ...)
I/PerformanceMonitor: Performance metrics: PerformanceMetrics(frameDropRate=0.02, currentFps=30, ...)
I/SausageReplayAndroidSDK: Bitrate reduced by 15%
```

## 注意事项

1. **配置文件位置**: 确保配置文件位于正确的assets目录
2. **设备检测**: 系统会自动检测设备性能，但可以手动指定档位
3. **性能监控**: 性能监控不会自动启动，需要用户手动创建和启动
4. **资源管理**: 性能监控器需要用户手动管理生命周期
5. **按需使用**: 高级API按需使用，不会影响基础录制功能
6. **线程安全**: 所有API都是线程安全的，可以在任何线程调用

## 故障排除

### 配置文件加载失败
- 检查文件路径是否正确
- 检查JSON格式是否正确
- 查看日志中的错误信息

### 性能监控不工作
- 确认SDK已正确初始化
- 检查设备档位是否正确设置
- 查看性能监控器是否已启动

### 自适应策略不生效
- 检查性能阈值设置是否合理
- 确认监控指标是否正常收集
- 查看日志中的自适应触发信息
