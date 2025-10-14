# Unity 集成详细指南

## 概述

本指南详细说明如何将Sausage Replay SDK集成到Unity项目中，包括完整的配置步骤、常见问题解决方案和最佳实践。

## 集成步骤

### 1. 准备AAR文件

首先需要从Android项目构建AAR文件：

```bash
# 在android目录下执行
cd android
./gradlew :replay-sdk:assembleRelease

# AAR文件位置
# android/replay-sdk/build/outputs/aar/replay-sdk-release.aar
```

将生成的AAR文件复制到Unity项目的 `Assets/Plugins/Android/` 目录，并重命名为 `SausageReplaySDK.aar`。

### 2. 导入Unity插件

1. 将整个 `unity` 文件夹复制到Unity项目的 `Assets` 目录
2. 在Unity中刷新资源（Ctrl+R 或 Cmd+R）
3. 确认所有脚本文件正确导入

### 3. 配置Android设置

#### 3.1 Player Settings

1. 打开 **File > Build Settings**
2. 选择 **Android** 平台
3. 点击 **Switch Platform**
4. 点击 **Player Settings**，配置以下设置：

**Other Settings:**
- **Minimum API Level**: 22 (Android 5.1)
- **Target API Level**: 33 或更高
- **Scripting Backend**: IL2CPP
- **Target Architectures**: ARM64
- **Internet Access**: Require

**XR Settings:**
- 根据项目需求配置

#### 3.2 Android Manifest

插件已包含必要的Android Manifest配置，但您可能需要根据项目需求进行调整。

**权限配置:**
```xml
<uses-permission android:name="android.permission.RECORD_AUDIO" />
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" />
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_MEDIA_PROJECTION" />
```

**服务配置:**
```xml
<service
    android:name="com.funny.replaysdk.RecordingFgService"
    android:enabled="true"
    android:exported="false"
    android:foregroundServiceType="mediaProjection" />
```

### 4. 代码集成

#### 4.1 基本集成

```csharp
using SausageReplay;

public class RecordingManager : MonoBehaviour, IRecordingCallback
{
    private void Start()
    {
        // 请求权限并初始化SDK
        SausageReplayPermissionManager.RequestAllRequiredPermissions((granted, errorCode, errorMessage) =>
        {
            if (granted)
            {
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
        var config = new RecordingConfig
        {
            quality = VideoQuality.HIGH,
            maxDurationSeconds = 60,
            includeAudio = true
        };

        SausageReplaySDK.StartRecording(config, this);
    }

    // 实现回调接口
    public void OnRecordingStarted() { }
    public void OnRecordingStopped(RecordingResult result) { }
    // ... 其他回调方法
}
```

#### 4.2 高级功能集成

```csharp
// 设备档位检测
var tierInfo = SausageReplaySDK.GetDeviceTierInfo();
Debug.Log($"设备档位: {tierInfo.tier}");

// 格式转换
SausageReplaySDK.ConvertVideoFormat(inputPath, OutputFormat.GIF, (success, outputPath) =>
{
    if (success)
    {
        Debug.Log($"转换成功: {outputPath}");
    }
});

// 性能监控
var memoryUsage = SausageReplaySDK.GetMemoryUsage();
Debug.Log($"内存使用: {memoryUsage.usagePercentage}%");
```

## 配置选项

### 录制配置

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
    public DevicePerformanceTier performanceTier = DevicePerformanceTier.MID_RANGE; // 设备档位
}
```

### 设备档位选择

根据目标设备选择合适的档位：

- **LOW_END**: 低端设备，适合性能较差的设备
- **MID_RANGE**: 中端设备，默认选择，适合大多数设备
- **HIGH_END**: 高端设备，适合性能较好的设备
- **FLAGSHIP**: 旗舰设备，适合最新旗舰设备

## 最佳实践

### 1. 权限管理

```csharp
// 在应用启动时检查权限
private void CheckPermissions()
{
    if (!SausageReplayPermissionManager.HasAllRequiredPermissions())
    {
        // 显示权限说明
        ShowPermissionRationale();
        
        // 请求权限
        SausageReplayPermissionManager.RequestAllRequiredPermissions((granted, errorCode, errorMessage) =>
        {
            if (!granted)
            {
                // 引导用户到设置页面
                SausageReplayPermissionManager.OpenAppSettings();
            }
        });
    }
}
```

### 2. 错误处理

```csharp
public void OnRecordingError(int errorCode, string errorMessage)
{
    switch (errorCode)
    {
        case 1001:
            // 麦克风权限被拒绝
            ShowPermissionError("需要麦克风权限才能录制音频");
            break;
        case 2003:
            // 录制启动失败
            ShowError("录制启动失败，请重试");
            break;
        default:
            // 其他错误
            ShowError($"录制错误: {errorMessage}");
            break;
    }
}
```

### 3. 资源管理

```csharp
private void OnDestroy()
{
    // 确保释放SDK资源
    if (SausageReplaySDK.IsInitialized())
    {
        SausageReplaySDK.Release();
    }
}

