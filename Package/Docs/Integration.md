# Sausage Replay SDK - Unity 集成与接入指南

> 本文提供完整接入步骤、API 说明、错误码对照与常见问题。建议先阅读 `README.md` 完成本地包导入，再参考本文进行集成。

## 相关链接
- **Android SDK 原生工程**：[../android/](../android/)
- **iOS SDK 原生工程**：[../ios/](../ios/)

## 1. 环境与支持
- Android：API 21+（≥ 5.0），设备具备 H.264（video/avc）编码器
- iOS：iOS 12+（ReplayKit 支持）
- 不支持模拟器
- 此功能对性能和渲染有一定影响，建议在高端设备使用。

## 2. 安装与导入
- **作为本地 Unity Package**：打开 Package Manager → + → Add package from disk… → 选择 `package.json`（本文件所在目录）
- **使用 Git 依赖**：在 `Packages/manifest.json` 中添加（注意：需要指定 `path=Package` 参数，因为 package.json 位于 Package 子目录中）：
```json
"com.funny.sausage-recorder-sdk": "git@git.tube:package/com.sofunny.sausage.recorder.git?path=Package"
```

## 3. 权限与平台配置
### 3.1 Android
- 已在 `Runtime/Plugins/Android/AndroidManifest.xml` 声明常用权限与 `FileProvider`，如需裁剪可按需修改：
  - `android.permission.RECORD_AUDIO`
  - `android.permission.FOREGROUND_SERVICE`
  - `android.permission.FOREGROUND_SERVICE_MEDIA_PROJECTION`
- 输出文件路径使用应用私有目录，`file_paths.xml` 已配置。

### 3.2 iOS
- 使用 ReplayKit，无需额外工程设置。回调以 JSON 字符串回传至 Unity。

## 4. 初始化与生命周期
```csharp
// 建议在游戏启动时调用
var ok = SausageReplay.SausageReplaySDK.Initialize(
    SausageReplay.SausageReplaySDK.VideoQualityPreset.Standard,
    enableDebugLog: true);

// 释放（一般不需要主动调用）
SausageReplay.SausageReplaySDK.Release();
```

## 5. 录制控制与回调
```csharp
// 开始录制（实现 IRecordingCallback 或订阅事件）
SausageReplay.SausageReplaySDK.StartRecording(this);

// 停止录制（仅在 IDLE 时拦截；iOS STOPPING 也可停止）
SausageReplay.SausageReplaySDK.StopRecording();
```

回调接口：
```csharp
public interface IRecordingCallback {
  void OnRecordingStarted();
  void OnRecordingProgress(long durationMs, long fileSizeBytes);
  void OnRecordingStopped(RecordingResult result);
  void OnRecordingError(int errorCode, string errorMessage);
}
```

录制结果（iOS 以 JSON 填充同字段）：
```csharp
[Serializable]
public class RecordingResult {
  public bool isSuccess;
  public string filePath;    // Android 相对路径 / iOS 文件名
  public long fileSize;
  public float duration;
  public string fileMd5;     // 完整性校验
#if UNITY_IOS && !UNITY_EDITOR
  public string assetLocalId; // iOS 相册资源 ID
#endif
  public int errorCode;
  public string errorMessage;
}
```

## 6. Android 自定义配置（可选）
支持按次覆盖档位基线：码率 / FPS / 最长时长 / 最大文件大小。
```csharp
// 示例：60s、500MB、含音频、10Mbps、60fps、STANDARD 档位
SausageReplay.SausageReplaySDK.StartRecordingWithCustomConfig();
```
内部将构造：
```kotlin
data class RecordingConfig(
    val maxDurationSeconds: Int = 1800,
    val maxFileSizeBytes: Long = 300L * 1024 * 1024,
    val includeAudio: Boolean = true,
    val targetBitrate: Int = 0,
    val targetFps: Int = 30,
    val performanceTier: Int = VideoQualityPreset.STANDARD
)
```
> 注意：Kotlin data class 构造顺序需严格匹配。

## 7. 错误码（对照摘录）
- 2000：录制已在进行中
- 2001：未开始录制
- 2002：用户拒绝授权
- 2003：平台不支持 / 创建失败（如无 H.264 编码器）
- 2004：启动录制失败
- 2005：启动超时
- 2010：MediaRecorder 错误（Android）
- 2011：录制时长过短（< 1s）

## 8. 常见接入问题（FAQ）
- Q：iOS 停止后 Unity 没收到 onStopped？
  - A：已在原生桥接将 stop completion 的结果 JSON 转发，确保 Unity 能收到；若仍未收到，请确认 Initialize 后四个回调已注册。
- Q：录制成功但找不到文件？
  - A：Android 回调返回相对路径，需 `Path.Combine(Application.persistentDataPath, filePath)` 获取完整路径。
- Q：MD5 有何用途？
  - A：可用于 Unity 侧复核文件完整性，避免传输过程中损坏。
- Q：短视频为何返回失败？
  - A：时长 < 1s 会视为无效片段以避免占用存储，并返回错误码。
- Q：模拟器是否支持？
  - A：不支持（模拟器环境需客户端自行判断）。

## 9. 验证清单（首次集成必查）
- [ ] 初始化返回 true，并能获取版本号
- [ ] 开始/停止录制，回调完整（含 progress/stopped/error）
- [ ] Android 文件路径可在 `Application.persistentDataPath` 下拼接访问
- [ ] iOS onStopped JSON 含 fileMd5、assetLocalId 字段
- [ ] 自定义配置能生效（码率/FPS/时长任一项）

---
如需启用更多编码参数或深度自定义，请联系 SDK 维护者评估新增字段与兼容性策略。

