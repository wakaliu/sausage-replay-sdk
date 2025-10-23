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
bool SausageReplaySDK_IsPlatformSupported(void);
const char* SausageReplaySDK_GetVersion(void);
void SausageReplaySDK_Release(void);
int SausageReplaySDK_GetCurrentPreset(void);

// 录制控制
bool SausageReplaySDK_StartRecording(const char* configJson);
void SausageReplaySDK_StopRecording(void);
int SausageReplaySDK_GetRecordingStatus(void);
bool SausageReplaySDK_AdjustRecordingQuality(int quality);

// 状态查询
const char* SausageReplaySDK_GetDetailedStatus(void);

#ifdef __cplusplus
}
#endif

NS_ASSUME_NONNULL_END