private void OnApplicationPause(bool pauseStatus)
{
    if (pauseStatus)
    {
        // 应用暂停时停止录制
        if (SausageReplaySDK.GetRecordingStatus() == RecordingStatus.RECORDING)
        {
            SausageReplaySDK.StopRecording();
        }
    }
}
```

### 4. 性能优化

```csharp
// 根据设备性能选择合适的配置
private RecordingConfig CreateOptimalConfig()
{
    var tierInfo = SausageReplaySDK.GetDeviceTierInfo();
    
    var config = new RecordingConfig
    {
        performanceTier = tierInfo.tier
    };
    
    // 根据设备档位调整参数
    switch (tierInfo.tier)
    {
        case DevicePerformanceTier.LOW_END:
            config.quality = VideoQuality.LOW;
            config.maxDurationSeconds = 30;
            break;
        case DevicePerformanceTier.MID_RANGE:
            config.quality = VideoQuality.MEDIUM;
            config.maxDurationSeconds = 60;
            break;
        case DevicePerformanceTier.HIGH_END:
        case DevicePerformanceTier.FLAGSHIP:
            config.quality = VideoQuality.HIGH;
            config.maxDurationSeconds = 120;
            break;
    }
    
    return config;
}
```

## 常见问题

### Q: 构建时出现"找不到AAR文件"错误

A: 确保AAR文件位于正确的路径：`Assets/Plugins/Android/SausageReplaySDK.aar`

### Q: 运行时出现"SDK未初始化"错误

A: 确保在调用录制功能前先调用 `SausageReplaySDK.Initialize()`

### Q: 权限请求失败

A: 检查Android Manifest中的权限配置，确保所有必需权限都已声明

### Q: 录制文件无法播放

A: 检查文件路径和权限，确保应用有写入外部存储的权限

### Q: 录制过程中应用崩溃

A: 检查内存使用情况，考虑降低录制质量或减少录制时长

## 调试技巧

### 1. 日志查看

```csharp
// 启用详细日志
Debug.Log($"SDK版本: {SausageReplaySDK.GetVersion()}");
Debug.Log($"平台支持: {SausageReplaySDK.IsPlatformSupported()}");

// 查看详细状态
var status = SausageReplaySDK.GetDetailedStatus();
Debug.Log($"详细状态: {JsonUtility.ToJson(status, true)}");
```

### 2. 权限检查

```csharp
// 检查权限状态
Debug.Log($"麦克风权限: {SausageReplayPermissionManager.HasMicrophonePermission()}");
Debug.Log($"存储权限: {SausageReplayPermissionManager.HasStoragePermission()}");
Debug.Log($"权限状态: {SausageReplayPermissionManager.GetPermissionStatusDescription()}");
```

### 3. 性能监控

```csharp
// 定期检查内存使用
private void Update()
{
    if (Time.frameCount % 300 == 0) // 每5秒检查一次
    {
        var memoryUsage = SausageReplaySDK.GetMemoryUsage();
        if (memoryUsage.usagePercentage > 80)
        {
            Debug.LogWarning($"内存使用过高: {memoryUsage.usagePercentage}%");
        }
    }
}
```

## 版本兼容性

### Unity版本支持

- **最低版本**: Unity 2022.3 LTS
- **推荐版本**: Unity 2022.3.57f1 或更高
- **测试版本**: Unity 2023.x

### Android版本支持

- **最低版本**: Android 5.1 (API 22)
- **推荐版本**: Android 8.0 (API 26) 或更高
- **目标版本**: Android 13 (API 33) 或更高

### 架构支持

- **ARM64**: 主要支持架构
- **ARMv7**: 兼容支持（性能可能受限）

## 更新日志

### v1.0.0
- 初始版本发布
- 基础录制功能
- 暂停/恢复支持
- 设备档位自适应
- 格式转换支持
- 完整的Unity集成

## 技术支持

如果您在集成过程中遇到问题，请：

1. 查看Unity Console中的错误日志
2. 检查Android设备的权限设置
3. 确认设备支持屏幕录制功能
4. 参考示例代码进行对比
5. 联系技术支持团队

## 许可证

本SDK遵循MIT许可证，详情请查看LICENSE文件。
