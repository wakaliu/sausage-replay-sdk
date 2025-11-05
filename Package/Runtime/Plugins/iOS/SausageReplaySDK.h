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

bool SausageReplaySDK_Initialize(int preset, bool enableDebugLog);
bool SausageReplaySDK_IsPlatformSupported(void);
const char* SausageReplaySDK_GetVersion(void);
void SausageReplaySDK_Release(void);
int SausageReplaySDK_GetCurrentPreset(void);
bool SausageReplaySDK_StartRecording(void);
void SausageReplaySDK_StopRecording(void);
int SausageReplaySDK_GetRecordingStatus(void);
const char* SausageReplaySDK_GetDetailedStatus(void);
void SausageReplaySDK_SetRecordingStartedCallback(void (*callback)());
void SausageReplaySDK_SetRecordingProgressCallback(void (*callback)(long long, long long));
void SausageReplaySDK_SetRecordingStoppedCallback(void (*callback)(const char*));
void SausageReplaySDK_SetRecordingErrorCallback(void (*callback)(int, const char*));

#ifdef __cplusplus
}
#endif

#endif /* SausageReplaySDK_h */


