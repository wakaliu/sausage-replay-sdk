# iOS SDK 接入指南

## 概述

Sausage Replay iOS SDK 是一个专为iOS平台设计的屏幕录制SDK，基于Apple的ReplayKit框架构建，提供高质量的屏幕录制功能。

## 系统要求

- **iOS版本**: iOS 12.0+
- **开发语言**: Objective-C / Swift
- **架构支持**: arm64 (真机), x86_64 (模拟器)
- **Xcode版本**: Xcode 12.0+
- **部署目标**: iOS 12.0+

## 快速开始

### 1. 集成SDK

#### 方式一：XCFramework集成（推荐）

1. 将 `SausageReplay.xcframework` 添加到您的Xcode项目中
2. 在项目设置中确保 `Embed & Sign` 选项已启用
3. 添加必要的系统框架依赖

#### 方式二：源码集成

1. 将 `ios/SausageReplay/` 目录下的所有源文件添加到您的项目中
2. 确保所有依赖的系统框架已正确链接

### 2. 添加系统框架依赖

在项目设置中添加以下系统框架：

```
ReplayKit.framework
AVFoundation.framework
Photos.framework
PhotosUI.framework
```

### 3. 配置权限

在 `Info.plist` 中添加必要的权限描述：

```xml
<key>NSMicrophoneUsageDescription</key>
<string>需要访问麦克风来录制音频</string>

<key>NSPhotoLibraryAddUsageDescription</key>
<string>需要访问相册权限来保存录制的视频</string>

<key>NSPhotoLibraryUsageDescription</key>
<string>需要访问相册权限来保存录制的视频</string>
```

## API 使用指南

### 1. 初始化SDK

```objc
#import <SausageReplay/SausageReplayIOSSDK.h>

// 使用视频清晰度档位初始化（推荐）
BOOL success = [SausageReplayIOSSDK initializeWithPreset:SRVideoQualityPresetStandard];

// 或使用设备性能档位初始化（兼容性）
BOOL success = [SausageReplayIOSSDK initializeWithTier:SRDevicePerformanceTierMidRange];
```

### 2. 检查平台支持

```objc
BOOL isSupported = [SausageReplayIOSSDK isPlatformSupported];
if (!isSupported) {
    NSLog(@"当前设备不支持屏幕录制");
}
```

### 3. 权限管理

```objc
#import <SausageReplay/SRPermissionManager.h>

// 检查麦克风权限
BOOL hasPermission = [SRPermissionManager hasMicrophonePermission];

// 请求麦克风权限
[SRPermissionManager requestMicrophonePermission:^(BOOL granted) {
    if (granted) {
        NSLog(@"麦克风权限已授权");
    } else {
        NSLog(@"麦克风权限被拒绝");
    }
}];
```

### 4. 开始录制

```objc
#import <SausageReplay/SRRecordingManager.h>
#import <SausageReplay/SRModels.h>

// 创建录制配置
SRRecordingConfig *config = [SRRecordingConfig defaultConfig];
config.qualityPreset = SRVideoQualityPresetStandard; // 设置清晰度档位
config.includeAudio = YES; // 包含音频
config.maxDurationSeconds = 60; // 最大录制时长

// 开始录制
BOOL success = [SRRecordingManager startRecordingWithConfig:config callback:self];
```

### 5. 录制控制

```objc
// 暂停录制
BOOL success = [SRRecordingManager pauseRecording];

// 恢复录制
BOOL success = [SRRecordingManager resumeRecording];

// 停止录制
[SRRecordingManager stopRecording:^(SRRecordingResult *result) {
    if (result.isSuccess) {
        NSLog(@"录制成功，文件路径: %@", result.filePath);
        NSLog(@"文件大小: %lld bytes", result.fileSize);
        NSLog(@"录制时长: %.1f 秒", result.duration);
    } else {
        NSLog(@"录制失败: %@", result.errorMessage);
    }
}];
```

### 6. 实现录制回调

```objc
@interface YourViewController : UIViewController <SRRecordingCallback>
@end

@implementation YourViewController

- (void)onRecordingStarted {
    NSLog(@"录制开始");
}

- (void)onRecordingProgress:(long long)durationMs fileSizeBytes:(long long)fileSizeBytes {
    NSLog(@"录制进度: %lld ms, 文件大小: %lld bytes", durationMs, fileSizeBytes);
}

- (void)onRecordingPaused {
    NSLog(@"录制暂停");
}

- (void)onRecordingResumed {
    NSLog(@"录制恢复");
}

- (void)onRecordingStopped:(SRRecordingResult *)result {
    if (result.isSuccess) {
        NSLog(@"录制完成: %@", result.filePath);
    } else {
        NSLog(@"录制失败: %@", result.errorMessage);
    }
}

- (void)onRecordingError:(NSInteger)errorCode errorMessage:(NSString *)errorMessage {
    NSLog(@"录制错误: %ld - %@", (long)errorCode, errorMessage);
}

- (void)onRecordingQualityAdjusted:(SRVideoQuality)quality {
    NSLog(@"质量已调整: %ld", (long)quality);
}

@end
```

