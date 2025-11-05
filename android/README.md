# RePlay 录屏 SDK（Android）README

## 概览

RePlay 录屏 SDK 提供原生 Android 屏幕录制能力，适配 Unity 项目集成：
- 屏幕录制（视频 + 可选麦克风音频）：基于 MediaProjection + MediaRecorder + VirtualDisplay
- 前台服务：Android 10+ 使用 `FOREGROUND_SERVICE_TYPE_MEDIA_PROJECTION`
- 设备档位：按 `VideoQualityPreset` 选择分辨率/码率/FPS 等基线参数
- 自定义参数：支持按次自定义码率/帧率（在档位基线之上覆盖）
- 统一日志与错误码：`Logger` 开关、`ErrorCodes` 集中管理
- 回调优先级：按次回调优先，其次 Unity 全局回调，避免重复派发
- 输出文件：应用私有目录，回调返回“相对路径 + MD5”便于 Unity 校验

## 环境与依赖
- minSdk: 22（示例）
- 编译：Android Gradle（Kotlin）
- 运行权限：
  - 录音（如需麦克风）：`android.permission.RECORD_AUDIO`
  - 前台服务（投屏）：`android.permission.FOREGROUND_SERVICE_MEDIA_PROJECTION`（Android 10+）
- 平台支持检查：
  - `SausageReplayAndroidSDK.isPlatformSupported()` 返回 false 的典型原因：
    - API < 21（无 MediaProjection）
    - 设备缺少 H.264 编码器（`video/avc`）

## 构建 AAR

### 使用 Gradle 任务

在 `android` 目录下执行以下命令：

```bash
# 构建并导出 AAR 到 Unity Package 目录
./gradlew :replay-sdk:exportAar
```

或者使用提供的脚本：

```bash
# 使用 export-aar.sh 脚本
./export-aar.sh
```

构建完成后，AAR 文件会自动导出到：
- `Package/Runtime/Plugins/Android/SausageReplaySDK.aar`

### 其他 Gradle 任务

```bash
# 查看 AAR 包信息
./gradlew :replay-sdk:aarInfo

# 清理导出的 AAR 包
./gradlew :replay-sdk:cleanExportedAar

# 仅构建 AAR（不导出）
./gradlew :replay-sdk:assembleRelease
```

构建的 AAR 文件位置：
- 构建输出：`replay-sdk/build/outputs/aar/replay-sdk-release.aar`
- Unity 导出：`Package/Runtime/Plugins/Android/SausageReplaySDK.aar`

## 安装与集成

### 引入 AAR
- 将 `SausageReplaySDK.aar` 放入宿主工程的 `libs/`，并在对应 module 的 `build.gradle` 中声明 `implementation files('libs/SausageReplaySDK.aar')`

### 混淆（ProGuard/R8）
- SDK 自带基础规则；若宿主强混淆，建议保留接口：
```
-keep class com.funny.replaysdk.** { *; }
-dontwarn com.funny.replaysdk.**
```

### Manifest 组件
- SDK 内部已声明：
  - `com.funny.replaysdk.ScreenCapturePermissionActivity`（透明授权中转）
  - `com.funny.replaysdk.RecordingForegroundService`（前台服务）
- 宿主需自行声明的典型权限（按需）：
```
<uses-permission android:name="android.permission.RECORD_AUDIO" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_MEDIA_PROJECTION" />
```

## 初始化与日志

```kotlin
val ok = SausageReplayAndroidSDK.initialize(
    context = applicationContext,
    preset = VideoQualityPreset.STANDARD,   // BASIC/SMOOTH/HIGH_FPS/ULTRA
    enableDebugLog = true                   // 控制 SDK 内部日志
)
```
- 推荐在 `Application.onCreate()` 中调用。
- 未显式初始化时，`startRecording(...)` 会做惰性兜底初始化（不建议依赖）。

## 录制控制 API

Kotlin/Java：
```kotlin
// 1) 最简单：按档位自动生成配置
@JvmStatic fun startRecording(activity: Activity): Boolean

// 2) 自动配置 + 按次回调
@JvmStatic fun startRecording(activity: Activity, callback: RecordingCallback?): Boolean

// 3) 自定义配置（在档位基线之上覆盖）
@JvmStatic fun startRecording(activity: Activity, config: RecordingConfig, callback: RecordingCallback?): Boolean

@JvmStatic fun stopRecording()                                  // Unity 无参重载
@JvmStatic fun stopRecording(callback: (RecordingResult) -> Unit)
@JvmStatic fun getRecordingStatus(): Int
@JvmStatic fun getDetailedStatus(): DetailedStatus
```

