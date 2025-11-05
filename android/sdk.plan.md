<!-- 61fd0968-a42f-4877-ace3-b2e5f921867f 3c422dd6-4f0c-4620-8a13-c19a3dd9274a -->
# RePlay 录屏 SDK 功能文档（初稿）

### 模块概览

- SDK 模块: `replay-sdk`（对外提供 AAR）
- 示例应用: `app`（演示集成与交互）
- 构建环境:
  - compileSdk: 36，minSdk: 22，Java/Kotlin 目标 11
  - 主要依赖：`androidx.core:core:1.13.1`
```14:29:replay-sdk/build.gradle.kts
android {
    namespace = "com.funny.replaysdk"
    compileSdk = 36
    defaultConfig { minSdk = 22 }
    ...
}
```


### 权限与组件

- 核心权限（SDK 声明）：前台服务、通知
```3:14:replay-sdk/src/main/AndroidManifest.xml
<uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
<uses-permission android:name="android.permission.POST_NOTIFICATIONS" />
<application>
    <activity android:name="com.funny.replaysdk.ScreenCapturePermissionActivity" ... />
    <service android:name="com.funny.replaysdk.RecordingForegroundService"
             android:foregroundServiceType="mediaProjection" />
</application>
```

- 示例 App 额外权限：录音、媒体投屏前台服务
```5:23:app/src/main/AndroidManifest.xml
<uses-permission android:name="android.permission.RECORD_AUDIO" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_MEDIA_PROJECTION" />
...
<service android:name=".RecordingFgService"
         android:foregroundServiceType="mediaProjection" />
```


### 核心功能

- 屏幕录制（视频+麦克风可选）：基于 MediaProjection + MediaRecorder + VirtualDisplay
- 授权与前台服务：透明代理 Activity 发起授权；Android 14+ 先启动 `mediaProjection` 类型前台服务
- 质量与性能：按“视频清晰度档位”与自适应策略计算分辨率、比特率、FPS；支持运行中调整质量
- 文件输出：默认保存到 `Context.getExternalFilesDir(MOVIES)/replay/replay_yyyyMMdd_HHmmss.mp4`
- Unity 对接：通过回调接口适配 Unity 事件

### 对外 API（Kotlin/Java 可调用）

- 初始化与生命周期
```33:58:replay-sdk/src/main/java/com/funny/replaysdk/SausageReplayAndroidSDK.kt
object SausageReplayAndroidSDK {
    @JvmStatic fun initialize(context: Context, preset: Int = VideoQualityPreset.STANDARD, enableDebugLog: Boolean = true): Boolean
    @JvmStatic fun isPlatformSupported(): Boolean
    @JvmStatic fun getVersion(): String
    @JvmStatic fun createPerformanceMonitor(callback: PerformanceCallback? = null): PerformanceMonitor?
    @JvmStatic fun getDeviceTierInfo(): DeviceTierInfo?
    @JvmStatic fun reloadDeviceTierConfig(): Boolean
    @JvmStatic fun release()
}
```

- 录制控制
```253:351:replay-sdk/src/main/java/com/funny/replaysdk/SausageReplayAndroidSDK.kt
object RecordingManager {
    @JvmStatic fun startRecording(activity: Activity): Boolean
    @JvmStatic fun startRecording(activity: Activity, callback: RecordingCallback?): Boolean
    @JvmStatic fun startRecording(activity: Activity, config: RecordingConfig, callback: RecordingCallback?): Boolean
    @JvmStatic fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?)
    @JvmStatic fun startWithProjection(resultCode: Int, data: Intent)
    @JvmStatic fun stopRecording(callback: (RecordingResult) -> Unit)
    @JvmStatic fun stopRecording() // Unity 无参重载
    @JvmStatic fun getRecordingStatus(): Int
    @JvmStatic fun adjustRecordingQuality(quality: Int): Boolean
    @JvmStatic fun resetStatus()
    @JvmStatic fun getDetailedStatus(): DetailedStatus
    @JvmStatic fun getDetailedStatusJson(): String
}
```

- 回调与数据结构
```134:172:replay-sdk/src/main/java/com/funny/replaysdk/SausageReplayAndroidSDK.kt
interface RecordingCallback { ... }
data class RecordingConfig(
  val maxDurationSeconds: Int,
  val maxFileSizeBytes: Long,
  val includeAudio: Boolean,
  val targetBitrate: Int,   // 0 表示不覆盖，使用档位默认码率
  val targetFps: Int,
  val performanceTier: Int
)
data class RecordingResult(
    val isSuccess: Boolean,
    val filePath: String?,      // 相对路径（相对于 persistentDataPath）
    val fileSize: Long,
    val duration: Float,
    val fileMd5: String?,       // 文件 MD5 值，用于完整性验证
    val errorCode: Int,
    val errorMessage: String?
)
data class DetailedStatus(...)
```

