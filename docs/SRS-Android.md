# Sausage Replay SDK - Android 平台软件需求规格文档 (SRS-Android)

## 文档信息
- **项目名称**: Sausage Replay SDK - Android
- **文档类型**: 软件需求规格文档 (SRS)
- **版本**: v1.0.0
- **作者**: Waka
- **创建日期**: 2025年10月10日
- **最低支持版本**: Android 5.1 (API 22)
- **目标SDK版本**: API 33
- **编译SDK版本**: API 34
- **开发语言**: Kotlin
- **集成平台**: Unity 2022.3.57f1
- **开发环境**: Windows 10, Android Studio 2025.1.3, Java 11.0.27 (LTS)

---

## 1. 引言

### 1.1 目的
本文件定义Android平台SDK的功能与技术规格，作为设计、开发、测试与验收的统一依据。

### 1.2 范围
- 为Unity提供屏幕录制能力：包含UI、支持麦克风音频，同步输出。
- 输出格式：MP4/GIF，支持压缩与大小控制。
- 不包含：分享、任何UI弹窗。

### 1.3 参考
- `docs/PRD.md`
- `docs/SRS.md`

---

## 2. 总体描述

### 2.1 架构概览
```
Unity (C# API)
  ↕ JNI/Unity AndroidJava* 桥接
Android AAR (Kotlin)
  ├─ PermissionManager
  ├─ RecordingManager (MediaProjection + MediaRecorder)
  ├─ FileManager (私有目录/压缩)
  └─ Config/Models
```

### 2.2 运行约束
- 单实例录制；并发录制不支持。
- 前台录制；不支持后台。
- 存储：优先应用私有目录；文件清理可配置。

---

## 2.3 设备性能档位（Android）
可选档位：
- `Basic`（720p30，4.5 Mbps）
- `Standard`（1080p30，8 Mbps，默认）
- `Smooth`（720p60，7 Mbps）
- `HighFPS`（1080p60，14 Mbps）
- `Ultra`（1440p30/60，20 Mbps）

档位影响：编码分辨率/FPS/比特率、缓冲深度、线程与任务调度策略、是否启用GIF转码。

---

## 3. 功能需求

### FR-AND-001 初始化
- 提供`init(context)`，幂等。
- 校验设备能力（编解码器、存储可用、权限状态查询能力）。
- 失败返回错误码与信息。

### FR-AND-002 权限管理
- 暴露检查与申请API（无界面）：
  - 录音：`RECORD_AUDIO`
  - 媒体存储（仅在公开目录写入时需要）：`READ/WRITE_MEDIA_*`（按目标SDK分支）
- 权限申请结果通过回调返回`PermissionResult(IsGranted, ErrorCode, ErrorMessage)`；SDK不弹窗提示。
- 用户永久拒绝时返回`PermissionPermanentlyDenied`。

### FR-AND-003 屏幕录制
- 使用`MediaProjection`创建`VirtualDisplay`，`Surface`接入`MediaRecorder`视频源。
- 分辨率：根据视频清晰度档位自动选择（Basic/720p, Standard/1080p, Smooth/720p, HighFPS/1080p, Ultra/1440p）。
- 帧率：根据视频清晰度档位自动设置（Basic/30fps, Standard/30fps, Smooth/60fps, HighFPS/60fps, Ultra/30-60fps）。
- 比特率：根据视频清晰度档位自动计算（Basic/4.5Mbps, Standard/8Mbps, Smooth/7Mbps, HighFPS/14Mbps, Ultra/20Mbps）。
- 录制时长：默认60s；到时自动停止并回调。

### FR-AND-004 音频录制
- 音频源：`AudioSource.MIC`，与视频合轨（`MediaRecorder`）。
- 采样率：48kHz（可降至44.1kHz）；编码`AAC`，码率默认`96~128kbps`（可配置）。

### FR-AND-005 文件生成与压缩
- 容器：MP4（H.264 + AAC）。
- GIF：通过录制完成后转码（逐帧采样+量化），受尺寸/时长限制（默认最长15s或分辨率≤720p）。
- 输出路径：应用私有目录，返回绝对路径。
- 大小控制：基于目标比特率与时长估算并限流；超限提前停止或降码率策略。
- 临时文件：录制结束后清理；异常中止时尝试恢复或删除残留。

