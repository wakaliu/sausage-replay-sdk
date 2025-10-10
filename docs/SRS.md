# Sausage Replay SDK - 软件需求规格文档 (SRS)

## 文档信息
- **项目名称**: Sausage Replay SDK
- **文档类型**: 软件需求规格文档 (Software Requirements Specification)
- **版本**: v1.0.0
- **创建日期**: 2025年10月10日
- **目标平台**: iOS, Android
- **集成平台**: Unity Engine

---

## 1. 引言

### 1.1 目的
本文档详细描述了Sausage Replay SDK的软件需求规格，为Unity游戏开发者提供跨平台屏幕录制功能的完整技术规范。

### 1.2 范围
本SDK为Unity引擎提供跨平台屏幕录制插件，支持iOS和Android平台，实现游戏内"高光时刻"录制功能。

### 1.3 定义和缩略语
- **SDK**: Software Development Kit (软件开发工具包)
- **API**: Application Programming Interface (应用程序编程接口)
- **SRS**: Software Requirements Specification (软件需求规格)
- **PRD**: Product Requirements Document (产品需求文档)

### 1.4 参考资料
- [PRD文档](./PRD.md) - 产品需求文档
- [SRS-Android文档](./SRS-Android.md) - Android平台详细规格
- [SRS-iOS文档](./SRS-iOS.md) - iOS平台详细规格

---

## 2. 总体描述

### 2.1 产品功能概述
Sausage Replay SDK提供以下核心功能：
- 跨平台屏幕录制（iOS/Android）
- 音频同步录制
- 多种输出格式（MP4/GIF）
- 文件压缩和大小控制
- 动态权限管理
- 性能优化

### 2.2 产品约束
- **平台限制**: 仅支持iOS和Android移动平台
- **集成限制**: 仅支持Unity引擎集成
- **录制限制**: 不支持后台录制
- **UI限制**: SDK不提供任何用户界面

### 2.3 用户特征
- **主要用户**: Unity游戏开发者
- **技术背景**: 具备Unity和C#开发经验
- **使用场景**: 游戏内集成屏幕录制功能

### 2.4 假设和依赖
- 目标设备具备足够的存储空间
- 目标设备支持屏幕录制功能
- Unity项目已正确配置目标平台

---

## 2.5 设备性能档位
- Android：`LowEnd`（低端机）、`MidRange`（中端机，默认）、`HighEnd`（高端机）、`Flagship`（旗舰机）
- iOS：`MidRange`（中端机，默认）、`HighEnd`（高端机）

SDK需依据档位自适应：
- 目标分辨率/FPS/比特率选择
- 线程池大小与编码缓冲深度
- GIF转码是否启用与采样率

---

## 3. 具体需求

### 3.1 功能需求

#### 3.1.1 初始化功能 (FR-001)
**需求描述**: SDK必须提供初始化接口，确保SDK正确加载和配置。

**输入**: 无
**处理**: 
- 检查平台支持性
- 初始化底层录制引擎
- 配置默认参数

**输出**: 
- 初始化成功/失败状态
- SDK版本信息

**验收标准**:
- 初始化时间 < 500ms
- 支持重复初始化调用
- 提供明确的错误信息

#### 3.1.2 权限管理功能 (FR-002)
**需求描述**: SDK必须提供完整的权限管理功能，包括权限检查和申请。

**输入**: 权限类型（录制权限/麦克风权限）
**处理**:
- 检查当前权限状态
- 申请所需权限
- 处理权限申请结果

**输出**:
- 权限状态信息
- 错误码和错误信息

**验收标准**:
- 支持权限状态实时查询
- 提供详细的错误码
- 不显示任何系统弹窗

#### 3.1.3 录制控制功能 (FR-003)
**需求描述**: SDK必须提供完整的录制控制功能，包括开始、停止、暂停、恢复录制。

**输入**: 录制配置参数
**处理**:
- 验证录制参数
- 启动录制引擎
- 管理录制状态