- Unity 回调桥接
```1:18:replay-sdk/src/main/java/com/funny/replaysdk/UnityCallbacks.kt
interface UnityRecordingCallback {
  fun onRecordingStarted()
  fun onRecordingProgress(durationMs: Long, fileSizeBytes: Long)
  fun onRecordingStopped(
      success: Boolean,
      filePath: String?,        // 相对路径（相对于 persistentDataPath）
      fileSize: Long,
      duration: Float,
      fileMd5: String?,         // 文件 MD5 值
      errorCode: Int,
      errorMessage: String?
  )
  fun onRecordingError(errorCode: Int, errorMessage: String?)
  fun onRecordingQualityAdjusted(quality: Int)
}
```


### 设备清晰度档位与自适应

- 配置来源：`assets/device_tier_config.json`；可热加载
```1:242:replay-sdk/src/main/assets/device_tier_config.json
{"videoQualityPresets": { "BASIC"|"STANDARD"|"SMOOTH"|"HIGH_FPS"|"ULTRA" ... },
 "adaptiveStrategies": { bitrateReduction, resolutionDegradation, fpsDegradation }}
```

- 管理类职责
```12:66:replay-sdk/src/main/java/com/funny/replaysdk/DeviceTierManager.kt
object DeviceTierManager {
  fun initializeWithPreset(context, preset): Boolean
  fun getCurrentTier(): Int; fun getCurrentTierConfig(): TierConfig?
  fun getAdaptiveStrategies(): AdaptiveStrategies?
  fun createPerformanceMonitor(...): PerformanceMonitor?
  fun calculateRecordingParams(...): RecordingParams
  fun applyAdaptiveAdjustment(...): RecordingParams
}
```

- 配置解析与默认兜底
```12:96:replay-sdk/src/main/java/com/funny/replaysdk/DeviceTierConfig.kt
object DeviceTierConfig { loadConfig/reloadConfig/getPresetConfig/getAdaptiveStrategies/... }
```

- 运行时质量调整（录制中）
录制中质量调整能力已移除；通过 `initialize(context, preset)` 切换 `VideoQualityPreset`，在下一次录制生效。


### 授权与前台服务流程

- 透明授权 Activity
```12:35:replay-sdk/src/main/java/com/funny/replaysdk/ScreenCapturePermissionActivity.kt
// onCreate -> MediaProjectionManager.createScreenCaptureIntent -> startActivityForResult
// onActivityResult -> RecordingManager.onActivityResult -> finish()
```

- Android 14+ 前台服务
```15:23:replay-sdk/src/main/java/com/funny/replaysdk/RecordingForegroundService.kt
startForeground(NOTIFICATION_ID, notification, FOREGROUND_SERVICE_TYPE_MEDIA_PROJECTION)
```

- 录制启动关键路径
```353:582:replay-sdk/src/main/java/com/funny/replaysdk/SausageReplayAndroidSDK.kt
onActivityResult -> ensure foreground service -> startWithProjection -> MediaRecorder/VirtualDisplay -> start()
```


### 文件与目录

- 输出目录：`Android/data/<pkg>/files/Movies/replay/`
```1003:1014:replay-sdk/src/main/java/com/funny/replaysdk/SausageReplayAndroidSDK.kt
private fun buildOutputFile(context: Context): File {
    val base = context.getExternalFilesDir(Environment.DIRECTORY_MOVIES) ?: context.filesDir
    val dir = File(base, "replay")
    ...
    val outputFile = File(dir, "replay_${'$'}ts.mp4")
}
```

- **文件路径返回方式**：SDK 回调中的 `filePath` 为**相对路径**（相对于 Unity 的 `persistentDataPath`）
  - 外部存储：`Movies/replay/replay_yyyyMMdd_HHmmss.mp4`
  - 内部存储：`Movies/replay/replay_yyyyMMdd_HHmmss.mp4`（如果使用内部存储）
  - Unity 获取完整路径：`Path.Combine(Application.persistentDataPath, filePath)`

- **文件 MD5 校验**：录制完成后，SDK 会自动计算文件的 MD5 值，并通过 `RecordingResult.fileMd5` 字段返回，方便 Unity 进行文件完整性验证


### 错误码与超时机制（选摘）

