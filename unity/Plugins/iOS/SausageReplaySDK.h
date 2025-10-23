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

/// 开始录制（使用初始化时设置的视频清晰度参数）
/// @return 是否开始成功
bool SausageReplaySDK_StartRecording(void);

/// 停止录制
void SausageReplaySDK_StopRecording(void);

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

#ifdef __cplusplus
}
#endif

#endif /* SausageReplaySDK_h */