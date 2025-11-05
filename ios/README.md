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

通过 Unity Package Manager 导入 SDK 后，以下文件会自动包含：
- `Package/Runtime/Plugins/iOS/SausageReplay.xcframework` - iOS SDK 框架
- `Package/Runtime/SausageReplaySDK.cs` - Unity C# 桥接脚本

**注意**：如果手动集成，请确保：
1. 将 `SausageReplay.xcframework` 复制到 Unity 项目的 `Assets/Plugins/iOS/` 目录
2. 确保 `SausageReplaySDK.cs` 脚本在项目中（位于 `Package/Runtime/` 目录）
3. 在Unity中设置iOS平台并构建

### 2. 基本使用

```csharp
using SausageReplay;

public class ReplayController : MonoBehaviour, SausageReplaySDK.IRecordingCallback
{
    void Start()
    {
        // 初始化SDK，使用Standard档位，启用调试日志
        bool initialized = SausageReplaySDK.Initialize(
            SausageReplaySDK.VideoQualityPreset.Standard, 
            enableDebugLog: true);
        if (initialized)
        {
            Debug.Log("SDK初始化成功");
        }
    }
    
    public void StartRecording()
    {
        // 开始录制（传入回调接口）
        bool started = SausageReplaySDK.StartRecording(this);
        if (started)
        {
            Debug.Log("录制开始");
        }
    }
    
    public void StopRecording()
    {
        SausageReplaySDK.StopRecording();
    }
    
    // 实现 IRecordingCallback 接口
    public void OnRecordingStarted()
    {
        Debug.Log("录制开始");
    }
    
    public void OnRecordingProgress(long durationMs, long fileSizeBytes)
    {
        Debug.Log($"录制进度: {durationMs}ms, {fileSizeBytes} bytes");
    }
    
    public void OnRecordingStopped(SausageReplaySDK.RecordingResult result)
    {
        if (result.isSuccess)
        {
            Debug.Log($"录制成功: {result.filePath}, 时长: {result.duration}s, 大小: {result.fileSize} bytes");
#if UNITY_IOS && !UNITY_EDITOR
            if (!string.IsNullOrEmpty(result.assetLocalId))
            {
                Debug.Log($"iOS相册资源ID: {result.assetLocalId}");
            }
#endif
        }
        else
        {
            Debug.LogError($"录制失败: {result.errorCode} - {result.errorMessage}");
        }
    }
    
    public void OnRecordingError(int errorCode, string errorMessage)
    {
        Debug.LogError($"录制错误: {errorCode} - {errorMessage}");
    }
}
```

## API参考

### 核心API

#### 初始化
```csharp
bool Initialize(VideoQualityPreset preset = VideoQualityPreset.Standard, bool enableDebugLog = true)
```

**参数说明**：
- `preset`：视频清晰度档位，默认为 `Standard`
- `enableDebugLog`：是否启用调试日志，默认为 `true`

**使用示例**：
```csharp
// 使用默认参数（Standard档位，启用调试日志）
bool ok = SausageReplaySDK.Initialize();

// 指定档位，使用默认调试日志设置
bool ok = SausageReplaySDK.Initialize(SausageReplaySDK.VideoQualityPreset.HighFPS);

// 指定档位和调试日志设置
bool ok = SausageReplaySDK.Initialize(
    SausageReplaySDK.VideoQualityPreset.Standard, 
    enableDebugLog: true);
```

#### 录制控制
```csharp
bool StartRecording(IRecordingCallback callback = null)
void StopRecording()
RecordingStatus GetRecordingStatus()
```

#### 状态查询
```csharp
bool IsPlatformSupported()
string GetVersion()
DetailedStatus GetDetailedStatus()
```

#### 资源释放
```csharp
void Release()
```

**注意**：iOS SDK 不支持录制过程中动态调整质量。`AdjustRecordingQuality` 方法在原生 SDK 中存在，但未在 Unity C# API 中暴露。如需调整质量，请在开始录制前通过 `Initialize` 方法设置不同的 `VideoQualityPreset`。

### 视频清晰度档位

- `Basic` (0)：720p30
- `Standard` (1)：1080p30 (默认)
- `Smooth` (2)：720p60
- `HighFPS` (3)：1080p60
- `Ultra` (4)：1440p60

**注意**：档位名称使用 `HighFPS`（注意大小写），不是 `HighFps`。

### 录制结果