### FR-AND-006 录制控制
- `start(config)`：参数校验、创建会话、进入录制态。
- `pause()/resume()`：在支持设备上通过`MediaRecorder`暂停/恢复；不支持时回退为软暂停（丢弃帧/静音）。
- `stop(callback)`：关闭`MediaRecorder`、`VirtualDisplay`、`MediaProjection`，返回`RecordingResult(FilePath, FileSize, Duration, ErrorCode)`。
- 状态查询：`getStatus()` → `Idle/Recording/Paused/Stopping`。

### FR-AND-007 错误处理与回调
- 回调线程：切换到主线程派发给Unity（或提供线程策略配置）。
- 统一错误码：与`docs/SRS.md`一致，含权限/录制/文件/系统类。

---

## 4. 非功能需求

### NFR-AND-001 性能
- CPU占用：典型机型录制时<15%。
- 内存增长：<100MB。
- 启停时延：启动<200ms，停止<1000ms，合成/转码<5s（视时长）。

### NFR-AND-002 兼容性
- 最低API 22，目标API 33，编译API 34。
- 厂商定制兼容策略：降级帧率/分辨率、软暂停回退、捕获异常参数自适应。

### NFR-AND-003 可靠性
- 资源泄漏零容忍：所有`Surface/Codec/Projection`严格成对释放。
- 异常恢复：录制失败可重试；残留文件自动清理。

### NFR-AND-004 可观测性
- 结构化日志（level、tag、eventId）。
- 可选埋点接口：关键事件（开始、暂停、恢复、停止、失败）。

---

## 4.5 主线程非阻塞
- 初始化、权限检查、创建`MediaProjection/VirtualDisplay`、`MediaRecorder`准备、文件I/O与GIF转码均在后台线程/协程执行。
- 所有回调在主线程派发；若后台操作超过阈值，需分片或分阶段执行，避免>16ms主线程阻塞。
- 关键路径（开始/停止录制）需采用异步状态机，UI线程仅发起指令。

---

## 5. 接口设计

### 5.1 Kotlin对外API（更新）
```kotlin
object VideoQualityPreset {
    const val BASIC = 0      // 720p30
    const val STANDARD = 1   // 1080p30
    const val SMOOTH = 2     // 720p60
    const val HIGH_FPS = 3   // 1080p60
    const val ULTRA = 4      // 1440p30/60
}

object SausageReplayAndroidSDK {
    fun initialize(context: Context, preset: Int = VideoQualityPreset.STANDARD): Boolean
    fun isPlatformSupported(): Boolean
    fun getVersion(): String
    fun release()
}

object PermissionManager {
    fun hasMicrophonePermission(context: Context): Boolean
    fun requestMicrophonePermission(activity: Activity, callback: (PermissionResult) -> Unit)
}

object RecordingManager {
    fun startRecording(activity: Activity): Boolean
    fun stopRecording(callback: (RecordingResult) -> Unit)
    fun pauseRecording()
    fun resumeRecording()
    fun getRecordingStatus(): RecordingStatus
}
```

### 5.2 Unity桥接（C#侧期望）
- 方法与`docs/SRS.md`中的C#签名一致，通过`AndroidJavaClass/AndroidJavaObject`映射。

### 5.3 配置与模型（更新）
```kotlin
// 录制配置现在由 Android 端根据设备档位自动生成
// Unity 端不再需要传递 RecordingConfig 参数
// Android 端会根据设备性能档位自动选择最优的录制参数

enum class VideoQuality { LOW, MEDIUM, HIGH }

enum class OutputFormat { MP4, GIF }

data class PermissionResult(
    val isGranted: Boolean,
    val errorCode: Int = 0,
    val errorMessage: String? = null
)

data class RecordingResult(
    val isSuccess: Boolean,
    val filePath: String? = null,
    val fileSize: Long = 0,
    val duration: Float = 0f,
    val errorCode: Int = 0,
    val errorMessage: String? = null
)

enum class RecordingStatus { IDLE, RECORDING, PAUSED, STOPPING }
```

---

## 6. 权限与清单

### 6.1 必需权限
- `RECORD_AUDIO`
- 录屏授权通过`MediaProjection`系统对话框（由宿主App触发，SDK不弹窗）。

