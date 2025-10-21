# Unity iOS 集成指南

## 概述

本指南介绍如何在Unity项目中集成Sausage Replay iOS SDK，实现跨平台的屏幕录制功能。

## 系统要求

- **Unity版本**: Unity 2020.3 LTS 或更高版本
- **iOS版本**: iOS 12.0+
- **Xcode版本**: Xcode 12.0+
- **部署目标**: iOS 12.0+

## 集成步骤

### 1. 导入SDK文件

将以下文件复制到您的Unity项目中：

```
Assets/Plugins/iOS/
├── SausageReplaySDK.h          # iOS桥接头文件
├── SausageReplaySDK.mm         # iOS桥接实现文件
└── SausageReplay.xcframework   # iOS SDK框架

Assets/Scripts/
├── SausageReplaySDK.cs         # Unity主接口
├── SausageReplayPermissionManager.cs  # 权限管理
├── UnityMainThreadDispatcher.cs       # 主线程调度器
└── Examples/
    ├── SausageReplayExample.cs        # 通用示例
    └── SausageReplayIOSExample.cs     # iOS专用示例
```

### 2. 配置iOS构建设置

#### 2.1 Player Settings

在Unity的Player Settings中配置：

- **Target Device**: iPhone & iPad
- **Target minimum iOS Version**: 12.0
- **Architecture**: ARM64
- **Scripting Backend**: IL2CPP
- **Api Compatibility Level**: .NET Standard 2.1

#### 2.2 权限配置

在Player Settings的iOS设置中添加权限描述：

```
Microphone Usage Description: 需要访问麦克风来录制音频
Photo Library Add Usage Description: 需要访问相册权限来保存录制的视频
Photo Library Usage Description: 需要访问相册权限来保存录制的视频
```

### 3. 代码集成

#### 3.1 基础使用

```csharp
using SausageReplay;

public class RecordingManager : MonoBehaviour
{
    void Start()
    {
        // 初始化SDK
        bool success = SausageReplaySDK.Initialize(VideoQualityPreset.Standard);
        if (success)
        {
            Debug.Log("SDK初始化成功");
        }
    }
    
    public void StartRecording()
    {
        var config = new RecordingConfig
        {
            QualityPreset = VideoQualityPreset.Standard,
            IncludeAudio = true,
            MaxDurationSeconds = 60,
            OutputFormat = OutputFormat.MP4
        };
        
        SausageReplaySDK.StartRecording(config);
    }
    
    public void StopRecording()
    {
        SausageReplaySDK.StopRecording();
    }
}
```

#### 3.2 事件监听

```csharp
void OnEnable()
{
    SausageReplaySDK.OnRecordingStarted += OnRecordingStarted;
    SausageReplaySDK.OnRecordingStopped += OnRecordingStopped;
    SausageReplaySDK.OnRecordingError += OnRecordingError;
}

void OnDisable()
{
    SausageReplaySDK.OnRecordingStarted -= OnRecordingStarted;
    SausageReplaySDK.OnRecordingStopped -= OnRecordingStopped;
    SausageReplaySDK.OnRecordingError -= OnRecordingError;
}

private void OnRecordingStarted()
{
    Debug.Log("录制开始");
}

private void OnRecordingStopped(RecordingResult result)
{
    if (result.IsSuccess)
    {
        Debug.Log($"录制完成: {result.FilePath}");
    }
    else
    {
        Debug.Log($"录制失败: {result.ErrorMessage}");
    }
}

private void OnRecordingError(int errorCode, string errorMessage)
{
    Debug.LogError($"录制错误: {errorCode} - {errorMessage}");
}
```

### 4. 视频清晰度档位

SDK提供5个预设的视频清晰度档位：

```csharp
public enum VideoQualityPreset
{
    Basic = 0,      // 720p30, 2 Mbps
    Standard = 1,   // 1080p30, 4 Mbps
    Smooth = 2,     // 720p60, 3 Mbps
    HighFPS = 3,    // 1080p60, 6 Mbps
    Ultra = 4       // 1440p30/60, 8 Mbps
}
```

#### 档位选择建议

```csharp
// 根据设备性能选择档位
VideoQualityPreset GetOptimalPreset()
{
    // 获取设备信息
    var deviceInfo = SausageReplaySDK.GetDeviceTierInfo();
    
    // 根据设备性能选择档位
    if (deviceInfo.TierName.Contains("HighEnd"))
    {
        return VideoQualityPreset.Ultra;
    }
    else if (deviceInfo.TierName.Contains("MidRange"))
    {
        return VideoQualityPreset.Standard;
    }
    else
    {
        return VideoQualityPreset.Basic;
    }
}
```

### 5. 权限管理

#### 5.1 检查权限

```csharp
bool hasPermission = SausageReplaySDK.HasMicrophonePermission();
if (!hasPermission)
{
    Debug.Log("需要麦克风权限");
}
```

#### 5.2 请求权限

```csharp
SausageReplaySDK.RequestMicrophonePermission((granted) =>
{
    if (granted)
    {
        Debug.Log("麦克风权限已授权");
    }
    else
    {
        Debug.Log("麦克风权限被拒绝");
    }
});
```

### 6. 高级功能

#### 6.1 录制控制

```csharp
// 暂停录制
bool success = SausageReplaySDK.PauseRecording();

// 恢复录制
bool success = SausageReplaySDK.ResumeRecording();

// 获取录制状态
int status = SausageReplaySDK.GetRecordingStatus();
```

#### 6.2 状态监控

```csharp
// 获取详细状态
string statusJson = SausageReplaySDK.GetDetailedStatus();
Debug.Log($"详细状态: {statusJson}");

// 获取内存使用情况
string memoryJson = SausageReplaySDK.GetMemoryUsage();
Debug.Log($"内存使用: {memoryJson}");

// 获取设备信息
var deviceInfo = SausageReplaySDK.GetDeviceTierInfo();
Debug.Log($"设备档位: {deviceInfo.TierName}");
```