### RecordingConfig（按次自定义）
```kotlin
data class RecordingConfig(
    val maxDurationSeconds: Int = 1800,
    val maxFileSizeBytes: Long = 300L * 1024 * 1024,
    val includeAudio: Boolean = true,
    val targetBitrate: Int = 0,              // 0 表示不覆盖，使用档位默认码率
    val targetFps: Int = 30,
    val performanceTier: Int = VideoQualityPreset.STANDARD
)
```
- `performanceTier` 选择“设备档位基线”，`targetBitrate/targetFps` 用于“局部覆盖”。
- 分辨率等仍由档位计算，当前版本不直接暴露分辨率自定义。

### RecordingCallback（原生按次回调）
```kotlin
interface RecordingCallback {
    fun onRecordingStarted()
    fun onRecordingProgress(durationMs: Long, fileSizeBytes: Long)
    fun onRecordingStopped(result: RecordingResult)
    fun onRecordingError(errorCode: Int, errorMessage: String?)
}
```

### RecordingResult（结果）
```kotlin
data class RecordingResult(
    val isSuccess: Boolean,
    val filePath: String?,     // 相对路径（相对于 persistentDataPath）
    val fileSize: Long,
    val duration: Float,
    val fileMd5: String?,      // 文件 MD5（可用于一致性校验）
    val errorCode: Int,
    val errorMessage: String?
)
```

## 回调机制与优先级
- 优先派发“按次回调”`RecordingCallback`
- 若本次未提供参数回调，且已设置了 Unity 全局回调，则派发给 Unity 回调

Unity 全局回调接口：
```java
interface UnityRecordingCallback {
  void onRecordingStarted();
  void onRecordingProgress(long durationMs, long fileSizeBytes);
  void onRecordingStopped(boolean success, String filePath, long fileSize, float duration, String fileMd5, int errorCode, String errorMessage);
  void onRecordingError(int errorCode, String errorMessage);
  void onRecordingQualityAdjusted(int quality); // 录制中质量调整已废弃，默认 no-op
}
```

## 文件输出与路径 / MD5
- 默认保存：`Android/data/<pkg>/files/Movies/replay/replay_yyyyMMdd_HHmmss.mp4`
- 回调中 `filePath` 为“相对路径”：
  - Unity 获取完整路径：`Path.Combine(Application.persistentDataPath, filePath)`
- 回调中包含 `fileMd5`，便于 Unity 侧一致性校验
- 若时长 < 1s：SDK 自动删除文件，并返回 `DURATION_TOO_SHORT` 错误

## Unity 接入指南（C#）

通过 Unity Package Manager 导入 SDK 后，可以使用统一的 C# API：

### 使用 Unity C# API（推荐）

```csharp
using SausageReplay;

public class ReplayController : MonoBehaviour, SausageReplaySDK.IRecordingCallback
{
    void Start()
    {
        // 初始化SDK
        bool ok = SausageReplaySDK.Initialize(SausageReplaySDK.VideoQualityPreset.Standard, enableDebugLog: true);
        if (ok)
        {
            Debug.Log("SDK初始化成功");
        }
    }
    
    public void StartRecording()
    {
        // 开始录制（传入回调接口）
        bool success = SausageReplaySDK.StartRecording(this);
    }
    
    public void StopRecording()
    {
        SausageReplaySDK.StopRecording();
    }
    
    // 实现 IRecordingCallback 接口
    public void OnRecordingStarted() { Debug.Log("[SDK] started"); }
    public void OnRecordingProgress(long durationMs, long fileSizeBytes) { Debug.Log($"[SDK] {durationMs}ms, {fileSizeBytes}B"); }
    public void OnRecordingStopped(SausageReplaySDK.RecordingResult result) { /* 处理结果 */ }
    public void OnRecordingError(int errorCode, string errorMessage) { Debug.LogError($"[SDK] {errorCode} - {errorMessage}"); }
}
```

### 直接使用 Android JNI（高级用法）

如果需要直接调用 Android SDK，可以使用以下方式：

```csharp
#if UNITY_ANDROID && !UNITY_EDITOR
var unityPlayer = new AndroidJavaClass("com.unity3d.player.UnityPlayer");
var activity = unityPlayer.GetStatic<AndroidJavaObject>("currentActivity");

var sdk = new AndroidJavaClass("com.funny.replaysdk.SausageReplayAndroidSDK");
var presets = new AndroidJavaClass("com.funny.replaysdk.VideoQualityPreset");
int preset = presets.GetStatic<int>("STANDARD");

bool ok = sdk.CallStatic<bool>("initialize", activity, preset, true);

var mgr = new AndroidJavaClass("com.funny.replaysdk.RecordingManager");
mgr.CallStatic("setUnityRecordingCallback", new ReplayUnityCallbacks());
#endif
```

