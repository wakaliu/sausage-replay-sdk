# Sausage Replay Android SDK API 文档

## 概述

Sausage Replay Android SDK 是一个用于Android平台的屏幕录制SDK，支持高质量视频录制、暂停/恢复、格式转换等功能。

## 快速开始

### 1. 初始化SDK

```kotlin
// 初始化SDK
val success = SausageReplayAndroidSDK.initialize(context, DevicePerformanceTier.MID_RANGE)
if (success) {
    // SDK初始化成功
}
```

### 2. 检查平台支持

```kotlin
val isSupported = SausageReplayAndroidSDK.isPlatformSupported()
```

### 3. 开始录制

```kotlin
val config = RecordingConfig(
    quality = VideoQuality.HIGH,
    maxDurationSeconds = 60,
    includeAudio = true
)

val success = RecordingManager.startRecording(activity, config) { result ->
    when (result) {
        is RecordingResult -> {
            if (result.isSuccess) {
                // 录制成功
                println("录制文件: ${result.filePath}")
            } else {
                // 录制失败
                println("录制失败: ${result.errorMessage}")
            }
        }
    }
}
```

## 核心API

### SausageReplayAndroidSDK

#### 初始化方法

```kotlin
fun initialize(context: Context, tier: DevicePerformanceTier = DevicePerformanceTier.MID_RANGE): Boolean
```
- **参数**：
  - `context`: Android应用上下文
  - `tier`: 设备性能等级（LOW_END, MID_RANGE, HIGH_END, FLAGSHIP）
- **返回**：初始化是否成功

#### 平台支持检查

```kotlin
fun isPlatformSupported(): Boolean
```
- **返回**：当前平台是否支持录制功能

#### 版本信息

```kotlin
fun getVersion(): String
```
- **返回**：SDK版本号

#### 内存监控

```kotlin
fun getMemoryUsage(): MemoryUsage
```
- **返回**：当前内存使用情况

#### 资源释放

```kotlin
fun release()
```
- **说明**：释放SDK占用的所有资源

### RecordingManager

#### 开始录制

```kotlin
fun startRecording(activity: Activity, config: RecordingConfig, callback: RecordingCallback? = null): Boolean
```
- **参数**：
  - `activity`: 当前Activity实例
  - `config`: 录制配置
  - `callback`: 录制回调（可选）
- **返回**：是否成功开始录制

#### 停止录制

```kotlin
fun stopRecording(callback: (RecordingResult) -> Unit)
```
- **参数**：
  - `callback`: 停止录制回调

#### 暂停录制

```kotlin
fun pauseRecording(): Boolean
```
- **返回**：是否成功暂停

#### 恢复录制

```kotlin
fun resumeRecording(): Boolean
```
- **返回**：是否成功恢复

#### 调整录制质量

```kotlin
fun adjustRecordingQuality(quality: VideoQuality): Boolean
```
- **参数**：
  - `quality`: 目标质量等级
- **返回**：是否成功调整

#### 格式转换

```kotlin
fun convertVideoFormat(inputPath: String, outputFormat: OutputFormat, callback: (Boolean, String?) -> Unit)
```
- **参数**：
  - `inputPath`: 输入文件路径
  - `outputFormat`: 目标格式
  - `callback`: 转换结果回调

#### 状态查询

```kotlin
fun getRecordingStatus(): RecordingStatus
fun getDetailedStatus(): DetailedStatus
```

#### 错误恢复

```kotlin
fun recoverFromError(): Boolean
```

#### 状态重置

```kotlin
fun resetStatus()
```

### PermissionManager

#### 检查麦克风权限

```kotlin
fun hasMicrophonePermission(context: Context): Boolean
```

#### 请求麦克风权限

```kotlin
fun requestMicrophonePermission(activity: Activity, callback: (granted: Boolean, errorCode: Int, message: String?) -> Unit)
```

#### 请求屏幕录制权限

```kotlin
fun requestScreenCapturePermission(activity: Activity, callback: (granted: Boolean, errorCode: Int, message: String?) -> Unit)
```

## 数据模型

### RecordingConfig

录制配置类：

```kotlin
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
```

### RecordingResult

录制结果类：

```kotlin
data class RecordingResult(
    val isSuccess: Boolean,
    val filePath: String? = null,
    val fileSize: Long = 0,
    val duration: Float = 0f,
    val errorCode: Int = 0,
    val errorMessage: String? = null
)
```

### MemoryUsage

内存使用情况：

