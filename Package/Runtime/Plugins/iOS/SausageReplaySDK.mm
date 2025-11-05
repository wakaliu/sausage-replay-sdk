//  SausageReplaySDK.mm
#import <Foundation/Foundation.h>
#import <ReplayKit/ReplayKit.h>
#import "SausageReplaySDK.h"
#import <SausageReplay/SausageReplayIOSSDK.h>
#import <SausageReplay/SRRecordingManager.h>
#import <SausageReplay/SRModels.h>

typedef void (*UnityCallback)();
typedef void (*UnityCallbackWithString)(const char*);
typedef void (*UnityCallbackWithIntString)(int, const char*);
typedef void (*UnityCallbackWithLongLong)(long long, long long);

static UnityCallback g_onRecordingStarted = nullptr;
static UnityCallbackWithLongLong g_onRecordingProgress = nullptr;
static UnityCallbackWithString g_onRecordingStopped = nullptr;
static UnityCallbackWithIntString g_onRecordingError = nullptr;

@interface UnityRecordingCallback : NSObject <SRRecordingCallback>
@end

@implementation UnityRecordingCallback
- (void)onRecordingStarted { if (g_onRecordingStarted) g_onRecordingStarted(); }
- (void)onRecordingProgress:(long long)durationMs fileSizeBytes:(long long)fileSizeBytes { if (g_onRecordingProgress) g_onRecordingProgress(durationMs, fileSizeBytes); }
- (void)onRecordingStopped:(SRRecordingResult *)result {
    if (!g_onRecordingStopped) return;
    NSDictionary *resultDict = @{ @"isSuccess": @(result.isSuccess), @"filePath": result.filePath ?: @"", @"fileSize": @(result.fileSize), @"duration": @(result.duration), @"fileMd5": result.fileMd5 ?: @"", @"assetLocalId": result.assetLocalId ?: @"", @"errorCode": @(result.errorCode), @"errorMessage": result.errorMessage ?: @"" };
    NSError *error; NSData *jsonData = [NSJSONSerialization dataWithJSONObject:resultDict options:0 error:&error]; if (error) return;
    NSString *jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding]; char *cString = strdup([jsonString UTF8String]); g_onRecordingStopped(cString); free(cString);
}
- (void)onRecordingError:(NSInteger)errorCode errorMessage:(NSString *)errorMessage { if (g_onRecordingError) g_onRecordingError((int)errorCode, errorMessage.UTF8String); }
@end

static UnityRecordingCallback *g_recordingCallback = nil;

extern "C" bool SausageReplaySDK_Initialize(int preset, bool enableDebugLog) {
    SRVideoQualityPreset videoPreset = (SRVideoQualityPreset)preset;
    BOOL success = [SausageReplayIOSSDK initializeWithPreset:videoPreset enableDebugLog:enableDebugLog];
    if (!g_recordingCallback) g_recordingCallback = [[UnityRecordingCallback alloc] init];
    return success;
}
extern "C" bool SausageReplaySDK_IsPlatformSupported(void) { return [SausageReplayIOSSDK isPlatformSupported]; }
extern "C" const char* SausageReplaySDK_GetVersion(void) { NSString *version = [SausageReplayIOSSDK version]; return strdup(version ? version.UTF8String : "1.0.0"); }
extern "C" void SausageReplaySDK_Release(void) { [SausageReplayIOSSDK releaseResources]; g_recordingCallback = nil; }
extern "C" int SausageReplaySDK_GetCurrentPreset(void) { return (int)[SausageReplayIOSSDK getCurrentPreset]; }
extern "C" bool SausageReplaySDK_StartRecording(void) { return [SRRecordingManager startRecordingWithCallback:g_recordingCallback]; }
extern "C" void SausageReplaySDK_StopRecording(void) {
    [SRRecordingManager stopRecording:^(SRRecordingResult *result) {
        // 将 stop completion 的结果转发给 Unity（与 onRecordingStopped 一致的 JSON 格式）
        if (g_onRecordingStopped) {
            NSDictionary *resultDict = @{
                @"isSuccess": @(result.isSuccess),
                @"filePath": result.filePath ?: @"",
                @"fileSize": @(result.fileSize),
                @"duration": @(result.duration),
                @"fileMd5": result.fileMd5 ?: @"",
                @"assetLocalId": result.assetLocalId ?: @"",
                @"errorCode": @(result.errorCode),
                @"errorMessage": result.errorMessage ?: @""
            };
            NSError *error = nil;
            NSData *jsonData = [NSJSONSerialization dataWithJSONObject:resultDict options:0 error:&error];
            if (jsonData && !error) {
                NSString *jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
                char *cString = strdup([jsonString UTF8String]);
                g_onRecordingStopped(cString);
                free(cString);
            } else {
                const char *fallback = "{\"isSuccess\":false,\"errorCode\":-1,\"errorMessage\":\"serialization error\"}";
                g_onRecordingStopped(strdup(fallback));
            }
        }
    }];
}
extern "C" int SausageReplaySDK_GetRecordingStatus(void) { return (int)[SRRecordingManager status]; }
extern "C" const char* SausageReplaySDK_GetDetailedStatus(void) {
    SRDetailedStatus *status = [SRRecordingManager getDetailedStatus]; if (!status) return strdup("{}");
    NSDictionary *statusDict = @{ @"status": @(status.status), @"isRecording": @(status.isRecording), @"duration": @(status.duration), @"fileSize": @(status.fileSize), @"errorCode": @(status.errorCode), @"errorMessage": status.errorMessage ?: @"" };
    NSError *error; NSData *jsonData = [NSJSONSerialization dataWithJSONObject:statusDict options:0 error:&error]; if (error) return strdup("{}");
    NSString *jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding]; return strdup(jsonString.UTF8String);
}
extern "C" void SausageReplaySDK_SetRecordingStartedCallback(UnityCallback callback) { g_onRecordingStarted = callback; }
extern "C" void SausageReplaySDK_SetRecordingProgressCallback(UnityCallbackWithLongLong callback) { g_onRecordingProgress = callback; }
extern "C" void SausageReplaySDK_SetRecordingStoppedCallback(UnityCallbackWithString callback) { g_onRecordingStopped = callback; }
extern "C" void SausageReplaySDK_SetRecordingErrorCallback(UnityCallbackWithIntString callback) { g_onRecordingError = callback; }