**输出**:
- 录制状态信息
- 录制文件路径

**验收标准**:
- 支持录制状态实时查询
- 提供录制进度回调
- 支持录制中断恢复

#### 3.1.4 文件管理功能 (FR-004)
**需求描述**: SDK必须提供文件生成、压缩和格式转换功能。

**输入**: 录制数据、压缩参数
**处理**:
- 生成MP4/GIF文件
- 应用压缩算法
- 管理临时文件

**输出**:
- 最终录制文件
- 文件大小信息

**验收标准**:
- 支持多种压缩级别
- 自动清理临时文件
- 提供文件大小控制

### 3.2 性能需求

#### 3.2.1 响应时间需求 (NFR-001)
- **初始化时间**: < 500ms
- **录制启动时间**: < 200ms
- **录制停止时间**: < 1000ms
- **文件生成时间**: < 5000ms

#### 3.2.2 资源使用需求 (NFR-002)
- **CPU占用率**: 录制期间 < 15%
- **内存增长**: 录制期间 < 100MB
- **存储空间**: 临时文件 < 200MB
- **电池消耗**: 最小化影响

#### 3.2.3 并发需求 (NFR-003)
- **单次录制**: 同时只能进行一次录制
- **多线程安全**: 支持多线程调用
- **状态同步**: 确保状态一致性

### 3.3 接口需求

#### 3.3.1 用户接口需求
- **无UI要求**: SDK不提供任何用户界面
- **回调接口**: 提供异步回调机制
- **错误处理**: 提供详细的错误信息

#### 3.3.2 硬件接口需求
- **屏幕接口**: 访问设备屏幕内容
- **音频接口**: 访问麦克风音频
- **存储接口**: 读写设备存储

#### 3.3.3 软件接口需求
- **Unity接口**: 通过C# API集成
- **系统接口**: 调用平台原生API
- **文件接口**: 支持文件系统操作

---

## 4. 系统架构

### 4.1 整体架构
```
┌─────────────────────────────────────┐
│           Unity C# Layer            │
│     (统一API接口和业务逻辑)          │
└─────────────────┬───────────────────┘
                  │
┌─────────────────┴───────────────────┐
│        Native Plugin Layer         │
│    (平台适配和原生API封装)           │
└─────────────────┬───────────────────┘
                  │
┌─────────────────┴───────────────────┐
│      Platform Native APIs          │
│  (iOS: ReplayKit, Android: MediaProjection) │
└─────────────────────────────────────┘
```

### 4.2 模块设计

#### 4.2.1 核心模块
- **SDKManager**: SDK初始化和生命周期管理
- **PermissionManager**: 权限管理模块
- **RecordingManager**: 录制控制模块
- **FileManager**: 文件管理模块
- **ConfigManager**: 配置管理模块

#### 4.2.2 平台适配模块
- **iOSAdapter**: iOS平台适配层
- **AndroidAdapter**: Android平台适配层
- **PlatformUtils**: 平台工具类

### 4.3 数据流设计
```
录制请求 → 权限检查 → 参数验证 → 启动录制 → 数据采集 → 文件生成 → 回调通知
```

---

## 5. API规范

### 5.1 核心API接口

#### 5.1.1 SDK管理接口（更新）
```csharp
public enum DevicePerformanceTier
{
    // Android: LowEnd, MidRange, HighEnd, Flagship；iOS: MidRange, HighEnd
    LowEnd,
    MidRange, // default
    HighEnd,
    Flagship
}

public class SausageReplaySDK
{
    /// <summary>
    /// 初始化SDK（非阻塞，内部在后台线程完成初始化工作）。
    /// </summary>
    /// <param name="tier">设备性能档位（不同平台可用档位见文档）</param>
    /// <returns>是否接受初始化请求（同步返回）。完成状态通过日志或后续调用确认。</returns>
    public static bool Initialize(DevicePerformanceTier tier = DevicePerformanceTier.MidRange);
    
    /// <summary>
    /// 检查平台支持性
    /// </summary>
    /// <returns>是否支持当前平台</returns>
    public static bool IsPlatformSupported();
    
    /// <summary>
    /// 获取SDK版本
    /// </summary>
    /// <returns>SDK版本字符串</returns>
    public static string GetVersion();
    
    /// <summary>
    /// 释放SDK资源
    /// </summary>
    public static void Release();
}
```

