# Sausage Replay SDK - 产品需求文档 (PRD)

## 文档信息
- **项目名称**: Sausage Replay SDK
- **版本**: v1.0.0
- **创建日期**: 2025年10月10日
- **文档类型**: 产品需求文档
- **目标平台**: iOS, Android
- **集成平台**: Unity Engine

---

## 1. 项目概述

### 1.1 项目背景
为Unity引擎设计的跨平台屏幕录制插件，支持在iOS和Android移动设备上录制屏幕并生成MP4视频或GIF。主要用于帮助玩家在游戏中录制"高光时刻"并分享至社交媒体，以提升用户参与感和游戏曝光率。

### 1.2 项目目标
- 提供统一的C# API接口，简化双平台集成
- 支持录制包含游戏UI在内的完整屏幕画面
- 同步捕获麦克风音频
- 提供灵活的压缩选项控制文件大小
- 确保录制过程对游戏性能影响最小化

### 1.3 目标用户
- **直接用户**: Unity游戏开发者
- **最终用户**: 移动游戏玩家

---

## 2. 产品需求

### 2.1 核心功能需求

#### 2.1.1 屏幕录制功能
- **录制范围**: 完整屏幕画面（包含游戏UI）
- **录制格式**: MP4视频、GIF动图
- **音频支持**: 同步录制麦克风音频
- **录制时长**: 最长60秒（可配置）
- **录制质量**: 支持多种质量选项（高清、标清、低清）

#### 2.1.2 文件管理功能
- **文件压缩**: 提供多种压缩选项
- **文件大小控制**: 支持设置最大文件大小限制
- **存储管理**: 自动管理临时文件和缓存
- **文件格式转换**: 支持MP4与GIF格式互转

#### 2.1.3 权限管理功能
- **动态权限申请**: 运行时申请录制权限
- **权限状态检查**: 提供权限状态查询API
- **错误码回调**: 权限申请失败时通过回调返回具体错误码，由项目方处理
- **无界面干预**: SDK不提供任何界面弹窗，所有权限相关UI由项目方自行处理

### 2.2 性能需求

#### 2.2.1 性能指标
- **CPU占用**: 录制期间CPU占用率 < 15%
- **内存占用**: 录制期间内存增长 < 100MB
- **帧率影响**: 对游戏帧率影响 < 5%
- **启动时间**: SDK初始化时间 < 500ms

#### 2.2.2 资源管理
- **内存回收**: 及时释放录制相关资源
- **电池优化**: 最小化电池消耗
- **存储优化**: 合理使用设备存储空间

### 2.3 兼容性需求

#### 2.3.1 平台支持
- **iOS**: 支持iOS 12.0及以上版本
- **Android**: 支持Android 5.1 (API Level 22)及以上版本
- **Unity**: 支持Unity 2019.4 LTS及以上版本

#### 2.3.2 设备支持
- **屏幕分辨率**: 支持各种主流分辨率
- **设备性能**: 适配中低端设备
- **存储空间**: 支持不同存储容量的设备

---

## 2.4 主线程非阻塞要求（新增）
- SDK所有耗时操作（初始化、权限、录制启停、文件生成/压缩/转码）不得阻塞主线程。
- 回调在主线程派发，但计算/IO在后台线程执行。
- FPS影响目标：录制期间对游戏帧率影响<5%；低端机需通过降级策略将抖动控制在可感知阈值以下。

## 2.5 设备性能档位（新增）
- Android：低端机/中端机（默认）/高端机/旗舰机 四档。
- iOS：中端机（默认）/高端机 两档。
- 初始化接口需接受设备档位参数，SDK按档位自适应分辨率、FPS、比特率、缓冲深度及GIF策略。

---

## 3. 技术架构

### 3.1 整体架构
```
Unity C# Layer (统一API接口)
    ↓
Native Plugin Layer (平台特定实现)
    ↓
Platform Native APIs (iOS/Android原生API)
```

### 3.2 模块设计

#### 3.2.1 核心模块
- **录制引擎**: 负责屏幕录制核心逻辑
- **音频处理**: 处理麦克风音频捕获
- **文件管理**: 处理文件生成、压缩、存储
- **权限管理**: 处理系统权限申请和状态管理
- **性能监控**: 监控录制过程中的性能指标

#### 3.2.2 平台适配层
- **iOS适配层**: 基于ReplayKit和AVFoundation
- **Android适配层**: 基于MediaProjection和MediaRecorder

---

## 4. API设计

### 4.1 核心API接口

#### 4.1.1 初始化接口（更新）
```csharp
public enum DevicePerformanceTier
{
    LowEnd,
    MidRange, // default
    HighEnd,
    Flagship
}

public class SausageReplaySDK
{
    // 初始化SDK（非阻塞），依据设备档位进行参数自适应
    public static bool Initialize(DevicePerformanceTier tier = DevicePerformanceTier.MidRange);
    
    // 检查平台支持
    public static bool IsPlatformSupported();
    
    // 获取SDK版本
    public static string GetVersion();
}
```