#### 6.3 格式转换

```csharp
// 检查GIF转换支持
bool supported = SausageReplaySDK.IsGifConversionSupported();

// 转换视频格式
SausageReplaySDK.ConvertVideoFormat("input.mp4", OutputFormat.GIF, (success, outputPath) =>
{
    if (success)
    {
        Debug.Log($"转换成功: {outputPath}");
    }
    else
    {
        Debug.Log("转换失败");
    }
});
```

### 7. 错误处理

#### 7.1 常见错误码

| 错误码 | 描述 | 解决方案 |
|--------|------|----------|
| 2000 | 录制已在进行中 | 等待当前录制完成 |
| 2001 | 录制未开始 | 先调用开始录制 |
| 2002 | 录制已在进行中 | 检查录制状态 |
| 2003 | 屏幕录制不可用 | 检查设备支持 |
| 2004 | 录制失败 | 检查权限和配置 |

#### 7.2 错误恢复

```csharp
// 从错误中恢复
bool recovered = SausageReplaySDK.RecoverFromError();
if (recovered)
{
    Debug.Log("错误恢复成功");
}
else
{
    Debug.Log("错误恢复失败，需要重新初始化");
    SausageReplaySDK.Initialize(VideoQualityPreset.Standard);
}
```

### 8. iOS特殊注意事项

#### 8.1 ReplayKit限制

- 录制过程中无法直接访问视频文件
- 停止录制后会显示系统预览界面
- 用户需要通过预览界面保存视频到相册

#### 8.2 录制流程

```csharp
private void OnRecordingStopped(RecordingResult result)
{
    if (result.IsSuccess)
    {
        Debug.Log("录制完成，iOS会显示预览界面");
        Debug.Log("用户需要通过预览界面保存视频到相册");
        
        // 注意：result.FilePath 是占位文件路径
        // 真实的视频文件需要通过系统预览界面保存
    }
}
```

#### 8.3 权限处理

```csharp
void Start()
{
    // 检查并请求权限
    if (!SausageReplaySDK.HasMicrophonePermission())
    {
        SausageReplaySDK.RequestMicrophonePermission((granted) =>
        {
            if (granted)
            {
                InitializeSDK();
            }
            else
            {
                ShowPermissionDialog();
            }
        });
    }
    else
    {
        InitializeSDK();
    }
}
```

### 9. 构建和部署

#### 9.1 Unity构建

1. 在Unity中选择 **File > Build Settings**
2. 选择 **iOS** 平台
3. 点击 **Build** 生成Xcode项目

#### 9.2 Xcode配置

1. 打开生成的Xcode项目
2. 在项目设置中添加必要的框架：
   - ReplayKit.framework
   - AVFoundation.framework
   - Photos.framework
   - PhotosUI.framework

3. 确保 `SausageReplay.xcframework` 已正确链接

#### 9.3 测试

1. 在真机上测试（模拟器不支持屏幕录制）
2. 确保所有权限都已正确配置
3. 测试录制、暂停、恢复、停止功能

### 10. 示例项目

参考 `Assets/Scripts/Examples/SausageReplayIOSExample.cs` 了解完整的使用方法。

### 11. 故障排除

#### 11.1 常见问题

**Q: 录制失败，显示"设备不支持屏幕录制"**
A: 确保在真机上测试，模拟器不支持屏幕录制功能。

**Q: 录制过程中没有音频**
A: 检查麦克风权限，确保在录制配置中启用了音频。

**Q: 录制的视频无法播放**
A: 在iOS上，录制的视频需要通过系统预览界面保存到相册。

**Q: SDK初始化失败**
A: 检查iOS版本是否满足要求（iOS 12.0+），确保所有框架都已正确链接。

#### 11.2 调试技巧

```csharp
// 启用详细日志
Debug.Log($"SDK版本: {SausageReplaySDK.GetVersion()}");
Debug.Log($"平台支持: {SausageReplaySDK.IsPlatformSupported()}");
Debug.Log($"设备信息: {SausageReplaySDK.GetDeviceTierInfo()}");
Debug.Log($"内存使用: {SausageReplaySDK.GetMemoryUsage()}");
```

### 12. 性能优化

#### 12.1 档位选择

```csharp
// 根据设备性能选择合适的档位
VideoQualityPreset GetOptimalPreset()
{
    var deviceInfo = SausageReplaySDK.GetDeviceTierInfo();
    
    // 高端设备使用Ultra档位
    if (deviceInfo.MaxWidth >= 2560)
    {
        return VideoQualityPreset.Ultra;
    }
    // 中端设备使用Standard档位
    else if (deviceInfo.MaxWidth >= 1920)
    {
        return VideoQualityPreset.Standard;
    }
    // 低端设备使用Basic档位
    else
    {
        return VideoQualityPreset.Basic;
    }
}
```

#### 12.2 内存监控

```csharp
void Update()
{
    // 定期检查内存使用情况
    if (Time.frameCount % 300 == 0) // 每5秒检查一次
    {
        var memoryUsage = SausageReplaySDK.GetMemoryUsage();
        if (memoryUsage.UsagePercentage > 80)
        {
            Debug.LogWarning("内存使用率过高，建议停止录制");
        }
    }
}
```

## 技术支持

如有问题，请联系技术支持团队或查看项目文档。

## 更新日志

### v1.0.0
- 初始版本发布
- 支持iOS屏幕录制功能
- 支持5个视频清晰度档位
- 支持音频录制
- 支持暂停/恢复功能
- 支持Unity事件系统
