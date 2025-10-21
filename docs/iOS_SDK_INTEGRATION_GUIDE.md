# iOS SDK 集成指南

## 概述

Sausage Replay iOS SDK 是一个专为 Unity 游戏引擎设计的屏幕录制 SDK，支持 iOS 12.0+ 设备。本指南将帮助您快速集成和使用该 SDK。

## 系统要求

- **iOS 版本**: 12.0 或更高
- **Unity 版本**: 2020.3 LTS 或更高
- **Xcode 版本**: 12.0 或更高
- **开发语言**: Objective-C

## 快速开始

### 1. 导入 SDK

将以下文件复制到您的 Unity 项目中：

```
unity/Plugins/iOS/
├── SausageReplay.xcframework/          # iOS SDK 框架
├── SausageReplaySDK.h                  # Unity 桥接头文件
└── SausageReplaySDK.mm                 # Unity 桥接实现文件
```

### 2. 基本使用

```csharp
using UnityEngine;

public class ReplayManager : MonoBehaviour
{
    void Start()
    {
        // 初始化 SDK，使用 Standard 档位 (1080p30)
        bool success = SausageReplaySDK.Initialize(VideoQualityPreset.Standard);
        
        if (success)
        {
            Debug.Log("SDK 初始化成功");
        }
        else
        {
            Debug.LogError("SDK 初始化失败");
        }
    }
    
    public void StartRecording()
    {
        // 开始录制
        bool success = SausageReplaySDK.StartRecording();
        if (success)
        {
            Debug.Log("开始录制");
        }
    }
    
    public void StopRecording()
    {
        // 停止录制
        SausageReplaySDK.StopRecording();
        Debug.Log("停止录制");
    }
}
```

## API 参考

### 初始化

#### `Initialize(VideoQualityPreset preset)`

初始化 SDK。

**参数:**
- `preset`: 视频清晰度档位
  - `VideoQualityPreset.Basic` (0): 720p30
  - `VideoQualityPreset.Standard` (1): 1080p30 (默认)
  - `VideoQualityPreset.Smooth` (2): 720p60
  - `VideoQualityPreset.HighFps` (3): 1080p60
  - `VideoQualityPreset.Ultra` (4): 1440p30/60

**返回值:**
- `bool`: 是否初始化成功

**示例:**
```csharp
// 使用 Standard 档位初始化
bool success = SausageReplaySDK.Initialize(VideoQualityPreset.Standard);

// 使用 HighFps 档位初始化
bool success = SausageReplaySDK.Initialize(VideoQualityPreset.HighFps);
```

### 录制控制

#### `StartRecording()`

开始屏幕录制。

**返回值:**
- `bool`: 是否开始成功

#### `StopRecording()`

停止屏幕录制。

#### `PauseRecording()`

暂停录制。

**返回值:**
- `bool`: 是否暂停成功

#### `ResumeRecording()`

恢复录制。

**返回值:**
- `bool`: 是否恢复成功

#### `GetRecordingStatus()`

获取当前录制状态。

**返回值:**
- `RecordingStatus`: 录制状态枚举
  - `RecordingStatus.Idle`: 空闲
  - `RecordingStatus.Starting`: 开始中
  - `RecordingStatus.Recording`: 录制中
  - `RecordingStatus.Paused`: 已暂停
  - `RecordingStatus.Stopping`: 停止中

### 状态监控

#### `GetDetailedStatus()`

获取详细的录制状态信息。

**返回值:**
- `DetailedStatus`: 详细状态对象，包含：
  - `status`: 录制状态
  - `isRecording`: 是否正在录制
  - `isPaused`: 是否已暂停
  - `duration`: 录制时长（毫秒）
  - `fileSize`: 文件大小（字节）
  - `errorCode`: 错误码
  - `errorMessage`: 错误信息

#### `GetMemoryUsage()`

获取内存使用情况。

**返回值:**
- `MemoryUsage`: 内存使用对象，包含：
  - `usedMemory`: 已使用内存
  - `maxMemory`: 最大内存
  - `usagePercentage`: 使用百分比

### 权限管理

#### `HasMicrophonePermission()`

检查是否有麦克风权限。

