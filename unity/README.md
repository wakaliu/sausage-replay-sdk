# Sausage Replay SDK - Unity 集成指南

## 概述

Sausage Replay SDK Unity 插件提供了在Unity项目中使用Android屏幕录制功能的完整解决方案。本插件包含C#桥接代码、权限管理、示例代码和完整的集成指南。

## 目录结构

```
unity/
├── Plugins/
│   └── Android/
│       ├── SausageReplaySDK.aar          # Android SDK AAR文件
│       ├── AndroidManifest.xml           # Android权限配置
│       └── res/
│           └── xml/
│               └── file_paths.xml        # FileProvider路径配置
├── Scripts/
│   ├── SausageReplaySDK.cs               # 主SDK接口
│   ├── UnityMainThreadDispatcher.cs      # 主线程调度器
│   ├── SausageReplayPermissionManager.cs # 权限管理器
│   └── Examples/
│       └── SausageReplayExample.cs       # 使用示例
└── README.md                             # 本文件
```

## 快速开始

### 1. 导入插件

1. 将整个 `unity` 文件夹复制到您的Unity项目的 `Assets` 目录下
2. 确保 `SausageReplaySDK.aar` 文件位于 `Assets/Plugins/Android/` 目录
3. 在Unity中刷新资源（Ctrl+R 或 Cmd+R）

### 2. 配置Android设置

