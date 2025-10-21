# Unity iOS 集成指南

## 概述

本指南详细说明如何在 Unity 项目中集成 Sausage Replay iOS SDK，实现屏幕录制功能。

## 前置条件

- Unity 2020.3 LTS 或更高版本
- Xcode 12.0 或更高版本
- iOS 12.0 或更高版本的设备
- macOS 开发环境

## 集成步骤

### 1. 导入 SDK 文件

将以下文件复制到您的 Unity 项目中：

```
Assets/Plugins/iOS/
├── SausageReplay.xcframework/          # iOS SDK 框架
├── SausageReplaySDK.h                  # Unity 桥接头文件
└── SausageReplaySDK.mm                 # Unity 桥接实现文件
```

### 2. 配置 Unity 项目

#### 2.1 设置 iOS 构建设置

1. 打开 **File > Build Settings**
2. 选择 **iOS** 平台
3. 点击 **Player Settings**
4. 在 **iOS Settings** 中配置：
   - **Target minimum iOS Version**: 12.0
   - **Architecture**: ARM64

#### 2.2 配置 Info.plist

在 Unity 中，通过 **Player Settings > iOS Settings > Other Settings** 添加以下权限描述：

```
NSMicrophoneUsageDescription: 需要麦克风权限来录制音频
NSPhotoLibraryAddUsageDescription: 需要相册权限来保存录制的视频
```

或者手动编辑生成的 `Info.plist` 文件：

```xml
<key>NSMicrophoneUsageDescription</key>
<string>需要麦克风权限来录制音频</string>
<key>NSPhotoLibraryAddUsageDescription</key>
<string>需要相册权限来保存录制的视频</string>
```

### 3. 编写 C# 代码

#### 3.1 基本使用示例

```csharp
using UnityEngine;
using System;

public class ReplayManager : MonoBehaviour
{
    [Header("录制设置")]
    public VideoQualityPreset qualityPreset = VideoQualityPreset.Standard;
    
    [Header("UI 元素")]
    public UnityEngine.UI.Button startButton;
    public UnityEngine.UI.Button stopButton;
    public UnityEngine.UI.Text statusText;
    
    private bool isRecording = false;
    
    void Start()
    {
        // 初始化 SDK
        InitializeSDK();
        
        // 设置按钮事件
        if (startButton) startButton.onClick.AddListener(StartRecording);
        if (stopButton) stopButton.onClick.AddListener(StopRecording);
        
        // 设置录制回调
        SetRecordingCallbacks();
    }
    
    void InitializeSDK()
    {
        try
        {
            bool success = SausageReplaySDK.Initialize(qualityPreset);
            if (success)
            {
                Debug.Log($"SDK 初始化成功，使用档位: {qualityPreset}");
                UpdateStatus("SDK 已初始化");
            }
            else
            {
                Debug.LogError("SDK 初始化失败");
                UpdateStatus("SDK 初始化失败");
            }
        }
        catch (Exception e)
        {
            Debug.LogError($"SDK 初始化异常: {e.Message}");
            UpdateStatus("SDK 初始化异常");
        }
    }
    
    void SetRecordingCallbacks()
    {
        SausageReplaySDK.SetRecordingCallback(new RecordingCallback
        {
            OnRecordingStarted = () =>
            {
                Debug.Log("录制开始");
                UpdateStatus("录制中...");
                isRecording = true;
                UpdateButtonStates();
            },
            
            OnRecordingStopped = (result) =>
            {
                Debug.Log($"录制结束: 成功={result.isSuccess}, 文件={result.filePath}");
                isRecording = false;
                UpdateButtonStates();
                
                if (result.isSuccess)
                {
                    UpdateStatus($"录制完成: {FormatFileSize(result.fileSize)}");
                }
                else
                {
                    UpdateStatus($"录制失败: {result.errorMessage}");
                }
            },
            
            OnRecordingProgress = (duration, fileSize) =>
            {
                // 更新录制进度
                string durationStr = FormatDuration(duration);
                string sizeStr = FormatFileSize(fileSize);
                UpdateStatus($"录制中: {durationStr} - {sizeStr}");
            },
            
            OnRecordingError = (errorCode, message) =>
            {
                Debug.LogError($"录制错误: {errorCode} - {message}");
                UpdateStatus($"录制错误: {message}");
                isRecording = false;
                UpdateButtonStates();
            }
        });
    }
    
    public void StartRecording()
    {
        if (isRecording) return;
        
        try
        {
            bool success = SausageReplaySDK.StartRecording();
            if (!success)
            {
                UpdateStatus("开始录制失败");
            }
        }
        catch (Exception e)
        {
            Debug.LogError($"开始录制异常: {e.Message}");
            UpdateStatus("开始录制异常");
        }
    }
    
    public void StopRecording()
    {
        if (!isRecording) return;
        
        try
        {
            SausageReplaySDK.StopRecording();
        }
        catch (Exception e)
        {
            Debug.LogError($"停止录制异常: {e.Message}");
        }
    }
    
    void UpdateButtonStates()
    {
        if (startButton) startButton.interactable = !isRecording;
        if (stopButton) stopButton.interactable = isRecording;
    }
    
    void UpdateStatus(string message)
    {
        if (statusText) statusText.text = message;
        Debug.Log($"[ReplayManager] {message}");
    }
    
    string FormatDuration(long milliseconds)
    {
        TimeSpan time = TimeSpan.FromMilliseconds(milliseconds);
        return string.Format("{0:D2}:{1:D2}", time.Minutes, time.Seconds);
    }
    
    string FormatFileSize(long bytes)
    {
        if (bytes < 1024) return $"{bytes} B";
        if (bytes < 1024 * 1024) return $"{bytes / 1024.0:F1} KB";
        return $"{bytes / (1024.0 * 1024.0):F1} MB";
    }
    
    void OnDestroy()
    {
        // 清理资源
        if (isRecording)
        {
            SausageReplaySDK.StopRecording();
        }
        SausageReplaySDK.Release();
    }
}
```

