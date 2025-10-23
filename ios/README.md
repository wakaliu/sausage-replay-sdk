# SausageReplay iOS SDK

SausageReplay iOS SDK 是一个专为iOS平台设计的屏幕录制SDK，支持高质量屏幕录制、音频录制、多种输出格式等功能。

## 特性

- 🎥 **高质量屏幕录制**：支持1080p、720p、480p录制
- 🎵 **音频录制**：支持麦克风音频录制
- ⏸️ **暂停/恢复**：录制过程中可暂停和恢复
- 🔄 **实时质量调整**：根据设备性能动态调整录制参数
- 📱 **设备档位适配**：自动适配不同性能档位的设备
- 🎬 **多格式支持**：支持MP4、GIF格式输出
- 🛡️ **错误恢复**：内置错误检测和恢复机制

## 系统要求

- **最低版本**：iOS 12.0+
- **架构支持**：arm64 (真机), arm64 + x86_64 (模拟器)
- **开发语言**：Objective-C
- **集成平台**：Unity 2022.3 LTS 或更高版本

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
        // 初始化SDK
        bool initialized = SausageReplaySDK.Initialize(SausageReplaySDK.DevicePerformanceTier.MID_RANGE);
        if (initialized)
        {
            Debug.Log("SDK初始化成功");
        }
    }
    
    public void StartRecording()
    {
        // 创建录制配置
        var config = new SausageReplaySDK.RecordingConfig
        {
            quality = SausageReplaySDK.VideoQuality.MEDIUM,
            maxDurationSeconds = 60,
            includeAudio = true,
            outputFormat = SausageReplaySDK.OutputFormat.MP4
        };
        
        // 开始录制
        bool started = SausageReplaySDK.StartRecording(config, this);
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
bool Initialize(DevicePerformanceTier tier = DevicePerformanceTier.MID_RANGE)
```

#### 录制控制
```csharp
bool StartRecording(RecordingConfig config, IRecordingCallback callback = null)
void StopRecording()
bool PauseRecording()
bool ResumeRecording()
RecordingStatus GetRecordingStatus()
```

#### 状态查询
```csharp
bool IsPlatformSupported()
string GetVersion()
DetailedStatus GetDetailedStatus()
MemoryUsage GetMemoryUsage()
```

### 设备性能档位

- `MID_RANGE`：中端设备（默认）
  - 最大分辨率：1280x720
  - 目标帧率：30fps
  - 视频比特率：3-6 Mbps
  - 支持GIF转换

- `HIGH_END`：高端设备
  - 最大分辨率：1920x1080
  - 目标帧率：30fps
  - 视频比特率：6-10 Mbps
  - 支持GIF转换

### 录制配置

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
    public DevicePerformanceTier performanceTier = DevicePerformanceTier.MID_RANGE;
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

## 性能优化

### 内存管理
- 录制期间内存增长 < 100MB
- 自动清理临时文件
- 支持内存使用情况监控

### CPU优化
- 录制期间CPU占用 < 15%
- 根据设备性能自动调整参数
- 支持动态质量调整

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
- 支持MP4和GIF格式输出
- 支持设备性能档位适配

## 许可证

本项目采用 MIT 许可证。详情请参阅 LICENSE 文件。

## 支持

如有问题或建议，请提交 Issue 或联系开发团队。