**使用 Unity C# API（推荐）**：
```csharp
// 简单开始录制
bool success = SausageReplaySDK.StartRecording(callback);

// 使用自定义配置（仅Android）
bool success = SausageReplaySDK.StartRecordingWithCustomConfig();
```

**直接使用 Android JNI（高级用法）**：
```csharp
#if UNITY_ANDROID && !UNITY_EDITOR
// 简单开始录制
bool success = new AndroidJavaClass("com.funny.replaysdk.RecordingManager")
    .CallStatic<bool>("startRecording", activity);

// 自定义配置开始录制
var presets = new AndroidJavaClass("com.funny.replaysdk.VideoQualityPreset");
int preset = presets.GetStatic<int>("HIGH_FPS");

// Kotlin data class：构造参数顺序需完全匹配
AndroidJavaObject config = new AndroidJavaObject(
    "com.funny.replaysdk.RecordingConfig",
    3600,                // maxDurationSeconds
    500L * 1024 * 1024,  // maxFileSizeBytes
    true,                // includeAudio
    10_000_000,          // targetBitrate：Int（0 表示不覆盖）
    60,                  // targetFps
    preset               // performanceTier
);

bool success = new AndroidJavaClass("com.funny.replaysdk.RecordingManager")
    .CallStatic<bool>("startRecording", activity, config, null);
#endif
```

Unity 全局回调示例：
```csharp
public class ReplayUnityCallbacks : AndroidJavaProxy {
    public ReplayUnityCallbacks() : base("com.funny.replaysdk.UnityRecordingCallback") {}
    public void onRecordingStarted() { Debug.Log("[SDK] started"); }
    public void onRecordingProgress(long durationMs, long fileSizeBytes) { Debug.Log($"[SDK] {durationMs}ms, {fileSizeBytes}B"); }
    public void onRecordingStopped(bool success, string filePath, long fileSize, float duration, string fileMd5, int errorCode, string errorMessage) {
        if (success && !string.IsNullOrEmpty(filePath)) {
            string fullPath = System.IO.Path.Combine(Application.persistentDataPath, filePath);
            if (!string.IsNullOrEmpty(fileMd5)) {
                // 可选：Unity 侧 MD5 复核
            }
            Debug.Log($"[SDK] stopped: {fullPath}, {duration}s, {fileSize}B, md5={fileMd5}");
        } else {
            Debug.LogError($"[SDK] error: {errorCode} - {errorMessage}");
        }
    }
    public void onRecordingError(int errorCode, string errorMessage) { Debug.LogError($"[SDK] {errorCode} - {errorMessage}"); }
    public void onRecordingQualityAdjusted(int quality) {}
}
```

## 错误码（选摘）
- `2000` 录制已在进行中
- `2001` 未开始录制
- `2002` 用户拒绝授权
- `2003` 创建 MediaProjection 失败
- `2004` 启动录制失败
- `2005` 启动超时
- `2006` 拉起授权 Activity 失败
- `2010` MediaRecorder 错误
- `2011` 录制时长过短（<1s）

## 常见问题（FAQ）
- Q: 录制成功但时长为 0？
  - A: 使用 `MediaMetadataRetriever` 读取时长；短于 1s 的文件会被删除并返回错误。
- Q: 自定义 `targetBitrate` 的建议范围？
  - A: 参考档位默认区间：
    - 720p30：4–5 Mbps；1080p30：7–9 Mbps；720p60：6–8 Mbps；1080p60：12–16 Mbps；1440p≤60：18–22 Mbps。
- Q: Unity 如何获取完整路径？
  - A: `Path.Combine(Application.persistentDataPath, filePath)`，其中 `filePath` 来自回调。
- Q: 模拟器是否支持？
  - A: 依赖系统是否提供 MediaProjection 与 H.264 编码器，部分模拟器不支持或稳定性较差。

## 变更记录（摘要）
- 新增：回调返回相对路径 + `fileMd5`
- 变更：`RecordingConfig.targetBitrate` 改为 `Int`，`0` 表示不覆盖
- 移除：`RecordingConfig.outputPath`
- 移除：录制中“质量调整”能力，统一使用 `VideoQualityPreset` 并在“下一次录制”生效

---
如需启用完全自定义分辨率/更多编码选项，请联系本 SDK 维护者评估新增字段与兼容性策略。