```csharp
[Serializable]
public class RecordingResult
{
    public bool isSuccess;              // 是否成功
    public string filePath;             // 文件名（iOS）或相对路径（Android）
    public long fileSize;               // 文件大小（字节）
    public float duration;              // 录制时长（秒）
    public string fileMd5;              // 文件MD5哈希（用于完整性验证）
#if UNITY_IOS && !UNITY_EDITOR
    public string assetLocalId;         // iOS相册资源ID（PHAsset.localIdentifier）
#endif
    public int errorCode;               // 错误码
    public string errorMessage;         // 错误信息
}
```

**注意**：iOS SDK 通过 Unity Package 集成，不直接暴露配置类。录制参数通过初始化时的 `VideoQualityPreset` 设置，iOS 会自动使用 ReplayKit 的默认配置。

## 权限管理

SDK需要以下权限：

- **麦克风权限**：用于录制音频
  - 在 `Info.plist` 中添加 `NSMicrophoneUsageDescription`

- **屏幕录制权限**：由系统自动管理
  - 首次录制时会弹出系统权限对话框

## 错误处理

SDK使用统一的错误码系统，所有错误码定义在 `SRErrorCodes.h` 中。

### 错误码列表

#### 成功
- **0** (`SRErrorOK`)：成功

#### 权限相关错误 (1000-1999)
- **1202** (`SRErrorPhotoPermissionDenied`)：相册权限被拒绝
  - 用户拒绝了访问相册的权限
  - 解决方法：引导用户前往设置中开启相册权限

- **1203** (`SRErrorSaveToPhotosFailed`)：保存到相册失败
  - 保存视频到系统相册时发生错误
  - 解决方法：检查存储空间是否充足，权限是否已授予

#### 录制相关错误 (2000-2999)
- **2000** (`SRErrorRecordingAlreadyInProgress`)：录制已在进行中
  - 尝试开始录制时，已有录制正在进行
  - 解决方法：先停止当前录制，或等待当前录制完成

- **2001** (`SRErrorRecordingNotStarted`)：录制未开始
  - 尝试停止录制时，录制尚未开始
  - 解决方法：确保在开始录制后再调用停止方法

- **2002** (`SRErrorUserDenied`)：用户拒绝屏幕录制权限
  - 用户拒绝了屏幕录制权限
  - 解决方法：引导用户前往设置中开启屏幕录制权限

- **2003** (`SRErrorCreateProjectionFailed`)：创建录制会话失败
  - 无法创建屏幕录制会话
  - 解决方法：检查设备是否支持屏幕录制（iOS 12+），是否在模拟器上运行

- **2004** (`SRErrorStartFailed`)：启动录制失败
  - 开始录制时发生错误
  - 解决方法：检查权限状态、设备状态和存储空间

- **2005** (`SRErrorStartTimeout`)：录制启动超时
  - 录制启动操作超时
  - 解决方法：重试启动录制，检查设备性能

- **2006** (`SRErrorWriterNotStarted`)：写入器未启动或未捕获帧
  - 视频写入器未正确启动，或未捕获到任何视频帧
  - 解决方法：检查录制状态，确保正确初始化

- **2011** (`SRErrorDurationTooShort`)：录制时长过短（<1秒）
  - 录制的视频时长小于1秒，被视为无效
  - 解决方法：确保录制时长至少1秒以上

#### 文件相关错误 (3000-3999)
- **3004** (`SRErrorFormatNotSupported`)：格式不支持
  - 请求的输出格式不被支持
  - 解决方法：使用支持的格式（当前支持 MP4）

### 错误码使用示例

```csharp
public void OnRecordingError(int errorCode, string errorMessage)
{
    switch (errorCode)
    {
        case 2000:
            Debug.LogError("录制已在进行中，请先停止当前录制");
            break;
        case 2002:
            Debug.LogError("用户拒绝了屏幕录制权限，请前往设置开启");
            break;
        case 2003:
            Debug.LogError("创建录制会话失败，请检查设备支持情况");
            break;
        case 2011:
            Debug.LogError("录制时长过短，请确保录制至少1秒");
            break;
        default:
            Debug.LogError($"录制错误: {errorCode} - {errorMessage}");
            break;
    }
}
```

### 错误处理建议

1. **权限错误（1202, 2002）**：引导用户前往系统设置开启相应权限
2. **录制状态错误（2000, 2001）**：确保在正确的状态下调用相应方法
3. **设备支持错误（2003）**：检查设备是否支持屏幕录制功能
4. **时长错误（2011）**：确保录制时长满足最小要求

## 构建和部署

### 构建XCFramework

```bash
cd ios
./Scripts/build_xcframework.sh
```

### 集成到Unity

1. 构建完成后，XCFramework会自动复制到 `Package/Runtime/Plugins/iOS/` 目录
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
