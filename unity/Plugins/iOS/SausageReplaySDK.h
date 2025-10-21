//
//  SausageReplaySDK.h
//  SausageReplay Unity Bridge
//
//  Created by Waka on 2025/10/10.
//

#ifndef SausageReplaySDK_h
#define SausageReplaySDK_h

#ifdef __cplusplus
extern "C" {
#endif

// MARK: - 初始化与基础功能

/// 初始化SDK
/// @param preset 视频清晰度档位 (0=Basic, 1=Standard, 2=Smooth, 3=HighFps, 4=Ultra)
/// @return 是否初始化成功
bool SausageReplaySDK_Initialize(int preset);

/// 使用设备性能档位初始化SDK（兼容性方法）
/// @param tier 设备性能档位 (0=MidRange, 1=HighEnd)
/// @return 是否初始化成功
bool SausageReplaySDK_InitializeWithTier(int tier);

/// 检查平台支持
/// @return 是否支持屏幕录制
bool SausageReplaySDK_IsPlatformSupported(void);

/// 获取SDK版本
/// @return 版本字符串
const char* SausageReplaySDK_GetVersion(void);

/// 释放SDK资源
void SausageReplaySDK_Release(void);

/// 获取当前视频清晰度档位
/// @return 当前档位
int SausageReplaySDK_GetCurrentPreset(void);

// MARK: - 录制控制

/// 开始录制
/// @param configJson 录制配置JSON字符串
/// @return 是否开始成功
bool SausageReplaySDK_StartRecording(const char* configJson);

/// 停止录制
void SausageReplaySDK_StopRecording(void);

/// 暂停录制
/// @return 是否暂停成功
bool SausageReplaySDK_PauseRecording(void);

/// 恢复录制
/// @return 是否恢复成功
bool SausageReplaySDK_ResumeRecording(void);

/// 获取录制状态
/// @return 录制状态 (0=Idle, 1=Starting, 2=Recording, 3=Paused, 4=Stopping)
int SausageReplaySDK_GetRecordingStatus(void);

// MARK: - 质量调整

/// 调整录制质量
/// @param quality 目标质量 (0=LOW, 1=MEDIUM, 2=HIGH)
/// @return 是否调整成功
bool SausageReplaySDK_AdjustRecordingQuality(int quality);

// MARK: - 状态监控

/// 获取详细状态
/// @return 详细状态JSON字符串
const char* SausageReplaySDK_GetDetailedStatus(void);

/// 获取内存使用情况
/// @return 内存使用JSON字符串
const char* SausageReplaySDK_GetMemoryUsage(void);

// MARK: - 错误恢复

/// 从错误中恢复
/// @return 是否恢复成功
bool SausageReplaySDK_RecoverFromError(void);

/// 重置状态
void SausageReplaySDK_ResetStatus(void);

// MARK: - 设备信息

/// 获取设备档位信息
/// @return 设备信息JSON字符串
const char* SausageReplaySDK_GetDeviceTierInfo(void);

// MARK: - 格式转换

/// 检查GIF转换支持
/// @return 是否支持GIF转换
bool SausageReplaySDK_IsGifConversionSupported(void);

/// 获取GIF转换参数
/// @return GIF转换参数JSON字符串
const char* SausageReplaySDK_GetGifConversionParams(void);

/// 重新加载设备档位配置
/// @return 是否重新加载成功
bool SausageReplaySDK_ReloadDeviceTierConfig(void);

/// 转换视频格式
/// @param inputPath 输入文件路径
/// @param outputFormat 输出格式 (0=MP4, 1=GIF, 2=WEBM, 3=AVI)
/// @param callback 转换完成回调
void SausageReplaySDK_ConvertVideoFormat(const char* inputPath, int outputFormat, void* callback);

// MARK: - 权限管理

/// 检查麦克风权限
/// @return 是否有麦克风权限
bool SausageReplaySDK_HasMicrophonePermission(void);

/// 请求麦克风权限
/// @param callback 权限请求回调
void SausageReplaySDK_RequestMicrophonePermission(void* callback);

// MARK: - Unity回调注册

/// 注册录制开始回调
void SausageReplaySDK_RegisterOnRecordingStarted(void (*callback)(void));

/// 注册录制进度回调
void SausageReplaySDK_RegisterOnRecordingProgress(void (*callback)(long long, long long));

/// 注册录制暂停回调
void SausageReplaySDK_RegisterOnRecordingPaused(void (*callback)(void));

/// 注册录制恢复回调
void SausageReplaySDK_RegisterOnRecordingResumed(void (*callback)(void));

/// 注册录制停止回调
void SausageReplaySDK_RegisterOnRecordingStopped(void (*callback)(bool, const char*, long long, float));

/// 注册录制错误回调
void SausageReplaySDK_RegisterOnRecordingError(void (*callback)(int, const char*));

/// 注册质量调整回调
void SausageReplaySDK_RegisterOnRecordingQualityAdjusted(void (*callback)(int));

/// 注册转换完成回调
void SausageReplaySDK_RegisterOnConvertCompleted(void (*callback)(bool, const char*));

#ifdef __cplusplus
}
#endif

#endif /* SausageReplaySDK_h */