#### 3.2 高级功能示例

```csharp
public class AdvancedReplayManager : MonoBehaviour
{
    [Header("质量设置")]
    public VideoQualityPreset[] availablePresets = {
        VideoQualityPreset.Basic,
        VideoQualityPreset.Standard,
        VideoQualityPreset.Smooth,
        VideoQualityPreset.HighFps,
        VideoQualityPreset.Ultra
    };
    
    private VideoQualityPreset currentPreset = VideoQualityPreset.Standard;
    
    void Start()
    {
        // 检查平台支持
        if (!SausageReplaySDK.IsPlatformSupported())
        {
            Debug.LogError("当前平台不支持屏幕录制");
            return;
        }
        
        // 初始化 SDK
        InitializeSDK();
        
        // 检查权限
        CheckPermissions();
    }
    
    void InitializeSDK()
    {
        bool success = SausageReplaySDK.Initialize(currentPreset);
        if (success)
        {
            Debug.Log($"SDK 初始化成功，当前档位: {currentPreset}");
            
            // 获取当前档位信息
            int currentPresetValue = SausageReplaySDK.GetCurrentPreset();
            Debug.Log($"当前档位值: {currentPresetValue}");
        }
    }
    
    void CheckPermissions()
    {
        // 检查麦克风权限
        bool hasMicPermission = SausageReplaySDK.HasMicrophonePermission();
        Debug.Log($"麦克风权限: {hasMicPermission}");
        
        if (!hasMicPermission)
        {
            // 请求麦克风权限
            SausageReplaySDK.RequestMicrophonePermission((granted) =>
            {
                Debug.Log($"麦克风权限请求结果: {granted}");
            });
        }
    }
    
    public void ChangeQualityPreset(int presetIndex)
    {
        if (presetIndex >= 0 && presetIndex < availablePresets.Length)
        {
            currentPreset = availablePresets[presetIndex];
            
            // 重新初始化 SDK
            SausageReplaySDK.Release();
            InitializeSDK();
            
            Debug.Log($"切换到档位: {currentPreset}");
        }
    }
    
    public void GetSystemInfo()
    {
        // 获取内存使用情况
        var memoryUsage = SausageReplaySDK.GetMemoryUsage();
        if (memoryUsage != null)
        {
            Debug.Log($"内存使用: {memoryUsage.usagePercentage}% " +
                     $"({FormatFileSize(memoryUsage.usedMemory)} / {FormatFileSize(memoryUsage.maxMemory)})");
        }
        
        // 获取详细状态
        var detailedStatus = SausageReplaySDK.GetDetailedStatus();
        if (detailedStatus != null)
        {
            Debug.Log($"录制状态: {detailedStatus.status}, " +
                     $"是否录制中: {detailedStatus.isRecording}, " +
                     $"是否暂停: {detailedStatus.isPaused}");
        }
    }
    
    public void ConvertToGif(string videoPath)
    {
        if (SausageReplaySDK.IsGifConversionSupported())
        {
            SausageReplaySDK.ConvertVideoFormat(videoPath, OutputFormat.GIF, (success, outputPath) =>
            {
                if (success)
                {
                    Debug.Log($"GIF 转换成功: {outputPath}");
                }
                else
                {
                    Debug.LogError("GIF 转换失败");
                }
            });
        }
        else
        {
            Debug.LogWarning("当前设备不支持 GIF 转换");
        }
    }
    
    string FormatFileSize(long bytes)
    {
        if (bytes < 1024) return $"{bytes} B";
        if (bytes < 1024 * 1024) return $"{bytes / 1024.0:F1} KB";
        return $"{bytes / (1024.0 * 1024.0):F1} MB";
    }
}
```

