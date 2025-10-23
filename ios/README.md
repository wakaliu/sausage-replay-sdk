# SausageReplay iOS SDK

SausageReplay iOS SDK 是一个专为iOS平台设计的屏幕录制SDK，支持高质量屏幕录制、音频录制等功能。

## 特性

- 🎥 **高质量屏幕录制**：支持多种清晰度档位录制
- 🎵 **音频录制**：支持麦克风音频录制
- 📱 **清晰度档位**：支持Basic、Standard、Smooth、HighFps、Ultra档位
- 🎬 **MP4格式输出**：标准MP4格式录制

## 系统要求

- **最低版本**：iOS 12.0+
- **架构支持**：arm64 (真机), arm64 + x86_64 (模拟器)
- **集成平台**：Unity 2020.3 LTS 或更高版本

## 快速开始

### 1. 集成到Unity项目

1. 将 `SausageReplay.xcframework` 复制到 `Assets/Plugins/iOS/` 目录
2. 确保 `SausageReplaySDK.cs` 脚本在项目中
3. 在Unity中设置iOS平台并构建

### 2. 基本使用

```csharp
using SausageReplay;

public class ReplayController : MonoBehaviour
{
    void Start()
    {
        // 初始化SDK，使用Standard档位
        bool initialized = SausageReplaySDK.Initialize(VideoQualityPreset.Standard);
        if (initialized)
        {
            Debug.Log("SDK初始化成功");
        }
    }
    
    public void StartRecording()
    {
        // 开始录制
        bool started = SausageReplaySDK.StartRecording();
        if (started)
        {
            Debug.Log("录制开始");
        }
    }
    
    public void StopRecording()
    {
        SausageReplaySDK.StopRecording();
    }
}

// 实现录制回调
public class ReplayController : MonoBehaviour, SausageReplaySDK.IRecordingCallback
{
    public void OnRecordingStarted()
    {
        Debug.Log("录制开始");
    }
    
    public void OnRecordingStopped(SausageReplaySDK.RecordingResult result)
    {
        if (result.isSuccess)
        {
            Debug.Log($"录制成功: {result.filePath}");
        }
        else
        {
            Debug.LogError($"录制失败: {result.errorMessage}");
        }
    }
    
    // 其他回调方法...
}
```

## API参考

### 核心API

#### 初始化
```csharp
bool Initialize(VideoQualityPreset preset)
```

#### 录制控制
```csharp
bool StartRecording()
void StopRecording()
RecordingStatus GetRecordingStatus()
bool AdjustRecordingQuality(VideoQuality quality)
```

#### 状态查询
```csharp
bool IsPlatformSupported()
string GetVersion()
DetailedStatus GetDetailedStatus()
```

### 视频清晰度档位

- `Basic` (0)：720p30
- `Standard` (1)：1080p30 (默认)
- `Smooth` (2)：720p60
- `HighFps` (3)：1080p60
- `Ultra` (4)：1440p30/60

### 录制配置

```csharp
public class RecordingConfig
{
    public VideoQualityPreset qualityPreset = VideoQualityPreset.Standard;  // 视频清晰度档位
    public int maxDurationSeconds = 1800;                                   // 最大录制时长 (30分钟)
    public long maxFileSizeBytes = 300L * 1024 * 1024;                     // 最大文件大小 (300MB)
    public bool includeAudio = true;                                        // 是否包含音频
    public OutputFormat outputFormat = OutputFormat.MP4;                    // 输出格式
}
```

## 权限管理

SDK需要以下权限：

- **麦克风权限**：用于录制音频
  - 在 `Info.plist` 中添加 `NSMicrophoneUsageDescription`

- **屏幕录制权限**：由系统自动管理
  - 首次录制时会弹出系统权限对话框

## 错误处理

SDK使用统一的错误码系统：

- **1000-1999**：权限相关错误
- **2000-2999**：录制相关错误
- **3000-3999**：文件相关错误
- **4000-4999**：系统相关错误

## 构建和部署

### 构建XCFramework

```bash
cd ios
./Scripts/build_xcframework.sh
```

### 集成到Unity

1. 构建完成后，XCFramework会自动复制到 `unity/Plugins/iOS/` 目录
2. 在Unity中导入项目
3. 设置iOS平台并构建

## 示例项目

查看 `Examples/` 目录中的示例代码，了解如何使用SDK的各种功能。

## 故障排除

### 常见问题

1. **录制失败**
   - 检查权限是否已授权
   - 确认设备支持屏幕录制
   - 检查存储空间是否足够

2. **性能问题**
   - 降低录制质量
   - 减少录制时长
   - 检查设备温度

3. **文件问题**
   - 检查输出路径是否有效
   - 确认有足够的存储空间
   - 检查文件权限

## 更新日志

### v1.0.0 (2025-10-10)
- 初始版本发布
- 支持基础屏幕录制功能
- 支持音频录制
- 支持MP4格式输出
- 支持视频清晰度档位

## 许可证

本项目采用 MIT 许可证。详情请参阅 LICENSE 文件。

## 支持

如有问题或建议，请提交 Issue 或联系开发团队。
