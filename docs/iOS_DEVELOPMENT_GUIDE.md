## Sausage Replay SDK - iOS 开发指南

### 概述
- **目标平台**: iOS 12.0 及以上
- **CPU 架构**: 仅 `arm64`（设备），模拟器支持 `arm64`/`x86_64` 切片
- **语言**: 纯 Objective‑C
- **产物**: `XCFramework`（供 Unity `Plugins/iOS` 使用），无需 CocoaPods 发版
- **输出格式**: MP4（H.264；HEVC 可后续按设备能力择优扩展）
- **录制范围**: 应用内画面（游戏）+ 应用内音频（游戏声音）+ 麦克风（可选）
- **默认行为**: 导出成功后写入相册；可通过参数选择改为写入 App 沙盒

参考与预研资料：[飞书文档（内部）](https://sofunny.feishu.cn/wiki/UMrTwFmFjid6sBkwpgvceLR6n2b)

### 架构与模块
- Core: SDK 生命周期、状态机、配置加载、错误码映射、主线程派发
- Recording: `ReplayKit` 采集（`RPScreenRecorder startCapture`），视频/音频管线管理
- AudioMix: 应用音频与麦克风音频混合（`CMSampleBuffer` → 混音 → `AVAssetWriterInput`）
- Export: MP4 写入（`AVAssetWriter`，H.264），文件大小上限策略，完成回调
- Permissions: 麦克风权限、相册写入权限申请与结果回传（系统 UI）
- Bridge: Unity 桥接（C 接口导出 + `UnitySendMessage` 回调，主线程派发）
- Config: 质量档位 JSON（高清/标清），设备性能档位策略（`MidRange`/`HighEnd`）

### 目录布局（建议）
- `ios/SDK/Core/`
- `ios/SDK/Recording/`
- `ios/SDK/AudioMix/`
- `ios/SDK/Export/`
- `ios/SDK/Permissions/`
- `ios/SDK/Bridge/`
- `ios/SDK/Config/quality_profiles.json`
- `ios/Demo/`（最小可运行 Demo，验证录制流程与权限）
- `ios/Scripts/`（`xcframework` 打包与拷贝到 `unity/Plugins/iOS/` 脚本）

### 关键设计与实现细节
1) 采集与编码
   - 视频: `RPScreenRecorder startCaptureWithHandler:` 获取 `CMSampleBufferRef`（video），使用 `AVAssetWriter` + `AVAssetWriterInput`（H.264）写入；关键帧间隔、帧率上限随质量档位配置
   - 音频: 同步处理 `audioApp`（应用音频）与 `audioMic`（麦克风）样本；在自定义混音节点中对齐时间戳并混合后送入 `AVAssetWriterInput`（AAC）
   - 同步: 以视频时间线为基准，对音频使用 `CMSampleBufferGetPresentationTimeStamp` 对齐；丢失样本安全处理（静音填充）

2) 权限与系统 UI
   - 麦克风: 首次使用触发系统弹窗（`NSMicrophoneUsageDescription`）
   - 相册写入: 导出到相册需 `NSPhotoLibraryAddUsageDescription`
   - SDK API 返回权限检查/请求结果（供业务侧自定义 UI 与兜底逻辑），同时不屏蔽系统 UI

3) 存储策略
   - 默认: 写入相册（完成后返回相册本地标识或文件路径副本）
   - 可选: 写入 App 沙盒（`Caches/tmp/Documents` 可选），通过启动参数或 `RecordingConfig` 进行控制

4) 质量档位与设备档位
   - 质量档位: 仅“高清/标清”，从 `ios/SDK/Config/quality_profiles.json` 加载
   - 设备档位: `MidRange`/`HighEnd`（来自运行时硬件判定策略）；不同设备档位可映射到不同质量默认值

5) 文件大小控制
   - 目标大小上限（字节）+ 自适应回退：优先降码率，其次降分辨率，最后降帧率（不启用帧丢弃/动态码率时的静态回退策略）
   - 录制最长时长默认 60s，可配置

6) 错误码与回调
   - 错误码与 Android 对齐；iOS 特有错误映射到通用分类并附带平台子码
   - 所有回调在主线程派发到 Unity（`UnitySendMessage`）

### Unity 接口与回调
- C 导出接口：与现有 C#/Unity API 对齐（`Initialize/Start/Pause/Resume/Stop` 等）
- 回调集中封装在 `SausageReplaySDK.cs` 内部，外部无需固定 `GameObject` 名称
- 错误/进度/完成回调均在主线程调用

### Info.plist 配置
- `NSMicrophoneUsageDescription`
- `NSPhotoLibraryAddUsageDescription`

### XCFramework 打包
1) 生成静态库 + 头文件（目标 `iphoneos`/`iphonesimulator`）
2) 使用 `xcodebuild -create-xcframework` 组合切片
3) 产出目录：`dist/SausageReplaySDK.xcframework`
4) 脚本将产物与头文件拷贝到 `unity/Plugins/iOS/`

### 性能指标与优化
- 录制期 CPU < 15%，内存增长 < 100MB
- 使用硬件编码（H.264），避免在主线程做重负载
- 音频混音与文件写入使用后台队列，确保回调上抛在主线程

### 日志与诊断
- 可配置日志级别（Error/Warning/Info/Verbose）
- 导出失败时提供详细错误码与上下文（权限、磁盘、编码器状态）

### 里程碑
- M1: 项目 Scaffold 与桥接接口雏形，可编译 `XCFramework`
- M2: 采集与编码打通（视频+应用音频+麦克风），Demo 可录制
- M3: 文件大小控制与质量档位生效，默认写相册
- M4: 错误码对齐与文档完成，Unity 联调通过