### 6.2 可选权限（按目标SDK分支）
- 仅当写入公共媒体目录时：`READ_MEDIA_VIDEO` / `WRITE_EXTERNAL_STORAGE`（旧版）

### 6.3 Manifest与Proguard
- `AndroidManifest.xml`中声明必需权限（不声明`WRITE_EXTERNAL_STORAGE`，默认私有目录）。
- Proguard/R8：保留对外API类与反射使用的类型。

---

## 7. 录制与编码参数（按清晰度档位）

| 清晰度档位 | 分辨率 | 帧率 | 视频比特率 | 适用场景 |
|------------|--------|------|------------|----------|
| Basic | 720p | 30fps | 4.5 Mbps | 普通录屏、教程 |
| Standard | 1080p | 30fps | 8 Mbps | 主流游戏、应用 |
| Smooth | 720p | 60fps | 7 Mbps | 动作游戏、流畅度优先 |
| HighFPS | 1080p | 60fps | 14 Mbps | 竞技游戏、高动态 |
| Ultra | 1440p | 30fps | 20 Mbps | 高端内容、素材采集 |

音频：AAC LC，48kHz，96~128kbps；低端机可降至44.1kHz/96kbps。

---

## 7.1 清晰度档位选择

- **Basic (720p30)**：适合普通录屏、教程类内容，文件体积小
- **Standard (1080p30)**：主流选择，平衡质量与文件大小
- **Smooth (720p60)**：流畅度优先，适合动作游戏
- **HighFPS (1080p60)**：高质量回放，适合竞技游戏
- **Ultra (1440p)**：最高清晰度，适合高端内容制作

### 7.2 档位策略矩阵（详细）

| 维度 | Basic | Standard | Smooth | HighFPS | Ultra |
|------|-------|----------|--------|---------|-------|
| 目标分辨率 | 720p (1280x720) | 1080p (1920x1080) | 720p (1280x720) | 1080p (1920x1080) | 1440p (2560x1440) |
| 目标FPS | 30 | 30 | 60 | 60 | 30 |
| 视频比特率 | 4.5 Mbps | 8 Mbps | 7 Mbps | 14 Mbps | 20 Mbps |
| 关键帧间隔 (GOP) | 1s | 1s | 1s | 1s | 1s |
| 编码Profile | HIGH | HIGH | HIGH | HIGH | HIGH |
| 音频 | AAC LC 48kHz @ 128kbps | AAC LC 48kHz @ 128kbps | AAC LC 48kHz @ 128kbps | AAC LC 48kHz @ 128kbps | AAC LC 48kHz @ 128kbps |
| 缓冲深度（帧队列） | 6帧 | 6帧 | 8帧 | 10帧 | 12帧 |
| 线程并发 | 3工作线程 | 3工作线程 | 4工作线程 | 4工作线程 | 6工作线程 |
| 文件I/O | 串行写入+中等缓存 | 串行写入+中等缓存 | 异步写入+双缓冲 | 异步写入+双缓冲 | 异步写入+双缓冲 |
| 日志级别 | INFO | INFO | DEBUG | DEBUG | DEBUG |

注：所有参数由 Android 端根据视频清晰度档位从配置文件自动读取，无需手动配置；录制过程中可根据设备性能动态调整参数。

### 7.3 自动配置机制
- **清晰度档位选择**：Unity 端初始化时选择视频清晰度档位
- **配置文件读取**：Android 端从 `device_tier_config.json` 读取对应档位的录制参数
- **参数自动生成**：根据配置文件的参数自动生成 `RecordingConfig`
- **动态调整**：录制过程中根据实际性能表现动态调整参数
- **无需手动配置**：Unity 端只需调用 `StartRecording()`，无需传递任何配置参数

---

## 7.2 动态自适应与触发阈值
- 指标采集：编码队列长度、`MediaRecorder`写入耗时、丢帧率、系统温度、存储剩余、主线程帧耗时（目标<16ms）。
- 触发条件与动作（按优先级）：
  1) 丢帧率>3% 或 编码阻塞>200ms：降低比特率10~20%。
  2) 丢帧率>5% 或 队列持续拥塞>500ms：降分辨率一级（如1080p→720p）。
  3) 持续抖动：降FPS至25/20。
  4) 存储预估超限：提前停止或强制再降码率。