- 常见错误（集中管理于 `ErrorCodes`）：
  - 2000 录制已在进行中
  - 2001 未开始录制
  - 2002 用户拒绝授权
  - 2003 创建 MediaProjection 失败
  - 2004 启动录制失败
  - 2005 启动超时
  - 2006 拉起授权 Activity 失败
  - 2010 MediaRecorder 错误
- 启动超时：10s 未进入录制则复位为 IDLE
```278:287:replay-sdk/src/main/java/com/funny/replaysdk/SausageReplayAndroidSDK.kt
mainHandler.postAtTime({ if (status==STOPPING) { status=IDLE; onRecordingError(2005) } }, ...+10000)
```

### 错误码集中管理

- 位置：`replay-sdk/src/main/java/com/funny/replaysdk/ErrorCatalog.kt`
- 接口：
```1:999:replay-sdk/src/main/java/com/funny/replaysdk/ErrorCatalog.kt
internal object ErrorCodes {
  const val RECORDING_ALREADY_IN_PROGRESS = 2000
  ...
  fun messageFor(code: Int): String
  fun result(code: Int, extraMessage: String? = null, filePath: String? = null, fileSize: Long = 0L, duration: Float = 0f, fileMd5: String? = null): RecordingResult
}
```
- 用法示例：
```
callback?.onRecordingError(ErrorCodes.START_TIMEOUT, ErrorCodes.messageFor(ErrorCodes.START_TIMEOUT))
val result = ErrorCodes.result(ErrorCodes.RECORDING_NOT_STARTED, "status=$currentStatus")
```


### 性能监控（可选高级能力）

- 指标：帧丢失率、当前FPS、编码阻塞时长、队列深度、累计帧数等
- 策略：按阈值执行降级（先比特率，再分辨率，再FPS），稳定后逐步恢复
```15:79:replay-sdk/src/main/java/com/funny/replaysdk/PerformanceMonitor.kt
class PerformanceMonitor(...){ startMonitoring()/stopMonitoring()/recordFrame()/getCurrentMetrics() }
```


### 集成与使用示例（App）

- 初始化与切换清晰度档位
```213:233:app/src/main/java/com/funny/replay/MainActivity.kt
SausageReplayAndroidSDK.initialize(this, VideoQualityPreset.HIGH_FPS)
```

- 启停录制与回调
```89:161:app/src/main/java/com/funny/replay/MainActivity.kt
RecordingManager.startRecording(this, RecordingConfig(), callback)
...
RecordingManager.stopRecording { result -> ... }
```

### 回调分发策略

- 参数回调优先：当调用 `startRecording(..., callback)` 传入 `RecordingCallback` 时，事件优先派发给该回调。
- Unity 兜底：仅当本次未提供参数回调时，若已通过 `RecordingManager.setUnityRecordingCallback(...)` 设置了全局 Unity 回调，则派发给 Unity 回调。
- 目的：避免同一事件被重复回调（参数回调与 Unity 回调双发）。

