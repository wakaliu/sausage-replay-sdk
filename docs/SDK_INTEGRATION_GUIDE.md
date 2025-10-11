# Sausage Replay SDK 接入指南

## 📋 目录

- [概述](#概述)
- [系统要求](#系统要求)
- [快速开始](#快速开始)
- [Unity集成](#unity集成)
- [Android原生集成](#android原生集成)
- [API参考](#api参考)
- [权限管理](#权限管理)
- [设备性能档位](#设备性能档位)
- [高级功能](#高级功能)
- [故障排除](#故障排除)
- [更新日志](#更新日志)

## 概述

Sausage Replay SDK 是一个专为移动设备设计的屏幕录制SDK，支持Android平台。提供高质量的屏幕录制、音频录制、实时质量调整等功能。

### 主要特性

- 🎥 **高质量屏幕录制**：支持1080p、720p、480p录制
- 🎵 **音频录制**：支持系统音频和麦克风音频录制
- ⏸️ **暂停/恢复**：录制过程中可暂停和恢复
- 🔄 **实时质量调整**：根据设备性能动态调整录制参数
- 📱 **设备档位适配**：自动适配不同性能档位的设备
- 🎬 **多格式支持**：支持MP4、GIF、WEBM、AVI格式输出
- 🛡️ **错误恢复**：内置错误检测和恢复机制

## 系统要求

### Android平台
- **最低版本**：Android 5.1 (API Level 22)
- **目标版本**：Android 13 (API Level 33)
- **编译版本**：Android 14 (API Level 36)
- **架构支持**：arm64-v8a, armeabi-v7a, x86, x86_64

### Unity版本
- **推荐版本**：Unity 2022.3 LTS 或更高版本
- **最低版本**：Unity 2020.3 LTS

## 快速开始

### 1. 获取SDK

从项目仓库获取最新版本的SDK文件：

```
unity/
├── Plugins/
│   └── Android/
│       ├── SausageReplaySDK.aar          # Android SDK
│       ├── AndroidManifest.xml           # Android配置
│       └── res/
│           └── xml/
│               └── file_paths.xml        # 文件路径配置
└── Scripts/
    ├── SausageReplaySDK.cs               # 主SDK接口
    ├── UnityMainThreadDispatcher.cs      # 主线程调度器
    ├── SausageReplayPermissionManager.cs # 权限管理器
    └── Examples/
        └── SausageReplayExample.cs       # 使用示例
```

### 2. 导入到Unity项目

1. 将`unity`文件夹下的所有文件复制到您的Unity项目中
2. 确保文件结构正确：
   ```
   Assets/
   ├── Plugins/
   │   └── Android/
   │       ├── SausageReplaySDK.aar
   │       ├── AndroidManifest.xml
   │       └── res/xml/file_paths.xml
   └── Scripts/
       ├── SausageReplaySDK.cs
       ├── UnityMainThreadDispatcher.cs
       ├── SausageReplayPermissionManager.cs
       └── Examples/
           └── SausageReplayExample.cs
   ```

### 3. 基本使用

```csharp
using SausageReplay;

public class RecordingController : MonoBehaviour, IRecordingCallback
{
    private void Start()
    {
        // 1. 请求权限
        SausageReplayPermissionManager.RequestAllRequiredPermissions((granted, errorCode, errorMessage) =>
        {
            if (granted)
            {
                // 2. 初始化SDK
                bool success = SausageReplaySDK.Initialize(DevicePerformanceTier.MID_RANGE);
                if (success)
                {
                    Debug.Log("SDK初始化成功");
                }
            }
        });
    }

    public void StartRecording()
    {
        // 3. 配置录制参数
        var config = new RecordingConfig
        {
            quality = VideoQuality.MEDIUM,
            maxDurationSeconds = 60,
            includeAudio = true,
            outputFormat = OutputFormat.MP4
        };

        // 4. 开始录制
        SausageReplaySDK.StartRecording(config, this);
    }

    public void StopRecording()
    {
        // 5. 停止录制
        SausageReplaySDK.StopRecording();
    }

    // 实现录制回调
    public void OnRecordingStarted()
    {
        Debug.Log("录制开始");
    }

    public void OnRecordingStopped(RecordingResult result)
    {
        if (result.isSuccess)
        {
            Debug.Log($"录制完成: {result.filePath}");
        }
    }

    // 其他回调方法...
    public void OnRecordingProgress(long durationMs, long fileSizeBytes) { }
    public void OnRecordingPaused() { }
    public void OnRecordingResumed() { }
    public void OnRecordingError(int errorCode, string errorMessage) { }
    public void OnRecordingQualityAdjusted(VideoQuality quality) { }
}
```

## Unity集成

### 项目设置

1. **Player Settings**
   - 设置最低API Level为22
   - 启用Internet Access权限
   - 配置Package Name

2. **Android Manifest**
   - SDK会自动添加必要的权限
   - 确保FileProvider配置正确

### 权限处理

```csharp
// 检查权限状态
bool hasPermissions = SausageReplayPermissionManager.HasAllRequiredPermissions();

// 请求权限
SausageReplayPermissionManager.RequestAllRequiredPermissions((granted, errorCode, errorMessage) =>
{
    if (granted)
    {
        // 权限获取成功，可以开始使用SDK
    }
    else
    {
        // 权限被拒绝，引导用户到设置页面
        SausageReplayPermissionManager.OpenAppSettings();
    }
});
```

### 主线程调度器

SDK使用`UnityMainThreadDispatcher`确保所有回调在主线程执行：

```csharp
// 自动创建，无需手动处理
// 确保场景中有GameObject挂载了UnityMainThreadDispatcher组件
```

## Android原生集成

### 1. 添加依赖

在您的Android项目的`build.gradle`中添加：

```gradle
dependencies {
    implementation files('libs/SausageReplaySDK.aar')
    implementation 'androidx.core:core-ktx:1.17.0'
}
```

### 2. 权限配置

在`AndroidManifest.xml`中添加必要权限：

```xml
<uses-permission android:name="android.permission.RECORD_AUDIO" />
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" />
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_MEDIA_PROJECTION" />
<uses-permission android:name="android.permission.SYSTEM_ALERT_WINDOW" />
```

### 3. 基本使用

```kotlin
import com.funny.replaysdk.SausageReplayAndroidSDK
import com.funny.replaysdk.RecordingCallback
import com.funny.replaysdk.RecordingConfig
import com.funny.replaysdk.VideoQuality
import com.funny.replaysdk.OutputFormat

class MainActivity : AppCompatActivity(), RecordingCallback {
    
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        // 初始化SDK
        SausageReplayAndroidSDK.initialize(applicationContext)
        
        // 配置录制参数
        val config = RecordingConfig(
            quality = VideoQuality.MEDIUM,
            maxDurationSeconds = 60,
            includeAudio = true,
            outputFormat = OutputFormat.MP4
        )
        
        // 开始录制
        SausageReplayAndroidSDK.startRecording(config, this)
    }
    
    override fun onRecordingStarted() {
        // 录制开始
    }
    
    override fun onRecordingStopped(result: RecordingResult) {
        // 录制完成
    }
    
    // 其他回调方法...
}
```

## API参考

### 核心类

#### SausageReplaySDK

主要的SDK接口类，提供所有录制功能。

**主要方法：**

```csharp
// 初始化SDK
public static bool Initialize(DevicePerformanceTier tier = DevicePerformanceTier.MID_RANGE)

// 开始录制
public static bool StartRecording(RecordingConfig config, IRecordingCallback callback = null)

// 停止录制
public static void StopRecording()

// 暂停录制
public static bool PauseRecording()

// 恢复录制
public static bool ResumeRecording()

// 调整录制质量
public static bool AdjustRecordingQuality(VideoQuality quality)

// 获取录制状态
public static RecordingStatus GetRecordingStatus()

// 获取详细状态
public static DetailedStatus GetDetailedStatus()

// 获取内存使用情况
public static MemoryUsage GetMemoryUsage()

// 错误恢复
public static bool RecoverFromError()

// 释放SDK资源
public static void Release()
```

#### RecordingConfig

录制配置类，用于设置录制参数。

```csharp
public class RecordingConfig
{
    public VideoQuality quality = VideoQuality.MEDIUM;           // 视频质量
    public int maxDurationSeconds = 60;                          // 最大录制时长
    public long maxFileSizeBytes = 50L * 1024 * 1024;           // 最大文件大小
    public bool includeAudio = true;                             // 是否包含音频
    public OutputFormat outputFormat = OutputFormat.MP4;         // 输出格式
    public string outputPath = null;                             // 输出路径
    public int? targetBitrate = null;                            // 目标比特率
    public int targetFps = 30;                                   // 目标帧率
    public DevicePerformanceTier performanceTier = DevicePerformanceTier.MID_RANGE; // 设备档位
}
```

#### IRecordingCallback

录制回调接口，用于接收录制状态更新。

```csharp
public interface IRecordingCallback
{
    void OnRecordingStarted();                                    // 录制开始
    void OnRecordingProgress(long durationMs, long fileSizeBytes); // 录制进度
    void OnRecordingPaused();                                     // 录制暂停
    void OnRecordingResumed();                                    // 录制恢复
    void OnRecordingStopped(RecordingResult result);              // 录制停止
    void OnRecordingError(int errorCode, string errorMessage);    // 录制错误
    void OnRecordingQualityAdjusted(VideoQuality quality);        // 质量调整
}
```

### 枚举类型

#### VideoQuality
```csharp
public enum VideoQuality
{
    LOW = 0,    // 低质量 (480p)
    MEDIUM = 1, // 中等质量 (720p)
    HIGH = 2    // 高质量 (1080p)
}
```

#### OutputFormat
```csharp
public enum OutputFormat
{
    MP4 = 0,   // MP4格式
    GIF = 1,   // GIF格式
    WEBM = 2,  // WebM格式
    AVI = 3    // AVI格式
}
```

#### RecordingStatus
```csharp
public enum RecordingStatus
{
    IDLE = 0,     // 空闲
    RECORDING = 1, // 录制中
    PAUSED = 2,   // 已暂停
    STOPPING = 3  // 停止中
}
```

#### DevicePerformanceTier
```csharp
public enum DevicePerformanceTier
{
    LOW_END = 0,    // 低端设备
    MID_RANGE = 1,  // 中端设备
    HIGH_END = 2,   // 高端设备
    FLAGSHIP = 3    // 旗舰设备
}
```

## 权限管理

### 必需权限

SDK需要以下权限才能正常工作：

- `RECORD_AUDIO`：录制音频
- `WRITE_EXTERNAL_STORAGE`：写入外部存储
- `READ_EXTERNAL_STORAGE`：读取外部存储
- `FOREGROUND_SERVICE`：前台服务
- `FOREGROUND_SERVICE_MEDIA_PROJECTION`：媒体投影前台服务
- `SYSTEM_ALERT_WINDOW`：系统窗口权限（用于屏幕录制）

### 权限请求

```csharp
// 检查权限状态
bool hasMicPermission = SausageReplayPermissionManager.HasMicrophonePermission();
bool hasStoragePermission = SausageReplayPermissionManager.HasStoragePermission();
bool hasAllPermissions = SausageReplayPermissionManager.HasAllRequiredPermissions();

// 请求权限
SausageReplayPermissionManager.RequestMicrophonePermission((granted, errorCode, errorMessage) =>
{
    if (granted)
    {
        Debug.Log("麦克风权限获取成功");
    }
    else
    {
        Debug.LogError($"麦克风权限被拒绝: {errorMessage}");
    }
});

// 请求所有权限
SausageReplayPermissionManager.RequestAllRequiredPermissions((granted, errorCode, errorMessage) =>
{
    if (granted)
    {
        Debug.Log("所有权限获取成功");
    }
    else
    {
        Debug.LogError($"权限请求失败: {errorMessage}");
        // 引导用户到设置页面
        SausageReplayPermissionManager.OpenAppSettings();
    }
});
```

### 屏幕录制权限

屏幕录制需要用户手动授权，SDK会自动处理：

```csharp
// 请求屏幕录制权限
SausageReplayPermissionManager.RequestScreenCapturePermission((granted, errorCode, errorMessage) =>
{
    if (granted)
    {
        Debug.Log("屏幕录制权限获取成功");
    }
    else
    {
        Debug.LogError($"屏幕录制权限被拒绝: {errorMessage}");
    }
});
```

## 设备性能档位

SDK支持根据设备性能自动调整录制参数，提供四个性能档位：

### 档位说明

| 档位 | 描述 | 典型设备 | 推荐分辨率 | 推荐FPS |
|------|------|----------|------------|---------|
| LOW_END | 低端设备 | 入门级手机 | 480p | 24fps |
| MID_RANGE | 中端设备 | 主流手机 | 720p | 30fps |
| HIGH_END | 高端设备 | 旗舰手机 | 1080p | 60fps |
| FLAGSHIP | 旗舰设备 | 顶级手机 | 1080p+ | 60fps+ |

### 使用设备档位

```csharp
// 初始化时指定设备档位
bool success = SausageReplaySDK.Initialize(DevicePerformanceTier.HIGH_END);

// 获取设备档位信息
var tierInfo = SausageReplaySDK.GetDeviceTierInfo();
if (tierInfo != null)
{
    Debug.Log($"设备档位: {tierInfo.tier}");
    Debug.Log($"档位名称: {tierInfo.tierName}");
    Debug.Log($"最大分辨率: {tierInfo.maxWidth}x{tierInfo.maxHeight}");
    Debug.Log($"目标FPS: {tierInfo.targetFps}");
    Debug.Log($"GIF支持: {tierInfo.gifSupported}");
}
```

### 自定义档位配置

SDK支持通过JSON配置文件自定义设备档位参数：

```json
{
  "deviceTiers": {
    "LOW_END": {
      "maxWidth": 480,
      "maxHeight": 854,
      "targetFps": 24,
      "videoBitrate": 1000000,
      "audioBitrate": 64000,
      "gifSupported": false,
      "threadCount": 2
    },
    "MID_RANGE": {
      "maxWidth": 720,
      "maxHeight": 1280,
      "targetFps": 30,
      "videoBitrate": 2500000,
      "audioBitrate": 128000,
      "gifSupported": true,
      "threadCount": 4
    }
  }
}
```

## 高级功能

### 实时质量调整

```csharp
// 录制过程中调整质量
bool success = SausageReplaySDK.AdjustRecordingQuality(VideoQuality.HIGH);

// 监听质量调整事件
SausageReplaySDK.OnRecordingQualityAdjusted += (quality) =>
{
    Debug.Log($"录制质量已调整到: {quality}");
};
```

### 视频格式转换

```csharp
// 转换录制文件格式
SausageReplaySDK.ConvertVideoFormat(inputPath, OutputFormat.GIF, (success, outputPath) =>
{
    if (success)
    {
        Debug.Log($"格式转换成功: {outputPath}");
    }
    else
    {
        Debug.LogError("格式转换失败");
    }
});
```

### 内存监控

```csharp
// 获取内存使用情况
var memoryUsage = SausageReplaySDK.GetMemoryUsage();
if (memoryUsage != null)
{
    Debug.Log($"总内存: {memoryUsage.totalMemory / 1024 / 1024}MB");
    Debug.Log($"已使用: {memoryUsage.usedMemory / 1024 / 1024}MB");
    Debug.Log($"使用率: {memoryUsage.usagePercentage}%");
}
```

### 错误恢复

```csharp
// 执行错误恢复
bool success = SausageReplaySDK.RecoverFromError();
if (success)
{
    Debug.Log("错误恢复成功");
}
else
{
    Debug.LogError("错误恢复失败");
}
```

### 性能监控（高级API）

```csharp
// 创建性能监控器
var monitor = SausageReplaySDK.CreatePerformanceMonitor(new PerformanceCallback
{
    OnPerformanceMetrics = (metrics) =>
    {
        Debug.Log($"当前FPS: {metrics.currentFps}");
        Debug.Log($"丢帧率: {metrics.frameDropRate:P2}");
        Debug.Log($"队列深度: {metrics.queueDepth}");
    },
    OnBitrateReduction = (reduction) =>
    {
        Debug.Log($"比特率降低: {reduction:P2}");
    }
});

// 开始监控
monitor?.StartMonitoring();

// 记录帧
monitor?.RecordFrame();

// 停止监控
monitor?.StopMonitoring();
```

## 故障排除

### 常见问题

#### 1. SDK初始化失败

**问题**：`SausageReplaySDK.Initialize()`返回false

**解决方案**：
- 检查权限是否已授予
- 确认设备支持屏幕录制
- 检查Android版本是否满足要求

```csharp
// 检查平台支持
bool supported = SausageReplaySDK.IsPlatformSupported();
if (!supported)
{
    Debug.LogError("当前平台不支持屏幕录制");
}
```

#### 2. 录制启动失败

**问题**：`StartRecording()`返回false

**解决方案**：
- 确认SDK已正确初始化
- 检查录制配置参数
- 确认没有其他应用正在录制

```csharp
// 检查录制状态
var status = SausageReplaySDK.GetRecordingStatus();
if (status != RecordingStatus.IDLE)
{
    Debug.LogWarning($"当前状态不是空闲: {status}");
}
```

#### 3. 权限被拒绝

**问题**：权限请求失败

**解决方案**：
- 引导用户到设置页面手动授权
- 检查权限请求时机
- 提供权限说明

```csharp
// 检查是否需要显示权限说明
bool shouldShow = SausageReplayPermissionManager.ShouldShowPermissionRationale();
if (shouldShow)
{
    // 显示权限说明对话框
    ShowPermissionRationaleDialog();
}
```

#### 4. 录制文件无法找到

**问题**：录制完成后找不到文件

**解决方案**：
- 检查存储权限
- 确认输出路径正确
- 检查存储空间是否充足

```csharp
// 获取详细状态
var detailedStatus = SausageReplaySDK.GetDetailedStatus();
if (detailedStatus != null)
{
    Debug.Log($"输出文件: {detailedStatus.outputFile}");
    Debug.Log($"文件大小: {detailedStatus.outputFileSize} bytes");
}
```

### 调试技巧

#### 1. 启用详细日志

```csharp
// 在Unity中启用详细日志
Debug.unityLogger.logEnabled = true;
```

#### 2. 检查SDK版本

```csharp
string version = SausageReplaySDK.GetVersion();
Debug.Log($"SDK版本: {version}");
```

#### 3. 监控内存使用

```csharp
// 定期检查内存使用情况
InvokeRepeating(nameof(CheckMemoryUsage), 0f, 5f);

private void CheckMemoryUsage()
{
    var memoryUsage = SausageReplaySDK.GetMemoryUsage();
    if (memoryUsage != null && memoryUsage.usagePercentage > 80)
    {
        Debug.LogWarning($"内存使用率过高: {memoryUsage.usagePercentage}%");
    }
}
```

## 更新日志

### v1.0.0 (2025-01-11)

#### 新增功能
- ✅ 基础屏幕录制功能
- ✅ 音频录制支持
- ✅ 暂停/恢复录制
- ✅ 实时质量调整
- ✅ 设备性能档位适配
- ✅ 多格式输出支持（MP4、GIF、WEBM、AVI）
- ✅ 错误恢复机制
- ✅ 内存监控
- ✅ Unity C#桥接
- ✅ 权限管理
- ✅ 主线程调度器

#### 技术特性
- 支持Android 5.1+ (API Level 22+)
- 支持Unity 2020.3 LTS+
- 支持多架构（arm64-v8a, armeabi-v7a, x86, x86_64）
- 使用Kotlin开发
- 基于MediaProjection API
- 支持前台服务录制

#### 性能优化
- 设备档位自适应
- 动态质量调整
- 内存回收机制
- 线程池优化
- 编码队列管理

---

## 技术支持

如果您在使用过程中遇到问题，请：

1. 查看本文档的故障排除部分
2. 检查SDK版本是否为最新
3. 查看Unity Console和Android Logcat日志
4. 联系技术支持团队

**联系方式**：
- 邮箱：support@sausage-replay.com
- 文档：https://docs.sausage-replay.com
- 问题反馈：https://github.com/sausage-replay/sdk/issues

---

*最后更新：2025年1月11日*