```kotlin
data class MemoryUsage(
    val totalMemory: Long,
    val usedMemory: Long,
    val freeMemory: Long,
    val maxMemory: Long,
    val usagePercentage: Int
)
```

### DetailedStatus

详细状态信息：

```kotlin
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
```

## 枚举类型

### VideoQuality

视频质量等级：

```kotlin
enum class VideoQuality { 
    LOW,    // 低质量 (480p)
    MEDIUM, // 中等质量 (720p)
    HIGH    // 高质量 (1080p)
}
```

### OutputFormat

输出格式：

```kotlin
enum class OutputFormat { 
    MP4,   // MP4格式
    GIF,   // GIF格式
    WEBM,  // WebM格式
    AVI    // AVI格式
}
```

### RecordingStatus

录制状态：

```kotlin
enum class RecordingStatus { 
    IDLE,     // 空闲
    RECORDING, // 录制中
    PAUSED,   // 已暂停
    STOPPING  // 停止中
}
```

### DevicePerformanceTier

设备性能等级：

```kotlin
enum class DevicePerformanceTier { 
    LOW_END,   // 低端设备
    MID_RANGE, // 中端设备
    HIGH_END,  // 高端设备
    FLAGSHIP   // 旗舰设备
}
```

## 回调接口

### RecordingCallback

录制回调接口：

```kotlin
interface RecordingCallback {
    fun onRecordingStarted()
    fun onRecordingProgress(durationMs: Long, fileSizeBytes: Long)
    fun onRecordingPaused()
    fun onRecordingResumed()
    fun onRecordingStopped(result: RecordingResult)
    fun onRecordingError(errorCode: Int, errorMessage: String?)
    fun onRecordingQualityAdjusted(quality: VideoQuality) {}
}
```

## 错误码

### 权限相关 (1000-1999)
- `1001`: 麦克风权限被拒绝
- `1002`: 屏幕录制权限被拒绝

### 录制相关 (2000-2999)
- `2001`: 录制未开始
- `2002`: 录制已在进行中
- `2003`: 录制启动失败
- `2004`: 录制停止失败

### 暂停/恢复相关 (3000-3999)
- `3001`: 暂停录制失败
- `3002`: 恢复录制失败
- `3003`: 质量调整失败

### 错误恢复相关 (4000-4999)
- `4001`: 错误恢复成功

## 使用示例

### 完整录制流程

```kotlin
class MainActivity : AppCompatActivity() {
    
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        // 初始化SDK
        SausageReplayAndroidSDK.initialize(this)
        
        // 检查权限
        if (!PermissionManager.hasMicrophonePermission(this)) {
            PermissionManager.requestMicrophonePermission(this) { granted, errorCode, message ->
                if (granted) {
                    startRecording()
                }
            }
        } else {
            startRecording()
        }
    }
    
    private fun startRecording() {
        val config = RecordingConfig(
            quality = VideoQuality.HIGH,
            maxDurationSeconds = 120,
            includeAudio = true
        )
        
        RecordingManager.startRecording(this, config, object : RecordingCallback {
            override fun onRecordingStarted() {
                // 录制开始
            }
            
            override fun onRecordingProgress(durationMs: Long, fileSizeBytes: Long) {
                // 更新进度
            }
            
            override fun onRecordingStopped(result: RecordingResult) {
                if (result.isSuccess) {
                    // 录制成功
                    println("录制文件: ${result.filePath}")
                }
            }
            
            override fun onRecordingError(errorCode: Int, errorMessage: String?) {
                // 处理错误
            }
        })
    }
}
```

### 格式转换示例

```kotlin
// 转换MP4为GIF
RecordingManager.convertVideoFormat(
    inputPath = "/path/to/video.mp4",
    outputFormat = OutputFormat.GIF
) { success, outputPath ->
    if (success) {
        println("转换成功: $outputPath")
    } else {
        println("转换失败")
    }
}
```

## 注意事项

1. **权限要求**：需要麦克风和屏幕录制权限
2. **性能影响**：录制可能影响应用性能，建议在非关键场景使用
3. **存储空间**：确保有足够的存储空间用于录制文件
4. **线程安全**：所有API都是线程安全的，可以在任意线程调用
5. **资源管理**：使用完毕后调用`release()`释放资源

## 版本历史

- **v1.0.0**: 初始版本，支持基础录制功能
- 支持暂停/恢复、进度监控、质量调整
- 支持多格式输出和格式转换
- 完善的错误处理和状态管理