### 4. 构建和测试

#### 4.1 构建 iOS 项目

1. 在 Unity 中打开 **File > Build Settings**
2. 选择 **iOS** 平台
3. 点击 **Build** 或 **Build And Run**
4. 选择输出目录

#### 4.2 在 Xcode 中配置

1. 打开生成的 Xcode 项目
2. 在 **Project Navigator** 中确认 `SausageReplay.xcframework` 已正确导入
3. 在 **Build Settings** 中确认：
   - **iOS Deployment Target**: 12.0 或更高
   - **Architectures**: arm64
4. 在 **Info.plist** 中确认权限描述已添加

#### 4.3 测试功能

1. 在真机上运行应用
2. 测试基本录制功能
3. 检查权限请求是否正常
4. 验证录制文件是否生成

## 常见问题

### 1. 编译错误

**问题**: 出现 "Undefined symbols" 错误
**解决方案**: 
- 确认 `SausageReplay.xcframework` 已正确导入
- 检查 Unity 插件目录结构
- 确认桥接文件存在且正确

### 2. 权限问题

**问题**: 录制时提示权限不足
**解决方案**:
- 检查 `Info.plist` 中的权限描述
- 确认在真机上测试（模拟器不支持某些权限）
- 手动在设置中授予权限

### 3. 录制失败

**问题**: 录制无法开始或文件为空
**解决方案**:
- 确认应用在前台运行
- 检查设备存储空间
- 验证 SDK 初始化是否成功
- 查看控制台日志获取详细错误信息

### 4. 性能问题

**问题**: 录制时游戏卡顿
**解决方案**:
- 降低视频清晰度档位
- 减少录制时长
- 优化游戏性能
- 监控内存使用情况

## 最佳实践

1. **错误处理**: 始终检查 API 返回值并实现适当的错误处理
2. **权限管理**: 在录制前检查并请求必要权限
3. **性能优化**: 根据设备性能选择合适的清晰度档位
4. **用户体验**: 提供清晰的录制状态反馈
5. **资源管理**: 及时释放 SDK 资源

## 技术支持

如遇到问题，请：
1. 查看控制台日志
2. 检查设备兼容性
3. 参考 API 文档
4. 联系技术支持团队