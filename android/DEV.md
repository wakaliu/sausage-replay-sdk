# Android 开发记录（变更日志）

> 目的：记录 `android/` 工程下与 SDK 开发相关的关键变更、约定与兼容性说明，便于团队协作与回溯。

## 目录
- 工程结构与约定
- 命名空间与版本配置
- 功能里程碑
- 重要兼容性说明
- 待办与后续计划

---

## 工程结构与约定
- 库模块：`replay-sdk`（唯一真源，产出 AAR 提供 Unity 集成）
- 示例模块：`app`（仅用于功能验证与性能测试，不包含业务逻辑）
- 包名/命名空间统一：`com.funny.replaysdk`（sample 为 `com.funny.replaysdk.sample`）

## 命名空间与版本配置
- compileSdk = 36（满足 `androidx.core:1.17.0+` 要求）
- targetSdk = 33（保守目标以降低行为变更带来的影响）
- minSdk = 22（Android 5.1）

## 功能里程碑

### 2025-01-XX (里程碑E) - CPU性能优化
- **CPU核心绑定优化**：
  - 实现录制线程CPU小核绑定，避免影响游戏性能
  - 使用Android Process API设置线程优先级为THREAD_PRIORITY_LOWEST
  - 添加CPU优化配置选项，支持动态启用/禁用
  - 新增`setCpuOptimizationEnabled()`和`isCpuOptimizationEnabled()`API
- **硬件编码器优化**：
  - 优先使用H.264/HEVC硬件编码器，减少CPU负担
  - 自动检测硬件编码器支持，回退到软件编码器
  - 设置硬件编码器特定参数和配置文件
  - 优化音频编码参数(AAC 128kbps)
- **动态质量调节**：
  - 实时监控CPU和内存使用率
  - 根据性能自动调整录制质量(比特率、分辨率、帧率)
  - 支持手动触发性能检查和质量调节
  - 新增`setDynamicQualityEnabled()`、`getCurrentQualityReduction()`等API
- **性能监控机制**：
  - 每5秒自动检查系统性能
  - 智能质量降级和恢复策略
  - 完善的日志记录和回调通知
- **性能提升**：
  - 录制线程绑定到小核，减少对主线程的干扰
  - 降低功耗，延长电池续航时间
  - 提升多任务场景下的用户体验
- **兼容性保障**：
  - CPU绑定失败时自动降级到默认行为
  - 支持运行时动态配置CPU优化策略
  - 完善的日志记录和错误处理

### 2025-10-10 (里程碑D)
- **多格式支持**：
  - 扩展 `OutputFormat` 枚举：支持 MP4、GIF、WEBM、AVI
  - 实现 `convertVideoFormat()` 格式转换API
  - 添加格式转换辅助函数和路径生成
  - Sample 应用集成格式转换按钮
- **高级功能**：
  - 完善 `RecordingConfig` 支持更多配置选项
  - 实现 `getDetailedStatus()` 详细状态查询
  - 添加 `recoverFromError()` 错误恢复机制
  - 增强状态同步和资源管理

### 2025-10-10 (里程碑C)
- **暂停/恢复功能**：
  - 实现 `pauseRecording()` 和 `resumeRecording()` 方法
  - 支持 Android 7.0+ 原生暂停/恢复，低版本使用软暂停策略
  - 状态机支持 `PAUSED` 状态，完整的状态流转
  - 错误码扩展：3001-3002 覆盖暂停/恢复错误场景
- **录制进度监控**：
  - 实现 `onRecordingProgress(durationMs, fileSizeBytes)` 回调
  - 每500ms更新一次录制进度（时长、文件大小）
  - Sample 应用实时显示录制进度信息
- **性能优化**：
  - 优化 `RecordingWorker` 线程管理，支持优雅退出
  - 实现 `getMemoryUsage()` 内存监控API
  - 添加 `adjustRecordingQuality()` 动态质量调整功能
  - 完善资源回收机制，防止内存泄漏
- **UI 增强**：
  - 新增暂停/恢复按钮，支持录制过程中的控制
  - 新增质量调整按钮（高/中/低质量）
  - 增强内存监控显示，实时显示内存使用情况

### 2025-10-10 (里程碑B)
- **线程安全架构**：
  - 新增 `RecordingWorker` 工作线程，所有录制操作串行执行
  - 状态管理线程安全：`AtomicReference<RecordingStatus>` 替代普通变量
  - 主线程回调：通过 `Handler(Looper.getMainLooper())` 确保回调在主线程执行
- **回调接口系统**：
  - 新增 `RecordingCallback` 接口：`onRecordingStarted/Progress/Paused/Resumed/Stopped/Error`
  - 错误码标准化：2000-2004 覆盖常见错误场景
  - Sample 应用集成回调测试，实时反馈录制状态
- **API 增强**：
  - `startRecording()` 支持可选回调参数
  - `getRecordingStatus()` 返回实时状态
  - 所有录制操作异步化，避免阻塞主线程

### 2025-10-10 (里程碑A)
- 初始化工程（方式A：空壳工程 + Library + sample）
- `replay-sdk`：
  - API 骨架：`SausageReplayAndroidSDK`、`PermissionManager`、`RecordingManager`、模型与枚举
  - 录制链路最小可运行：MediaProjection + MediaRecorder + VirtualDisplay
  - 配置项：`maxDurationSeconds` 自动停止；`maxFileSizeBytes` 尝试应用；`includeAudio` 麦克风开关；质量档位分辨率与默认码率
  - 异常清理与状态复位
- `app`：
  - 最小 UI（开始/停止）与权限、授权回调转发

## 重要兼容性说明
- 部分厂商系统（包括部分 Android 10 设备）对 MediaProjection 启动路径有更严格限制，可能抛出：
  - `SecurityException: Media projections require a foreground service of type ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PROJECTION`
- 处理策略：
  - sample 通过 `RecordingFgService` 前台服务统一启动录屏；
  - 库中提供 `RecordingManager.startWithProjection(resultCode, data)` 供服务直接调用；
  - 该方案对 Android 10 及以下版本也兼容，不影响功能（会出现“录制中”前台通知）。

## 待办与后续计划
- 状态机完善（IDLE/RECORDING/PAUSED/STOPPING），异常路径更细的错误码映射
- `pause/resume` 支持：不支持 `MediaRecorder.pause()` 的设备回退到软暂停策略
- 录制中动态降级策略（码率/分辨率/FPS）与监控指标上报接口
- GIF 转码流程与体积控制（中高端档位默认允许，低端机默认关闭）

---

如对上述记录有补充，请在对应小节下直接追加条目，并保持时间倒序。
