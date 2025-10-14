# Sausage Replay SDK - Unity 项目概览

## 项目结构

```
unity/
├── Plugins/
│   └── Android/
│       ├── SausageReplaySDK.aar          # Android SDK AAR文件
│       ├── AndroidManifest.xml           # Android权限和服务配置
│       └── res/
│           └── xml/
│               └── file_paths.xml        # FileProvider路径配置
├── Scripts/
│   ├── SausageReplaySDK.cs               # 主SDK接口类
│   ├── UnityMainThreadDispatcher.cs      # Unity主线程调度器
│   ├── SausageReplayPermissionManager.cs # Android权限管理器
│   └── Examples/
│       └── SausageReplayExample.cs       # 完整功能示例
├── Samples~/
│   ├── BasicRecording/                   # 基础录制示例
│   │   ├── SausageReplayBasicExample.cs
│   │   └── README.md
│   └── AdvancedFeatures/                 # 高级功能示例
│       ├── SausageReplayAdvancedExample.cs
│       └── README.md
├── package.json                          # Unity包管理器配置
├── README.md                             # 主要使用指南
├── INTEGRATION_GUIDE.md                  # 详细集成指南
└── UNITY_PROJECT_OVERVIEW.md             # 本文件
```

## 核心组件说明

### 1. SausageReplaySDK.cs

**功能**: 主要的SDK接口类，提供所有录制功能的C#封装

**主要特性**:
- 完整的录制控制API（开始、停止、暂停、恢复）
- 设备档位自适应支持
- 格式转换功能
- 性能监控API
- 线程安全的回调处理
- Editor模式下的模拟实现

**关键方法**:
```csharp
// 基础功能
bool Initialize(DevicePerformanceTier tier)
bool StartRecording(RecordingConfig config, IRecordingCallback callback)
void StopRecording()
bool PauseRecording()
bool ResumeRecording()

// 高级功能
DeviceTierInfo GetDeviceTierInfo()
bool IsGifConversionSupported()
void ConvertVideoFormat(string inputPath, OutputFormat format, Action<bool, string> callback)
MemoryUsage GetMemoryUsage()
```

### 2. UnityMainThreadDispatcher.cs

**功能**: Unity主线程调度器，确保Android回调在Unity主线程执行

**主要特性**:
- 单例模式设计
- 线程安全的任务队列
- 自动生命周期管理
- 异常处理机制

**使用场景**:
- Android JNI回调需要切换到Unity主线程
- 避免跨线程访问Unity API的问题
- 确保UI更新的线程安全

### 3. SausageReplayPermissionManager.cs

**功能**: Android权限管理器，处理所有权限相关操作

**主要特性**:
- 权限状态检查
- 权限请求处理
- 权限说明显示
- 设置页面跳转
- 完整的错误处理

**支持的权限**:
- RECORD_AUDIO (麦克风权限)
- WRITE_EXTERNAL_STORAGE (存储写入权限)
- READ_EXTERNAL_STORAGE (存储读取权限)
- FOREGROUND_SERVICE (前台服务权限)
- FOREGROUND_SERVICE_MEDIA_PROJECTION (媒体投影服务权限)

### 4. 示例代码

#### SausageReplayExample.cs
完整的示例实现，展示所有SDK功能的使用方法，包括：
- UI组件绑定
- 事件处理
- 状态管理
- 错误处理
- 资源清理

#### SausageReplayBasicExample.cs
基础录制示例，专注于核心录制功能：
- SDK初始化
- 权限请求
- 录制控制
- 状态显示

#### SausageReplayAdvancedExample.cs
高级功能示例，展示高级特性：
- 设备档位管理
- 质量调整
- 格式转换
- 性能监控
- 错误恢复

## 数据模型

### 核心数据结构

#### RecordingConfig
录制配置类，包含所有录制参数：
```csharp
public class RecordingConfig
{
    public VideoQuality quality;           // 视频质量
    public int maxDurationSeconds;         // 最大录制时长
    public long maxFileSizeBytes;          // 最大文件大小
    public bool includeAudio;              // 是否包含音频
    public OutputFormat outputFormat;      // 输出格式
    public string outputPath;              // 自定义输出路径
    public int? targetBitrate;             // 目标比特率
    public int targetFps;                  // 目标帧率
    public DevicePerformanceTier performanceTier; // 设备档位
}
```

#### RecordingResult
录制结果类，包含录制完成后的信息：
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

#### DeviceTierInfo
设备档位信息类：
```csharp
public class DeviceTierInfo
{
    public DevicePerformanceTier tier;     // 设备档位
    public string tierName;                // 档位名称
    public int maxWidth;                   // 最大宽度
    public int maxHeight;                  // 最大高度
    public int targetFps;                  // 目标FPS
    public long videoBitrate;              // 视频比特率
    public bool gifSupported;              // GIF支持
}
```

### 枚举类型