## 视频清晰度档位

SDK提供5个预设的视频清晰度档位：

| 档位 | 分辨率 | 帧率 | 比特率 | 适用场景 |
|------|--------|------|--------|----------|
| Basic | 720p | 30fps | 2 Mbps | 低端设备，网络传输 |
| Standard | 1080p | 30fps | 4 Mbps | 标准录制，平衡质量与性能 |
| Smooth | 720p | 60fps | 3 Mbps | 流畅录制，游戏场景 |
| HighFps | 1080p | 60fps | 6 Mbps | 高质量流畅录制 |
| Ultra | 1440p | 30/60fps | 8 Mbps | 超高清录制，高端设备 |

### 档位选择建议

```objc
// 根据设备性能选择档位
if ([self isHighEndDevice]) {
    config.qualityPreset = SRVideoQualityPresetUltra;
} else if ([self isMidRangeDevice]) {
    config.qualityPreset = SRVideoQualityPresetStandard;
} else {
    config.qualityPreset = SRVideoQualityPresetBasic;
}
```

## 高级功能

### 1. 获取设备信息

```objc
SRDeviceTierInfo *tierInfo = [SausageReplayIOSSDK getDeviceTierInfo];
NSLog(@"设备档位: %@", tierInfo.tierName);
NSLog(@"最大分辨率: %ldx%ld", (long)tierInfo.maxWidth, (long)tierInfo.maxHeight);
NSLog(@"目标帧率: %ld", (long)tierInfo.targetFps);
NSLog(@"视频比特率: %lld", tierInfo.videoBitrate);
```

### 2. 内存监控

```objc
SRMemoryUsage *memoryUsage = [SausageReplayIOSSDK getMemoryUsage];
NSLog(@"内存使用: %.1f MB / %.1f MB (%.1f%%)",
      memoryUsage.usedMemory / 1024.0 / 1024.0,
      memoryUsage.maxMemory / 1024.0 / 1024.0,
      memoryUsage.usagePercentage);
```

### 3. 错误恢复

```objc
BOOL recovered = [SRRecordingManager recoverFromError];
if (recovered) {
    NSLog(@"错误恢复成功");
} else {
    NSLog(@"错误恢复失败，需要重新初始化");
}
```

### 4. 格式转换

```objc
[SRRecordingManager convertVideoFormat:@"input.mp4"
                          outputFormat:SROutputFormatGIF
                              callback:^(BOOL success, NSString *outputPath) {
    if (success) {
        NSLog(@"转换成功: %@", outputPath);
    } else {
        NSLog(@"转换失败");
    }
}];
```

## 注意事项

### 1. ReplayKit限制

- 录制过程中无法直接访问视频文件
- 停止录制后会显示系统预览界面
- 用户需要通过预览界面保存视频到相册

### 2. 权限要求

- 麦克风权限：录制音频时必需
- 相册权限：保存视频到相册时必需
- 屏幕录制权限：由系统自动处理

### 3. 性能考虑

- 录制会消耗CPU和内存资源
- 建议在录制前检查设备性能
- 长时间录制可能影响应用性能

### 4. 文件管理

- 录制的视频文件保存在应用沙盒中
- 需要定期清理临时文件
- 大文件可能占用较多存储空间

## 错误处理

### 常见错误码

| 错误码 | 描述 | 解决方案 |
|--------|------|----------|
| 2000 | 录制已在进行中 | 等待当前录制完成 |
| 2001 | 录制未开始 | 先调用开始录制 |
| 2002 | 录制已在进行中 | 检查录制状态 |
| 2003 | 屏幕录制不可用 | 检查设备支持 |
| 2004 | 录制失败 | 检查权限和配置 |

### 错误处理示例

```objc
- (void)onRecordingError:(NSInteger)errorCode errorMessage:(NSString *)errorMessage {
    switch (errorCode) {
        case 2000:
            NSLog(@"录制已在进行中，请等待完成");
            break;
        case 2001:
            NSLog(@"请先开始录制");
            break;
        case 2003:
            NSLog(@"设备不支持屏幕录制");
            break;
        case 2004:
            NSLog(@"录制失败: %@", errorMessage);
            break;
        default:
            NSLog(@"未知错误: %ld - %@", (long)errorCode, errorMessage);
            break;
    }
}
```

## 示例项目

参考 `ios/Demo/` 目录下的示例项目，了解完整的使用方法。

## 技术支持

如有问题，请联系技术支持团队或查看项目文档。

## 更新日志

### v1.0.0
- 初始版本发布
- 支持基本的屏幕录制功能
- 支持5个视频清晰度档位
- 支持音频录制
- 支持暂停/恢复功能
