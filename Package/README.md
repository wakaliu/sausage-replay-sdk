# Sausage Recorder SDK (Unity Package)

## 简介
- 跨平台屏幕录制 SDK，支持 Android / iOS。
- 统一初始化与回调。
- 支持自定义配置（Android：码率/FPS/时长等）。

## 安装
- **作为本地 Unity Package**：将本目录以 UPM 本地包导入。
  - 打开 Package Manager → + → Add package from disk… → 选择 `package.json`
- **使用 Git 依赖**：在 `Packages/manifest.json` 中添加（注意：需要指定 `path=Package` 参数）：
```json
"com.funny.sausage-recorder-sdk": "git@git.tube:package/com.sofunny.sausage.recorder.git?path=Package"
```

## 目录结构
- `Runtime/`
  - `SausageReplaySDK.cs`（主桥接）
  - `UnityMainThreadDispatcher.cs`（主线程派发）
  - `Plugins/Android`（Manifest 与 FileProvider 配置）
  - `Plugins/iOS`（Objective‑C Bridge）
- `Samples~/BasicRecording`（基础示例脚本）
- [`Docs/Integration.md`](Docs/Integration.md)（接入与排错详解）

## 快速开始（C#）
```csharp
// 初始化
var ok = SausageReplay.SausageReplaySDK.Initialize(
    SausageReplay.SausageReplaySDK.VideoQualityPreset.Standard, enableDebugLog: true);

// 开始录制（实现 IRecordingCallback 接口）
SausageReplay.SausageReplaySDK.StartRecording(this);

// 停止录制
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

录制结果：
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

## Android 自定义配置
使用辅助方法创建配置并启动：
```csharp
// 示例：60s、500MB、含音频、10Mbps、60fps、STANDARD 档位
SausageReplay.SausageReplaySDK.StartRecordingWithCustomConfig();
```
（内部会构造 `com.funny.replaysdk.RecordingConfig` 并调用 Android 的 `startRecording(activity, config)`）

## 常见问题（简）

> **📖 详细文档**：更多详情（完整接入步骤、错误码、FAQ 等），请参阅：[**集成与接入指南**](Docs/Integration.md)

## 许可
MIT