- 恢复策略：指标连续稳定N秒（如10s）后逐步回升（仅在HighEnd/Flagship允许）。

---

## 7.3 线程与缓冲策略
- 主线程：仅派发回调与接收Unity指令；严禁耗时操作。
- 编码线程池：`LOW_END=1-2, MID=2-3, HIGH=3-4, FLAG=4-6`；用于参数计算、I/O、GIF转码。
- Surface采集到编码的缓冲队列采用无界警戒+丢弃非关键帧策略，保证稳定写入。
- 关键操作（开始/停止）分阶段异步：资源创建→连接→准备→开始；释放反向执行，确保每步可恢复。

---

## 7.4 I/O 与存储策略
- 默认写入应用私有目录：`/data/data/<pkg>/files/replay/`。
- 小块顺序写，避免频繁fsync；采用预分配（可选）降低碎片。
- 磁盘阈值：剩余空间<200MB时拒绝开始；录制中估算超限则提前停止并回调`InsufficientStorage`。
- 临时文件：统一前缀与后缀；异常退出时下次初始化清理。

---

## 7.5 GIF 策略细化
- 默认仅中端及以上档位启用；低端机默认禁用（可显式开启但将强制更低fps与分辨率）。
- 采样帧率：LowEnd≤8fps, Mid≤10fps, High≤12fps, Flag≤15fps。
- 分辨率上限：LowEnd≤480p, Mid≤720p, High/Flag≤1080p。
- 体积上限建议：≤20MB；超过则自动进一步降采样或返回MP4并附错误码。

---

## 7.6 监控与日志
- 指标：CPU、内存增量、队列深度、丢帧率、I/O耗时、回调耗时、主线程帧耗时。
- 日志：结构化（level、tag、eventId、value）；日志级别根据设备档位自动设置（SDK不内置上报）。

---

## 8. 错误码（节选，完整见`docs/SRS.md`）
- 权限：`PermissionDenied(1001)`、`PermissionPermanentlyDenied(1002)`
- 录制：`RecordingAlreadyStarted(2002)`、`RecordingFailed(2004)`
- 文件：`FileCreationFailed(3001)`、`FileSizeExceeded(3002)`
- 系统：`InsufficientStorage(4002)`、`SDKNotInitialized(4004)`

---

## 9. 测试与验收

### 9.1 功能测试
- 初始化、权限、开始/暂停/恢复/停止、结果回调、异常路径。

### 9.2 性能测试
- 典型机型（API 22/28/33）录制60s时CPU/内存/温度/帧率影响。

### 9.3 兼容性测试
- 不同分辨率/厂商定制系统；横竖屏切换；来电/多任务打断场景。

### 9.4 稳定性测试
- 连续多轮录制与资源泄漏核查；异常中断后的恢复。

---

## 10. 变更记录
| 版本 | 日期 | 变更内容 | 作者 |
|------|------|----------|------|
| 1.0.0 | 2025-10-10 | 初始版本创建 | Waka |

---

## 11. Manifest/Proguard 最小模板

### 11.1 AndroidManifest 片段（宿主合并）
```xml
<manifest>
    <uses-permission android:name="android.permission.RECORD_AUDIO" />
    <!-- 若写入公共媒体目录（可选，按目标SDK选择合适权限） -->
    <!-- <uses-permission android:name="android.permission.READ_MEDIA_VIDEO" /> -->
    <!-- 旧设备（target<33）写存储权限才需要 -->
    <!-- <uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" tools:ignore="ScopedStorage" /> -->

    <application>
        <!-- 无需导出组件；如需前台Service则另行定义（当前不需要） -->
    </application>
</manifest>
```

### 11.2 Proguard/R8 规则
```pro
# 保留对外API，避免混淆
-keep class com.funny.replaysdk.** { *; }
-dontwarn com.funny.replaysdk.**

# 若使用反射或ServiceLoader，需补充keep
```

---

## 12. Unity C# ↔ Kotlin 桥接示例

