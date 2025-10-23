# Sausage Replay SDK - iOS 平台软件需求规格文档 (SRS-iOS)

## 文档信息
- **项目名称**: Sausage Replay SDK - iOS
- **文档类型**: 软件需求规格文档 (SRS)
- **版本**: v1.0.0
- **作者**: Waka
- **创建日期**: 2025年10月10日
- **最低支持版本**: iOS 12.0+
- **开发语言**: Objective-C
- **集成平台**: Unity 2022.3.57f1
- **交付形式**: .xcframework（供Unity集成）

---

## 1. 引言

### 1.1 目的
本文件定义iOS平台SDK的功能与技术规格，作为设计、开发、测试与验收的统一依据。

### 1.2 范围
- 为Unity提供屏幕录制能力：包含UI、支持麦克风音频，同步输出。
- 输出格式：MP4/GIF（GIF为转码流程）。
- 不包含：分享、任何UI弹窗。

### 1.3 参考
- `docs/PRD.md`
- `docs/SRS.md`

---

## 2. 总体描述

### 2.1 架构概览
```
Unity (C# API)
  ↕ Unity-iOS Bridge (Objective-C)
SausageReplay.xcframework (Objective-C)
  ├─ SRRecordingManager (ReplayKit + AVAssetWriter)
  ├─ SRFileManager
  └─ SRConfig/Models
```

### 2.2 运行约束
- 单实例录制；并发录制不支持。
- 前台录制；后台不支持。
- 存储：应用沙盒私有目录；文件清理可配置。

### 2.3 视频清晰度档位（iOS）
- `Basic`（720p30，4.5 Mbps）
- `Standard`（1080p30，8 Mbps，默认）
- `Smooth`（720p60，7 Mbps）
- `HighFPS`（1080p60，14 Mbps）
- `Ultra`（1440p30/60，20 Mbps）

档位影响：编码分辨率/FPS/比特率、缓冲深度、任务调度策略、是否启用GIF转码。

---

## 2.4 兼容性补充（ReplayKit模式）
- 数据流捕获（Sample Handler / RPBroadcastSampleHandler 等流式接口）在 iOS 11.0+ 可用。
- iOS 9/10 早期版本仅支持基于系统录屏生成文件的方式，无法获取实时数据流。
- 本SDK最低支持 iOS 12.0+，因此默认采用数据流模式并基于 ReplayKit + AVAssetWriter 实现实时写入。

---

## 3. 功能需求

### FR-IOS-001 初始化
- `initializeWithTier:` 幂等；根据档位设置默认参数与队列优先级。
- 能力检测：ReplayKit可用性、写存储可用、音频授权状态。
- 非阻塞：内部在后台队列完成重任务准备。

### FR-IOS-002 权限管理
- 无UI：不弹出任何SDK层提示；失败通过回调错误码。
- 麦克风权限：查询与请求（交由宿主触发）；返回`PermissionResult`。
- 屏录授权：由`RPScreenRecorder`系统流程触发；结果回调至宿主，SDK不代办UI。

### FR-IOS-003 屏幕录制
- 使用`RPScreenRecorder`捕获屏幕与麦克风音频（可选）。
- 视频编码：`AVAssetWriter`写入H.264，音频AAC；容器MP4。
- 分辨率/FPS/比特率：依据档位与`SRRecordingConfig`选择；支持上限约束。
- 时长上限：默认60s；到时自动停止并回调。

### FR-IOS-004 文件管理与GIF
- 私有目录写入；返回绝对路径。
- GIF：录制完成后转码（逐帧采样+量化），受尺寸与时长限制。
- 临时文件：异常中止清理。

### FR-IOS-005 录制控制
- `startRecordingWithConfig:`：参数校验、准备`AVAssetWriter`、建立回调通道。
- `pause/resume`：通过丢帧/静音软暂停策略实现（ReplayKit原生暂停受限）。
- `stopWithCallback:`：关闭写入并回调`SRRecordingResult`。
- 状态：`Idle/Recording/Paused/Stopping`。

### FR-IOS-006 错误处理
- 与通用`docs/SRS.md`错误码域对齐：权限/录制/文件/系统。
- 回调线程：主线程派发；重任务后台执行。

---

## 4. 非功能需求

### NFR-IOS-001 主线程非阻塞
- 初始化、权限、启停录制、文件写入/转码均在后台队列执行；主线程仅派发回调与响应Unity调用。
- 如主线程阻塞>16ms需优化或拆分。

### NFR-IOS-002 性能
- CPU占用：录制中<15%。
- 内存增长：<100MB。
- 启停延迟：启动<200ms，停止<1000ms；转码<5s（视时长）。

### NFR-IOS-003 兼容性
- iOS 12+；新系统上适配ReplayKit行为差异。

---

## 5. 接口设计

