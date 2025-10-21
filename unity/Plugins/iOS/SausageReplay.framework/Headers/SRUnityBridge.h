//
//  SRUnityBridge.h
//  SausageReplay
//
//  Created by Waka on 2025/10/10.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * Unity桥接层
 * 提供C函数接口供Unity调用
 */
@interface SRUnityBridge : NSObject

@end

// MARK: - C函数导出接口

#ifdef __cplusplus
extern "C" {
#endif

// SDK管理
bool SausageReplaySDK_Initialize(int preset);
bool SausageReplaySDK_InitializeWithTier(int tier); // 兼容旧版本
bool SausageReplaySDK_IsPlatformSupported(void);
const char* SausageReplaySDK_GetVersion(void);
void SausageReplaySDK_Release(void);
int SausageReplaySDK_GetCurrentPreset(void);

// 录制控制
bool SausageReplaySDK_StartRecording(const char* configJson);
void SausageReplaySDK_StopRecording(void);
bool SausageReplaySDK_PauseRecording(void);
bool SausageReplaySDK_ResumeRecording(void);
int SausageReplaySDK_GetRecordingStatus(void);
bool SausageReplaySDK_AdjustRecordingQuality(int quality);

// 状态查询
const char* SausageReplaySDK_GetDetailedStatus(void);
const char* SausageReplaySDK_GetMemoryUsage(void);
bool SausageReplaySDK_RecoverFromError(void);
void SausageReplaySDK_ResetStatus(void);

// 高级功能
const char* SausageReplaySDK_GetDeviceTierInfo(void);
bool SausageReplaySDK_IsGifConversionSupported(void);
const char* SausageReplaySDK_GetGifConversionParams(void);
bool SausageReplaySDK_ReloadDeviceTierConfig(void);

// 格式转换
void SausageReplaySDK_ConvertVideoFormat(const char* inputPath, int outputFormat, void(*callback)(bool success, const char* outputPath));

// 权限管理
bool SausageReplaySDK_HasMicrophonePermission(void);
void SausageReplaySDK_RequestMicrophonePermission(void(*callback)(bool granted, int errorCode, const char* message));

#ifdef __cplusplus
}
#endif

NS_ASSUME_NONNULL_END
