# iOS Unity Bridge

## 概述

这个目录包含了Sausage Replay iOS SDK的Unity桥接文件，用于在Unity项目中集成iOS屏幕录制功能。

## 文件说明

### SausageReplaySDK.h
iOS桥接头文件，定义了所有Unity可以调用的C函数接口。

### SausageReplaySDK.mm
iOS桥接实现文件，实现了Unity与iOS SDK之间的通信。

## 集成方法

### 1. 复制文件到Unity项目

将以下文件复制到您的Unity项目中：

```
Assets/Plugins/iOS/
├── SausageReplaySDK.h
├── SausageReplaySDK.mm
└── SausageReplay.xcframework
```

### 2. 配置Unity项目

在Unity的Player Settings中：

- 设置Target minimum iOS Version为12.0
- 添加必要的权限描述
- 确保Scripting Backend设置为IL2CPP

### 3. 使用SDK

```csharp
using SausageReplay;

// 初始化SDK
bool success = SausageReplaySDK.Initialize(VideoQualityPreset.Standard);

// 开始录制
var config = new RecordingConfig
{
    QualityPreset = VideoQualityPreset.Standard,
    IncludeAudio = true,
    MaxDurationSeconds = 60
};
SausageReplaySDK.StartRecording(config);

// 停止录制
SausageReplaySDK.StopRecording();
```

## 注意事项

1. **真机测试**: 屏幕录制功能只能在真机上使用，模拟器不支持
2. **权限配置**: 确保在Info.plist中配置了必要的权限描述
3. **框架依赖**: 确保项目中包含了ReplayKit等必要的系统框架
4. **iOS版本**: 最低支持iOS 12.0

## 技术支持

如有问题，请参考Unity iOS集成指南或联系技术支持团队。