#### 4.1.2 权限管理接口
```csharp
public class PermissionManager
{
    // 检查录制权限
    public static bool HasRecordingPermission();
    
    // 请求录制权限
    public static void RequestRecordingPermission(Action<PermissionResult> callback);
    
    // 检查麦克风权限
    public static bool HasMicrophonePermission();
    
    // 请求麦克风权限
    public static void RequestMicrophonePermission(Action<PermissionResult> callback);
}

public class PermissionResult
{
    public bool IsGranted { get; set; }
    public int ErrorCode { get; set; }
    public string ErrorMessage { get; set; }
}

public enum PermissionErrorCode
{
    Success = 0,
    PermissionDenied = 1001,
    PermissionPermanentlyDenied = 1002,
    SystemError = 1003,
    UnsupportedPlatform = 1004
}
```

#### 4.1.3 录制控制接口
```csharp
public class RecordingManager
{
    // 开始录制
    public static bool StartRecording(RecordingConfig config);
    
    // 停止录制
    public static void StopRecording(Action<string> onComplete);
    
    // 暂停录制
    public static void PauseRecording();
    
    // 恢复录制
    public static void ResumeRecording();
    
    // 获取录制状态
    public static RecordingStatus GetRecordingStatus();
}
```

#### 4.1.4 配置管理接口
```csharp
public class RecordingConfig
{
    public VideoQuality Quality { get; set; }
    public int MaxDurationSeconds { get; set; }
    public long MaxFileSizeBytes { get; set; }
    public bool IncludeAudio { get; set; }
    public string OutputPath { get; set; }
}

public enum VideoQuality
{
    Low,    // 480p
    Medium, // 720p
    High    // 1080p
}
```

---

## 5. 平台特定需求

### 5.1 iOS平台

#### 5.1.1 技术实现
- **录制技术**: 基于ReplayKit框架
- **音频处理**: 使用AVAudioEngine
- **文件格式**: 支持MP4和GIF输出
- **权限处理**: 使用AVCaptureDevice权限

#### 5.1.2 特殊考虑
- **App Store审核**: 确保符合App Store审核指南
- **后台录制**: 不支持后台录制
- **系统限制**: 遵循iOS系统录制限制

### 5.2 Android平台

#### 5.1.1 技术实现
- **录制技术**: 基于MediaProjection API
- **音频处理**: 使用MediaRecorder
- **文件格式**: 支持MP4和GIF输出
- **权限处理**: 使用运行时权限系统

#### 5.2.2 特殊考虑
- **系统版本兼容**: 处理不同Android版本的API差异
- **厂商定制**: 适配不同厂商的系统定制
- **权限管理**: 处理Android 6.0+的运行时权限

---

## 6. 开发计划

### 6.1 开发阶段
1. **需求分析阶段** (1周)
   - 详细需求分析
   - 技术方案设计
   - API接口设计

2. **核心开发阶段** (4周)
   - iOS平台开发 (2周)
   - Android平台开发 (2周)

3. **集成测试阶段** (2周)
   - 单元测试
   - 集成测试
   - 性能测试

4. **文档和发布阶段** (1周)
   - 技术文档编写
   - 示例代码编写
   - 发布准备

### 6.2 里程碑
- **Week 1**: 完成需求分析和技术设计
- **Week 3**: 完成iOS平台开发
- **Week 5**: 完成Android平台开发
- **Week 7**: 完成集成测试
- **Week 8**: 完成文档和发布

---

## 7. 风险评估

### 7.1 技术风险
- **平台兼容性**: 不同设备和系统版本的兼容性问题
- **性能影响**: 录制过程对游戏性能的影响
- **权限管理**: 复杂的权限申请流程

### 7.2 缓解措施
- **充分测试**: 在多种设备上进行测试
- **性能优化**: 持续优化录制性能
- **权限引导**: 提供清晰的权限申请引导

---

## 8. 验收标准

### 8.1 功能验收
- [ ] 支持iOS和Android平台录制
- [ ] 支持MP4和GIF格式输出
- [ ] 支持音频录制
- [ ] 权限管理功能正常
- [ ] 文件压缩功能正常

### 8.2 性能验收
- [ ] 录制期间CPU占用率 < 15%
- [ ] 录制期间内存增长 < 100MB
- [ ] 对游戏帧率影响 < 5%
- [ ] SDK初始化时间 < 500ms

### 8.3 兼容性验收
- [ ] 支持目标平台版本范围
- [ ] 支持主流设备分辨率
- [ ] 适配中低端设备性能

---

## 9. 附录

### 9.1 参考文档
- [内网调研文档](https://sofunny.feishu.cn/wiki/UMrTwFmFjid6sBkwpgvceLR6n2b)

### 9.2 相关标准
- iOS Human Interface Guidelines
- Android Design Guidelines
- Unity Plugin Development Guidelines

### 9.3 变更记录
| 版本 | 日期 | 变更内容 | 作者 |
|------|------|----------|------|
| 1.0.0 | 2025-10-10 | 初始版本创建 | Waka |

---

*本文档将根据开发进度持续更新和完善*