#### 5.1.2 权限管理接口
```csharp
public class PermissionManager
{
    /// <summary>
    /// 检查录制权限
    /// </summary>
    /// <returns>是否有录制权限</returns>
    public static bool HasRecordingPermission();
    
    /// <summary>
    /// 请求录制权限
    /// </summary>
    /// <param name="callback">权限申请结果回调</param>
    public static void RequestRecordingPermission(Action<PermissionResult> callback);
    
    /// <summary>
    /// 检查麦克风权限
    /// </summary>
    /// <returns>是否有麦克风权限</returns>
    public static bool HasMicrophonePermission();
    
    /// <summary>
    /// 请求麦克风权限
    /// </summary>
    /// <param name="callback">权限申请结果回调</param>
    public static void RequestMicrophonePermission(Action<PermissionResult> callback);
}
```

#### 5.1.3 录制控制接口
```csharp
public class RecordingManager
{
    /// <summary>
    /// 开始录制
    /// </summary>
    /// <param name="config">录制配置</param>
    /// <returns>是否成功开始录制</returns>
    public static bool StartRecording(RecordingConfig config);
    
    /// <summary>
    /// 停止录制
    /// </summary>
    /// <param name="callback">录制完成回调</param>
    public static void StopRecording(Action<RecordingResult> callback);
    
    /// <summary>
    /// 暂停录制
    /// </summary>
    public static void PauseRecording();
    
    /// <summary>
    /// 恢复录制
    /// </summary>
    public static void ResumeRecording();
    
    /// <summary>
    /// 获取录制状态
    /// </summary>
    /// <returns>当前录制状态</returns>
    public static RecordingStatus GetRecordingStatus();
}
```

### 5.2 数据模型

#### 5.2.1 配置模型
```csharp
public class RecordingConfig
{
    /// <summary>
    /// 视频质量
    /// </summary>
    public VideoQuality Quality { get; set; } = VideoQuality.Medium;
    
    /// <summary>
    /// 最大录制时长（秒）
    /// </summary>
    public int MaxDurationSeconds { get; set; } = 60;
    
    /// <summary>
    /// 最大文件大小（字节）
    /// </summary>
    public long MaxFileSizeBytes { get; set; } = 50 * 1024 * 1024; // 50MB
    
    /// <summary>
    /// 是否包含音频
    /// </summary>
    public bool IncludeAudio { get; set; } = true;
    
    /// <summary>
    /// 输出文件路径
    /// </summary>
    public string OutputPath { get; set; }
    
    /// <summary>
    /// 输出格式
    /// </summary>
    public OutputFormat Format { get; set; } = OutputFormat.MP4;
}

public enum VideoQuality
{
    Low,    // 480p
    Medium, // 720p
    High    // 1080p
}

public enum OutputFormat
{
    MP4,
    GIF
}
```

#### 5.2.2 结果模型
```csharp
public class PermissionResult
{
    /// <summary>
    /// 权限是否授予
    /// </summary>
    public bool IsGranted { get; set; }
    
    /// <summary>
    /// 错误码
    /// </summary>
    public int ErrorCode { get; set; }
    
    /// <summary>
    /// 错误信息
    /// </summary>
    public string ErrorMessage { get; set; }
}

public class RecordingResult
{
    /// <summary>
    /// 录制是否成功
    /// </summary>
    public bool IsSuccess { get; set; }
    
    /// <summary>
    /// 输出文件路径
    /// </summary>
    public string FilePath { get; set; }
    
    /// <summary>
    /// 文件大小（字节）
    /// </summary>
    public long FileSize { get; set; }
    
    /// <summary>
    /// 录制时长（秒）
    /// </summary>
    public float Duration { get; set; }
    
    /// <summary>
    /// 错误码
    /// </summary>
    public int ErrorCode { get; set; }
    
    /// <summary>
    /// 错误信息
    /// </summary>
    public string ErrorMessage { get; set; }
}

public enum RecordingStatus
{
    Idle,       // 空闲
    Recording,  // 录制中
    Paused,     // 已暂停
    Stopping    // 停止中
}
```