**返回值:**
- `bool`: 是否有权限

#### `RequestMicrophonePermission()`

请求麦克风权限。

### 格式转换

#### `IsGifConversionSupported()`

检查是否支持 GIF 转换。

**返回值:**
- `bool`: 是否支持

#### `GetGifConversionParams()`

获取 GIF 转换参数。

**返回值:**
- `GifConversionParams`: GIF 转换参数对象

#### `ConvertVideoFormat(string inputPath, OutputFormat outputFormat, Action<bool, string> callback)`

转换视频格式。

**参数:**
- `inputPath`: 输入文件路径
- `outputFormat`: 输出格式
- `callback`: 转换完成回调

### 错误处理

#### `RecoverFromError()`

从错误中恢复。

**返回值:**
- `bool`: 是否恢复成功

#### `ResetStatus()`

重置 SDK 状态。

## 回调事件

SDK 支持以下回调事件：

```csharp
public class ReplayManager : MonoBehaviour
{
    void Start()
    {
        // 设置录制回调
        SausageReplaySDK.SetRecordingCallback(new RecordingCallback
        {
            OnRecordingStarted = () => Debug.Log("录制开始"),
            OnRecordingStopped = (result) => Debug.Log($"录制结束: {result.isSuccess}"),
            OnRecordingProgress = (duration, fileSize) => Debug.Log($"录制进度: {duration}ms, {fileSize}bytes"),
            OnRecordingError = (errorCode, message) => Debug.LogError($"录制错误: {errorCode} - {message}")
        });
    }
}
```

## 配置说明

### 视频清晰度档位

| 档位 | 分辨率 | 帧率 | 比特率 | 适用场景 |
|------|--------|------|--------|----------|
| Basic | 720p | 30fps | 2 Mbps | 低端设备 |
| Standard | 1080p | 30fps | 4 Mbps | 标准设备 (默认) |
| Smooth | 720p | 60fps | 3 Mbps | 流畅录制 |
| HighFps | 1080p | 60fps | 6 Mbps | 高端设备 |
| Ultra | 1440p | 30/60fps | 8 Mbps | 旗舰设备 |

### 录制配置

录制配置通过 `RecordingConfig` 对象设置：

```csharp
var config = new RecordingConfig
{
    qualityPreset = VideoQualityPreset.Standard,
    maxDurationSeconds = 60,
    maxFileSizeBytes = 50L * 1024 * 1024, // 50MB
    includeAudio = true,
    outputFormat = OutputFormat.MP4,
    targetFps = 30
};
```

## 注意事项

1. **权限要求**: 确保在 `Info.plist` 中添加必要的权限描述：
   ```xml
   <key>NSMicrophoneUsageDescription</key>
   <string>需要麦克风权限来录制音频</string>
   <key>NSPhotoLibraryAddUsageDescription</key>
   <string>需要相册权限来保存录制的视频</string>
   ```

2. **录制限制**: 
   - 只能在应用前台录制
   - 录制过程中无法动态调整质量
   - 录制文件保存在应用沙盒中

3. **性能建议**:
   - 根据设备性能选择合适的清晰度档位
   - 避免在录制过程中进行大量计算
   - 定期检查内存使用情况

4. **错误处理**: 始终检查 API 返回值，并实现适当的错误处理逻辑。

## 故障排除

### 常见问题

1. **SDK 初始化失败**
   - 检查 iOS 版本是否满足要求
   - 确认设备支持屏幕录制功能

2. **录制失败**
   - 检查权限是否已授予
   - 确认应用在前台运行
   - 检查设备存储空间

3. **视频文件无法播放**
   - 确认录制过程正常完成
   - 检查文件路径是否正确
   - 验证视频编码格式

### 调试信息

启用详细日志：

```csharp
// 在开发阶段启用详细日志
#if UNITY_EDITOR || DEVELOPMENT_BUILD
    Debug.unityLogger.logEnabled = true;
#endif
```

## 版本信息

- **当前版本**: 1.0.0
- **最低 iOS 版本**: 12.0
- **支持的架构**: arm64, x86_64 (模拟器)

## 技术支持

如有问题，请联系技术支持团队或查看项目文档。