1. 打开 **File > Build Settings**
2. 选择 **Android** 平台
3. 点击 **Switch Platform**
4. 点击 **Player Settings**
5. 在 **Other Settings** 中设置：
   - **Minimum API Level**: 22 (Android 5.1)
   - **Target API Level**: 33 或更高
   - **Scripting Backend**: IL2CPP
   - **Target Architectures**: ARM64

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
                bool success = SausageReplaySDK.Initialize(VideoQualityPreset.Standard);
                if (success)
                {
                    Debug.Log("SDK初始化成功");
                }
            }
        });
    }

    public void StartRecording()
    {
        // 3. 创建录制配置
        var config = new RecordingConfig
        {
            quality = VideoQuality.HIGH,
            maxDurationSeconds = 60,
            includeAudio = true
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
}
```

## 详细API说明

### 核心类

#### SausageReplaySDK

主要的SDK接口类，提供所有录制功能。

**主要方法：**
- `Initialize(VideoQualityPreset preset)` - 初始化SDK
- `StartRecording(RecordingConfig config, IRecordingCallback callback)` - 开始录制
- `StopRecording()` - 停止录制
- `AdjustRecordingQuality(VideoQuality quality)` - 调整录制质量


### 数据结构

#### RecordingConfig

录制配置类：

```csharp
public class RecordingConfig
{
    public VideoQuality quality = VideoQuality.MEDIUM;        // 视频质量
    public int maxDurationSeconds = 60;                       // 最大录制时长
    public long maxFileSizeBytes = 50L * 1024 * 1024;        // 最大文件大小
    public bool includeAudio = true;                          // 是否包含音频
    public OutputFormat outputFormat = OutputFormat.MP4;      // 输出格式
    public string outputPath = null;                          // 自定义输出路径
    public int? targetBitrate = null;                         // 目标比特率
    public int targetFps = 30;                                // 目标帧率
    public int performanceTier = (int)VideoQualityPreset.Standard; // 视频清晰度档位
}
```

#### RecordingResult

录制结果类：

```csharp
public class RecordingResult
{
    public bool isSuccess;        // 是否成功
    public string filePath;       // 文件路径
    public long fileSize;         // 文件大小
    public float duration;        // 录制时长
    public int errorCode;         // 错误码
    public string errorMessage;   // 错误信息
}
```

### 枚举类型

#### VideoQualityPreset

视频清晰度档位：
- `Basic` - 720p30
- `Standard` - 1080p30（默认）
- `Smooth` - 720p60
- `HighFPS` - 1080p60
- `Ultra` - 1440p30/60

#### VideoQuality

视频质量等级：
- `LOW` - 低质量 (480p)
- `MEDIUM` - 中等质量 (720p)
- `HIGH` - 高质量 (1080p)

#### OutputFormat

输出格式：
- `MP4` - MP4格式
- `GIF` - GIF格式
- `WEBM` - WebM格式
- `AVI` - AVI格式

#### RecordingStatus

录制状态：
- `IDLE` - 空闲
- `RECORDING` - 录制中
- `PAUSED` - 已暂停
- `STOPPING` - 停止中

## 回调接口

### IRecordingCallback

录制回调接口，需要实现以下方法：

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

## 高级功能

### 设备档位自适应

SDK支持根据设备性能自动调整录制参数：

```csharp
// 获取设备档位信息
var tierInfo = SausageReplaySDK.GetDeviceTierInfo();
if (tierInfo != null)
{
    Debug.Log($"设备档位: {tierInfo.tier}");
    Debug.Log($"最大分辨率: {tierInfo.maxWidth}x{tierInfo.maxHeight}");
    Debug.Log($"GIF支持: {tierInfo.gifSupported}");
}
```

### 格式转换

支持将录制的MP4文件转换为其他格式：

```csharp
// 转换MP4为GIF
SausageReplaySDK.ConvertVideoFormat(
    inputPath: "/path/to/video.mp4",
    outputFormat: OutputFormat.GIF,
    callback: (success, outputPath) =>
    {
        if (success)
        {
            Debug.Log($"转换成功: {outputPath}");
        }
    }
);
```

### 性能监控

获取内存使用情况和详细状态：

```csharp
// 获取内存使用情况
var memoryUsage = SausageReplaySDK.GetMemoryUsage();
if (memoryUsage != null)
{
    Debug.Log($"内存使用: {memoryUsage.usagePercentage}%");
}

// 获取详细状态
var detailedStatus = SausageReplaySDK.GetDetailedStatus();
if (detailedStatus != null)
{
    Debug.Log($"录制状态: {detailedStatus.status}");
    Debug.Log($"输出文件: {detailedStatus.outputFile}");
}
```

## 错误处理

### 错误码说明

- **1000-1999**: 权限相关错误
  - `1001`: 麦克风权限被拒绝
  - `1002`: 存储权限被拒绝
  - `1003`: 屏幕录制权限被拒绝

- **2000-2999**: 录制相关错误
  - `2001`: 录制未开始
  - `2002`: 录制已在进行中
  - `2003`: 录制启动失败
  - `2004`: 录制停止失败

- **3000-3999**: 暂停/恢复相关错误
  - `3001`: 暂停录制失败
  - `3002`: 恢复录制失败
  - `3003`: 质量调整失败

### 错误恢复

当发生错误时，可以使用错误恢复功能：

```csharp
// 执行错误恢复
bool success = SausageReplaySDK.RecoverFromError();
if (success)
{
    Debug.Log("错误恢复成功");
}
```

## 权限管理

### 必需权限

SDK需要以下Android权限：

- `RECORD_AUDIO` - 录制音频
- `WRITE_EXTERNAL_STORAGE` - 写入外部存储
- `READ_EXTERNAL_STORAGE` - 读取外部存储
- `FOREGROUND_SERVICE` - 前台服务（Android 10+）
- `FOREGROUND_SERVICE_MEDIA_PROJECTION` - 媒体投影前台服务

### 权限请求流程

```csharp
// 1. 检查权限状态
bool hasPermissions = SausageReplayPermissionManager.HasAllRequiredPermissions();

if (!hasPermissions)
{
    // 2. 请求权限
    SausageReplayPermissionManager.RequestAllRequiredPermissions((granted, errorCode, errorMessage) =>
    {
        if (granted)
        {
            Debug.Log("权限获取成功");
            // 继续初始化SDK
        }
        else
        {
            Debug.LogError($"权限获取失败: {errorCode} - {errorMessage}");
            // 引导用户到设置页面
            SausageReplayPermissionManager.OpenAppSettings();
        }
    });
}
```

## 构建配置

### Android Manifest 配置

插件已包含必要的Android Manifest配置，但您可能需要根据项目需求进行调整：

```xml
<!-- 在您的AndroidManifest.xml中添加 -->
<uses-permission android:name="android.permission.RECORD_AUDIO" />
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" />
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_MEDIA_PROJECTION" />
```

### ProGuard 配置

如果启用了代码混淆，需要在ProGuard配置中添加：

```
-keep class com.funny.replaysdk.** { *; }
-keep class androidx.core.content.FileProvider { *; }
```

## 示例项目

### 使用示例脚本

项目中包含完整的使用示例 `SausageReplayExample.cs`，展示了：

- SDK初始化和权限请求
- 录制控制（开始、停止、暂停、恢复）
- 质量调整
- 格式转换
- 状态监控
- 错误处理

### 运行示例

1. 将 `SausageReplayExample.cs` 添加到场景中的GameObject
2. 在Inspector中配置UI组件引用
3. 构建并运行到Android设备
4. 按照UI提示操作

## 常见问题

### Q: 录制文件保存在哪里？

A: 录制文件默认保存在 `/Android/data/[包名]/files/Movies/replay/` 目录下。

### Q: 如何自定义录制文件保存路径？

A: 在 `RecordingConfig` 中设置 `outputPath` 属性：

```csharp
var config = new RecordingConfig
{
    outputPath = "/sdcard/MyVideos/custom_path.mp4"
};
```

### Q: 支持哪些视频格式？

A: 目前主要支持MP4格式录制，其他格式（GIF、WEBM、AVI）需要通过格式转换功能实现。

### Q: 如何优化录制性能？

A: 
1. 根据设备性能选择合适的档位
2. 调整录制质量参数
3. 在非关键场景进行录制
4. 监控内存使用情况

### Q: 录制过程中可以调整参数吗？

A: 是的，支持动态调整录制质量，但不支持调整分辨率、帧率等基础参数。

## 技术支持

如果您在使用过程中遇到问题，请：

1. 查看Unity Console中的错误日志
2. 检查Android设备的权限设置
3. 确认设备支持屏幕录制功能
4. 参考示例代码进行对比

## 版本历史

- **v1.0.0**: 初始版本
  - 基础录制功能
  - 暂停/恢复支持
  - 设备档位自适应
  - 格式转换支持
  - 完整的Unity集成