### 12.1 C# 调用示例（Unity）
```csharp
using UnityEngine;

public class ReplayBridge
{
    private const string SdkClass = "com.funny.replaysdk.SausageReplayAndroidSDK";
    private const string PermClass = "com.funny.replaysdk.PermissionManager";
    private const string RecClass = "com.funny.replaysdk.RecordingManager";

    public static bool Initialize()
    {
        using (var jc = new AndroidJavaClass(SdkClass))
        using (var unityPlayer = new AndroidJavaClass("com.unity3d.player.UnityPlayer"))
        using (var activity = unityPlayer.GetStatic<AndroidJavaObject>("currentActivity"))
        {
            return jc.CallStatic<bool>("initialize", activity);
        }
    }

    public static void RequestMicPermission(System.Action<bool,int,string> callback)
    {
        using (var jc = new AndroidJavaClass(PermClass))
        using (var unityPlayer = new AndroidJavaClass("com.unity3d.player.UnityPlayer"))
        using (var activity = unityPlayer.GetStatic<AndroidJavaObject>("currentActivity"))
        {
            var proxy = new PermissionCallbackProxy(callback);
            jc.CallStatic("requestMicrophonePermission", activity, proxy);
        }
    }

    private class PermissionCallbackProxy : AndroidJavaProxy
    {
        private readonly System.Action<bool,int,string> _cb;
        public PermissionCallbackProxy(System.Action<bool,int,string> cb) : base("com.funny.replaysdk.IPermissionCallback")
        { _cb = cb; }
        public void onResult(bool granted, int errorCode, string message) { _cb?.Invoke(granted, errorCode, message); }
    }
}
```

### 12.2 Kotlin 回调接口示例
```kotlin
package com.funny.replaysdk

interface IPermissionCallback {
    fun onResult(granted: Boolean, errorCode: Int, message: String?)
}
```

---

## 13. GIF 转码策略
- 触发：仅当`outputFormat == GIF`或调用方在录制完成后显式请求。
- 流程：读取MP4 → 采样帧（建议8~15fps）→ 缩放（≤720p）→ 量化调色板（256色）→ 编码GIF。
- 性能：长视频转GIF耗时高；对>15s视频默认拒绝或提示降分辨率/帧率。
- 质量/体积平衡：默认`720p@10fps`，可配置；最大尺寸建议≤20MB。
- 失败回退：返回MP4路径与错误码`FileFormatNotSupported`或具体转码失败码（扩展2005/3004范围）。

---

## 14. 回调线程与生命周期/打断处理

### 14.1 回调线程策略
- Kotlin层统一在主线程派发回调至Unity（`Handler(Looper.getMainLooper())`）。
- 提供开关以允许在调用线程回调（高级使用场景）。

### 14.2 生命周期与打断（补充低端机策略）
- 低端机优先启用降级：当检测到编码排队拥塞或掉帧，优先降低比特率→降分辨率→降FPS。
- 状态机在降级事件中保持无阻塞；调整在后台应用，主线程仅接收状态通知。

---

## 15. 构建与Gradle配置（补充）
- 启用`androidx.concurrent`或`kotlinx.coroutines`以简化后台执行。
- 提供`strictMode`开关用于开发期检测主线程IO/网络/阻塞。

---

## 16. 兼容性与降级矩阵
| 场景 | 触发条件 | 降级策略 |
|------|----------|----------|
| 不支持`MediaRecorder.pause()` | 旧设备 | 软暂停（丢帧/静音） |
| 设备编码能力不足 | 初始化失败/编码异常 | 降分辨率/比特率；必要时拒绝录制 |
| 存储不足 | 写入失败 | 立即停止并回调`InsufficientStorage` |
| 横竖屏切换 | 配置变化 | 锁定方向或重建Display |

---

## 17. 安全与隐私
- 不采集或上传任何用户数据。
- 录制文件仅存储于应用私有目录，除非调用方显式导出。
- 权限结果与错误码仅用于SDK内控制与回调，不做持久化。

---

## 18. 开发清单（实施提示）
- 包结构：`com.funny.replaysdk.*`
- 关键类：`SausageReplayAndroidSDK`, `PermissionManager`, `RecordingManager`, `FileManager`。
- 单元测试：参数校验、错误码映射、状态机切换。
- 集成示例：提供最小Unity工程调用样例。