#### Unity 设置全局回调（C# 示例）
```csharp
using UnityEngine;

public class ReplayUnityCallbacks : AndroidJavaProxy
{
    public ReplayUnityCallbacks() : base("com.funny.replaysdk.UnityRecordingCallback") {}

    // Kotlin 接口签名一致
    public void onRecordingStarted() {
        Debug.Log("[SDK] onRecordingStarted");
    }

    public void onRecordingProgress(long durationMs, long fileSizeBytes) {
        Debug.Log($"[SDK] progress: {durationMs} ms, {fileSizeBytes} B");
    }

    public void onRecordingStopped(bool success, string filePath, long fileSize, float duration, string fileMd5, int errorCode, string errorMessage) {
        if (success && !string.IsNullOrEmpty(filePath)) {
            // 获取完整路径（filePath 是相对于 persistentDataPath 的相对路径）
            string fullPath = System.IO.Path.Combine(Application.persistentDataPath, filePath);
            
            // 验证文件 MD5（如果提供了 MD5）
            if (!string.IsNullOrEmpty(fileMd5)) {
                string calculatedMd5 = CalculateFileMd5(fullPath);
                if (calculatedMd5 != fileMd5) {
                    Debug.LogWarning($"[SDK] MD5 mismatch! Expected: {fileMd5}, Got: {calculatedMd5}");
                } else {
                    Debug.Log($"[SDK] File MD5 verified: {fileMd5}");
                }
            }
            
            Debug.Log($"[SDK] stopped: {success}, relativePath={filePath}, fullPath={fullPath}, size={fileSize}, duration={duration}s, md5={fileMd5}, code={errorCode}");
        } else {
            Debug.Log($"[SDK] stopped: {success}, code={errorCode}, msg={errorMessage}");
        }
    }
    
    private string CalculateFileMd5(string filePath) {
        // Unity C# MD5 计算示例（需要 using System.Security.Cryptography）
        using (var md5 = System.Security.Cryptography.MD5.Create()) {
            using (var stream = System.IO.File.OpenRead(filePath)) {
                byte[] hash = md5.ComputeHash(stream);
                return System.BitConverter.ToString(hash).Replace("-", "").ToLowerInvariant();
            }
        }
    }

    public void onRecordingError(int errorCode, string errorMessage) {
        Debug.LogError($"[SDK] error: {errorCode} - {errorMessage}");
    }

    public void onRecordingQualityAdjusted(int quality) {
        Debug.Log($"[SDK] quality adjusted: {quality}");
    }
}

public class ReplayUnityInit : MonoBehaviour
{
    void Awake() {
    #if UNITY_ANDROID && !UNITY_EDITOR
        var unityPlayer = new AndroidJavaClass("com.unity3d.player.UnityPlayer");
        var activity = unityPlayer.GetStatic<AndroidJavaObject>("currentActivity");

        var sdk = new AndroidJavaClass("com.funny.replaysdk.SausageReplayAndroidSDK");
        var presets = new AndroidJavaClass("com.funny.replaysdk.VideoQualityPreset");
        int preset = presets.GetStatic<int>("STANDARD");

        // 初始化（第三参控制 SDK 日志开关）
        bool ok = sdk.CallStatic<bool>("initialize", activity, preset, true);

        // 设置全局 Unity 回调（仅在本次未传入参数回调时兜底接收事件）
        var mgr = new AndroidJavaClass("com.funny.replaysdk.SausageReplayAndroidSDK$RecordingManager");
        mgr.CallStatic("setUnityRecordingCallback", new ReplayUnityCallbacks());
    #endif
    }
}
```

#### 原生按次回调（Kotlin 示例）
```kotlin
val callback = object : com.funny.replaysdk.RecordingCallback {
    override fun onRecordingStarted() { /* update UI */ }
    override fun onRecordingProgress(durationMs: Long, fileSizeBytes: Long) { /* progress */ }
    override fun onRecordingStopped(result: com.funny.replaysdk.RecordingResult) { /* handle result */ }
    override fun onRecordingError(errorCode: Int, errorMessage: String?) { /* toast/log */ }
}

// 参数回调优先：若传入 callback，将不会再触发 Unity 全局回调
com.funny.replaysdk.SausageReplayAndroidSDK.RecordingManager.startRecording(activity, callback)
```

- 查询状态
```291:307:app/src/main/java/com/funny/replay/MainActivity.kt
val detailedStatus = RecordingManager.getDetailedStatus()
```


### AAR 导出

- 自定义 Gradle 任务：`exportAar` 将 `replay-sdk-release.aar` 复制为 `Package/Runtime/Plugins/Android/SausageReplaySDK.aar`
```78:117:replay-sdk/build.gradle.kts
tasks.register<Copy>("exportAar") { dependsOn("assembleRelease"); ... }
```


### 兼容性与注意事项

- Android 10+ 建议使用前台服务类型 `mediaProjection`
- 录音为 MIC（示例 App 申请 `RECORD_AUDIO`）；若需系统内录需另行适配 `AudioPlaybackCapture`（当前未实现）
- 目标分辨率/比特率会受设备编解码能力实际限制
- 输出目录为应用私有外部存储，卸载即清除；若需公共相册需适配 MediaStore
- **文件路径与 MD5**：
  - SDK 返回的 `filePath` 为相对路径（相对于 Unity 的 `persistentDataPath`），Unity 可通过 `Path.Combine(Application.persistentDataPath, filePath)` 获取完整路径
  - SDK 自动计算并返回文件的 MD5 值，Unity 可用于文件完整性验证

### 后续改造对比参考点

- 内录与混音能力（当前仅 MIC）
- 录制容错（进程保活、异常恢复、文件校验与时长统计）
- 配置动态下发与在线更新
- GPU 叠加（涂鸦/水印/浮窗）与 HEVC 编码选项
- Media3/CameraX/Preview 合流与音视频管线抽象
- 更细粒度的错误码与日志分级、埋点

### To-dos

- [ ] 确认文档范围（仅SDK或含示例App、Unity集成说明）
- [ ] 确认文档深度（是否需要时序图、错误码全表、FAQ）