#### DevicePerformanceTier
设备性能档位：
- LOW_END: 低端设备
- MID_RANGE: 中端设备（默认）
- HIGH_END: 高端设备
- FLAGSHIP: 旗舰设备

#### VideoQuality
视频质量等级：
- LOW: 低质量 (480p)
- MEDIUM: 中等质量 (720p)
- HIGH: 高质量 (1080p)

#### OutputFormat
输出格式：
- MP4: MP4格式
- GIF: GIF格式
- WEBM: WebM格式
- AVI: AVI格式

#### RecordingStatus
录制状态：
- IDLE: 空闲
- RECORDING: 录制中
- PAUSED: 已暂停
- STOPPING: 停止中

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

### IPerformanceCallback
性能监控回调接口（高级功能）：
```csharp
public interface IPerformanceCallback
{
    void OnPerformanceMetrics(PerformanceMetrics metrics);       // 性能指标
    void OnBitrateReduction(double reduction);                   // 比特率降低
    void OnBitrateRecovery(double reduction);                    // 比特率恢复
    void OnResolutionDegradation(int width, int height);         // 分辨率降级
    void OnResolutionRecovery(int width, int height);            // 分辨率恢复
    void OnFpsDegradation(int fps);                              // FPS降级
    void OnFpsRecovery(int fps);                                 // FPS恢复
}
```

## 平台支持

### Unity版本
- **最低版本**: Unity 2022.3 LTS
- **推荐版本**: Unity 2022.3.57f1
- **测试版本**: Unity 2023.x

### Android版本
- **最低版本**: Android 5.1 (API 22)
- **推荐版本**: Android 8.0 (API 26) 或更高
- **目标版本**: Android 13 (API 33) 或更高

### 架构支持
- **ARM64**: 主要支持架构
- **ARMv7**: 兼容支持

## 集成流程

### 1. 准备阶段
1. 从Android项目构建AAR文件
2. 将AAR文件复制到Unity项目
3. 导入Unity插件代码

### 2. 配置阶段
1. 配置Android Player Settings
2. 设置权限和服务配置
3. 配置构建参数

### 3. 开发阶段
1. 实现录制回调接口
2. 添加权限请求逻辑
3. 集成录制控制功能
4. 添加错误处理机制

### 4. 测试阶段
1. 在真机上测试基础功能
2. 测试不同设备档位的表现
3. 验证权限处理流程
4. 测试错误恢复机制

## 最佳实践

### 1. 初始化流程
```csharp
// 推荐的初始化流程
private void InitializeSDK()
{
    // 1. 检查权限
    if (!SausageReplayPermissionManager.HasAllRequiredPermissions())
    {
        // 2. 请求权限
        SausageReplayPermissionManager.RequestAllRequiredPermissions((granted, errorCode, errorMessage) =>
        {
            if (granted)
            {
                // 3. 初始化SDK
                bool success = SausageReplaySDK.Initialize(DevicePerformanceTier.MID_RANGE);
                if (success)
                {
                    // 4. 获取设备信息
                    var tierInfo = SausageReplaySDK.GetDeviceTierInfo();
                    Debug.Log($"设备档位: {tierInfo.tier}");
                }
            }
        });
    }
    else
    {
        // 直接初始化
        SausageReplaySDK.Initialize(DevicePerformanceTier.MID_RANGE);
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
            // 权限错误
            HandlePermissionError();
            break;
        case 2003:
            // 录制启动失败
            HandleRecordingStartError();
            break;
        default:
            // 通用错误处理
            HandleGenericError(errorCode, errorMessage);
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
        var status = SausageReplaySDK.GetRecordingStatus();
        if (status == RecordingStatus.RECORDING)
        {
            SausageReplaySDK.StopRecording();
        }
    }
}
```

## 性能优化建议

### 1. 设备档位选择
- 根据目标用户群体选择合适的默认档位
- 提供档位选择选项给用户
- 动态检测设备性能并推荐档位

### 2. 录制参数优化
- 根据设备性能调整录制质量
- 设置合理的录制时长限制
- 监控内存使用情况

### 3. 用户体验优化
- 提供清晰的权限说明
- 显示录制进度和状态
- 提供错误恢复选项

## 故障排除

### 常见问题
1. **AAR文件找不到**: 检查文件路径和导入设置
2. **权限请求失败**: 检查Android Manifest配置
3. **录制启动失败**: 检查设备支持和权限状态
4. **文件无法播放**: 检查文件路径和格式支持

### 调试技巧
1. 启用详细日志输出
2. 检查权限状态
3. 监控内存使用
4. 验证设备支持情况

## 版本历史

### v1.0.0 (当前版本)
- 完整的Unity集成支持
- 基础录制功能
- 高级功能支持
- 完整的示例代码
- 详细的文档说明

## 技术支持

如需技术支持，请：
1. 查看文档和示例代码
2. 检查Unity Console日志
3. 验证设备配置
4. 联系开发团队

---

**注意**: 本SDK专为Android平台设计，在Unity Editor中运行时将显示模拟行为。实际功能需要在Android设备上测试。