### 5.1 Objective-C 对外API（供Unity调用）
```objective-c
// 视频清晰度档位
typedef NS_ENUM(NSInteger, SRVideoQualityPreset) {
    SRVideoQualityPresetBasic = 0,      // 720p30
    SRVideoQualityPresetStandard = 1,   // 1080p30
    SRVideoQualityPresetSmooth = 2,     // 720p60
    SRVideoQualityPresetHighFps = 3,    // 1080p60
    SRVideoQualityPresetUltra = 4       // 1440p30/60
};

@interface SausageReplayIOSSDK : NSObject
+ (BOOL)initializeWithPreset:(SRVideoQualityPreset)preset;
+ (BOOL)isPlatformSupported;
+ (NSString *)version;
+ (void)releaseResources;
@end


typedef NS_ENUM(NSInteger, SRRecordingStatus) {
    SRRecordingStatusIdle,
    SRRecordingStatusRecording,
    SRRecordingStatusStopping
};


@interface SRRecordingConfig : NSObject
@property (nonatomic, assign) NSInteger maxDurationSeconds; // default 60
@property (nonatomic, assign) BOOL includeAudio; // default YES
@property (nonatomic, copy) NSString * _Nullable outputPath;
@property (nonatomic, assign) NSInteger targetBitrate; // optional
@property (nonatomic, assign) NSInteger targetFps; // default 30
@end

@interface SRRecordingManager : NSObject
+ (BOOL)startRecordingWithConfig:(SRRecordingConfig *)config;
+ (void)stopRecording:(void(^)(BOOL success, NSString * _Nullable filePath, long long fileSize, float duration, NSInteger errorCode, NSString * _Nullable message))callback;
+ (SRRecordingStatus)status;
@end
```

### 5.2 Unity桥接（C#侧期望）
- 与`docs/SRS.md` C#签名保持一致，通过`[DllImport]`或`iOS Bridge`方式调用Objective-C静态方法。

### 5.3 模型对齐
- `PermissionResult/RecordingResult/RecordingStatus/ErrorCode`与总SRS一致。

---

## 6. 档位与参数

### 6.1 档位策略
| 维度 | MidRange（默认） | HighEnd |
|------|------------------|---------|
| 分辨率上限 | 1280x720 | 1920x1080 |
| 目标FPS | 30 | 30 |
| 比特率参考 | 3~6 Mbps | 6~10 Mbps |
| GOP | 2s | 1~2s |
| 音频 | AAC LC 48kHz @ 96~128kbps | AAC LC 48kHz @ 128kbps |
| 缓冲深度 | 中 | 高 |
| GIF策略 | ≤10fps，≤720p | ≤12fps，≤1080p |

### 6.2 自适应与降级
- 指标：写入耗时、丢帧率、系统温度、存储预估。
- 降级链：降码率→降分辨率→降FPS；MP4优先，必要时禁用GIF转码。
- 恢复：指标稳定后小步回升（仅HighEnd允许）。

---

## 6.3 档位策略矩阵（详细）

| 维度 | MidRange（默认） | HighEnd |
|------|------------------|---------|
| 分辨率上限 | 1280x720 | 1920x1080 |
| 目标FPS | 30 | 30 |
| 视频比特率参考 | 3~6 Mbps | 6~10 Mbps |
| 关键帧间隔 (GOP) | 2s | 1~2s |
| 编码Profile | Main | Main/High |
| 音频 | AAC LC 48kHz @ 96~128kbps | AAC LC 48kHz @ 128kbps |
| 写入缓冲深度 | 中 | 高 |
| 录制线程并发 | 2~3 | 3~4 |
| GIF策略 | ≤10fps，≤720p | ≤12fps，≤1080p |
| I/O策略 | 串行写入+中等缓存 | 异步写入+双缓冲 |
| 日志级别 | Info | Debug |

---

## 6.4 动态自适应与触发阈值
- 指标采集：`AVAssetWriter`写入耗时、丢帧率、系统温度（ThermalState）、存储剩余、主线程帧耗时（<16ms）。
- 触发条件与动作：
  1) 丢帧率>3% 或 写入耗时尖峰>200ms：降低比特率10~20%。
  2) 丢帧率>5% 或 连续拥塞>500ms：降分辨率（1080p→720p）。
  3) 持续抖动：降FPS至25/20。
  4) 存储预估超限：提前停止或进一步降码率。
- 恢复策略：指标连续稳定N秒（如10s）后小步回升（仅HighEnd允许）。

---

## 6.5 线程与缓冲策略
- 主线程：仅进行回调派发与Unity交互，严禁重任务。
- 录制管线：ReplayKit帧回调→后台队列编码→`AVAssetWriter`写入；分阶段异步启动/停止。
- 缓冲：环形队列+背压策略；拥塞时优先丢弃非关键帧，保证时序与稳定性。

---

## 7. 存储、I/O 与 GIF 策略
- 目录：`<App>/Library/Caches/replay/`，可配置。
- 写入：小块顺序写入，必要时启用双缓冲；避免主线程I/O。
- 磁盘阈值：剩余<200MB拒绝开始；过程中超限提前停止并回调。
- GIF：默认MidRange及以上启用；采样帧率Mid≤10fps/≤720p，High≤12fps/≤1080p；体积上限建议≤20MB，超限自动进一步降采样或返回MP4与错误码。

---

## 8. 监控与日志
- 指标：CPU、内存增量、写入耗时、队列深度、丢帧率、主线程帧耗时、ThermalState变化。
- 日志：结构化（level、tag、eventId、value），日志级别可通过配置调整；SDK不内置上报，仅提供回调钩子。

---

## 9. 变更记录
| 版本 | 日期 | 变更内容 | 作者 |
|------|------|----------|------|
| 1.0.0 | 2025-10-10 | 初始版本创建 | Waka |