### 5.3 错误码定义
```csharp
public enum ErrorCode
{
    // 成功
    Success = 0,
    
    // 权限相关错误 (1000-1999)
    PermissionDenied = 1001,
    PermissionPermanentlyDenied = 1002,
    PermissionNotRequested = 1003,
    
    // 录制相关错误 (2000-2999)
    RecordingNotStarted = 2001,
    RecordingAlreadyStarted = 2002,
    RecordingConfigInvalid = 2003,
    RecordingFailed = 2004,
    
    // 文件相关错误 (3000-3999)
    FileCreationFailed = 3001,
    FileSizeExceeded = 3002,
    FileFormatNotSupported = 3003,
    
    // 系统相关错误 (4000-4999)
    SystemError = 4001,
    InsufficientStorage = 4002,
    UnsupportedPlatform = 4003,
    SDKNotInitialized = 4004
}
```

---

## 6. 质量属性

### 6.1 可靠性
- **错误处理**: 提供完整的错误处理机制
- **异常恢复**: 支持录制异常后的恢复
- **资源清理**: 确保资源正确释放

### 6.2 可用性
- **API简洁性**: 提供简单易用的API接口
- **文档完整性**: 提供完整的开发文档
- **示例代码**: 提供完整的示例代码

### 6.3 性能
- **响应时间**: 满足性能需求指标
- **资源使用**: 最小化系统资源占用
- **电池优化**: 优化电池消耗

### 6.4 可维护性
- **代码结构**: 清晰的代码结构
- **日志记录**: 完整的日志记录
- **版本管理**: 支持版本升级

---

## 7. 约束条件

### 7.1 技术约束
- **平台限制**: 仅支持iOS 12.0+和Android 5.1+
- **Unity版本**: 支持Unity 2019.4 LTS+
- **内存限制**: 考虑移动设备内存限制

### 7.2 业务约束
- **无UI要求**: SDK不提供任何用户界面
- **权限处理**: 由项目方处理权限相关UI
- **文件管理**: 由项目方管理录制文件

### 7.3 法律约束
- **隐私保护**: 遵守数据隐私保护法规
- **平台政策**: 遵守App Store和Google Play政策
- **开源协议**: 选择合适的开源协议

---

## 8. 验收标准

### 8.1 功能验收
- [ ] 所有API接口正常工作
- [ ] 权限管理功能完整
- [ ] 录制功能稳定可靠
- [ ] 文件生成正确
- [ ] 错误处理完善

### 8.2 性能验收
- [ ] 满足所有性能指标
- [ ] 内存使用合理
- [ ] CPU占用率符合要求
- [ ] 电池消耗最小化

### 8.3 兼容性验收
- [ ] 支持目标平台版本
- [ ] 适配主流设备
- [ ] Unity集成正常
- [ ] 跨平台一致性

---

## 9. 附录

### 9.1 相关文档
- [PRD文档](./PRD.md) - 产品需求文档
- [SRS-Android文档](./SRS-Android.md) - Android平台详细规格
- [SRS-iOS文档](./SRS-iOS.md) - iOS平台详细规格

### 9.2 变更记录
| 版本 | 日期 | 变更内容 | 作者 |
|------|------|----------|------|
| 1.0.0 | 2025-10-10 | 初始版本创建 | Waka |

---

*本文档将根据开发进度持续更新和完善*
