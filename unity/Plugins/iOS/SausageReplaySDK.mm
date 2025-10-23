//
//  SausageReplaySDK.mm
//  SausageReplay Unity Bridge
//
//  Created by Waka on 2025/10/10.
//

#import <Foundation/Foundation.h>
#import <ReplayKit/ReplayKit.h>
#import "SausageReplaySDK.h"

// 导入iOS SDK头文件
#import <SausageReplay/SausageReplayIOSSDK.h>
#import <SausageReplay/SRRecordingManager.h>
#import <SausageReplay/SRModels.h>

// Unity回调函数指针类型定义
typedef void (*UnityCallback)();
typedef void (*UnityCallbackWithInt)(int);
typedef void (*UnityCallbackWithString)(const char*);
typedef void (*UnityCallbackWithIntString)(int, const char*);
typedef void (*UnityCallbackWithLongLong)(long long, long long);

// 全局回调函数指针
static UnityCallback g_onRecordingStarted = nullptr;
static UnityCallbackWithLongLong g_onRecordingProgress = nullptr;
static UnityCallbackWithIntString g_onRecordingError = nullptr;

// 录制结果回调
static void (*g_onRecordingStopped)(bool, const char*, long long, float) = nullptr;

// 录制回调实现类
@interface UnityRecordingCallback : NSObject <SRRecordingCallback>
@end

@implementation UnityRecordingCallback

- (void)onRecordingStarted {
    if (g_onRecordingStarted) {
        g_onRecordingStarted();
    }
}

- (void)onRecordingProgress:(long long)durationMs fileSizeBytes:(long long)fileSizeBytes {
    if (g_onRecordingProgress) {
        g_onRecordingProgress(durationMs, fileSizeBytes);
    }
}

- (void)onRecordingStopped:(SRRecordingResult *)result {
    if (g_onRecordingStopped) {
        g_onRecordingStopped(result.isSuccess, 
                           result.filePath.UTF8String, 
                           result.fileSize, 
                           result.duration);
    }
}

- (void)onRecordingError:(NSInteger)errorCode errorMessage:(NSString *)errorMessage {
    if (g_onRecordingError) {
        g_onRecordingError((int)errorCode, errorMessage.UTF8String);
    }
}

@end

// 全局录制回调实例
static UnityRecordingCallback *g_recordingCallback = nil;

// MARK: - 初始化与基础功能

extern "C" bool SausageReplaySDK_Initialize(int preset) {
    SRVideoQualityPreset videoPreset = (SRVideoQualityPreset)preset;
    BOOL success = [SausageReplayIOSSDK initializeWithPreset:videoPreset];
    
    // 创建录制回调实例
    if (!g_recordingCallback) {
        g_recordingCallback = [[UnityRecordingCallback alloc] init];
    }
    
    if (!success) {
        NSLog(@"SausageReplaySDK_Initialize failed");
    }
    
    return success;
}

extern "C" bool SausageReplaySDK_IsPlatformSupported(void) {
    return [SausageReplayIOSSDK isPlatformSupported];
}

extern "C" const char* SausageReplaySDK_GetVersion(void) {
    NSString *version = [SausageReplayIOSSDK version];
    if (version) {
        return strdup(version.UTF8String);
    }
    return strdup("1.0.0");
}

extern "C" void SausageReplaySDK_Release(void) {
    [SausageReplayIOSSDK releaseResources];
    g_recordingCallback = nil;
}

extern "C" int SausageReplaySDK_GetCurrentPreset(void) {
    SRVideoQualityPreset preset = [SausageReplayIOSSDK getCurrentPreset];
    return (int)preset;
}

// MARK: - 录制控制

extern "C" bool SausageReplaySDK_StartRecording(void) {
    return [SRRecordingManager startRecordingWithCallback:g_recordingCallback];
}

extern "C" void SausageReplaySDK_StopRecording(void) {
    [SRRecordingManager stopRecording:^(SRRecordingResult *result) {
        if (g_onRecordingStopped) {
            g_onRecordingStopped(result.isSuccess, 
                               result.filePath.UTF8String, 
                               result.fileSize, 
                               result.duration);
        }
    }];
}

extern "C" int SausageReplaySDK_GetRecordingStatus(void) {
    SRRecordingStatus status = [SRRecordingManager status];
    return (int)status;
}

// MARK: - 质量调整

extern "C" bool SausageReplaySDK_AdjustRecordingQuality(int quality) {
    SRVideoQuality videoQuality = (SRVideoQuality)quality;
    return [SRRecordingManager adjustRecordingQuality:videoQuality];
}

// MARK: - 状态监控

extern "C" const char* SausageReplaySDK_GetDetailedStatus(void) {
    SRDetailedStatus *status = [SRRecordingManager getDetailedStatus];
    
    NSDictionary *statusDict = @{
        @"status": @(status.status),
        @"isRecording": @(status.isRecording),
        @"isPaused": @(status.isPaused),
        @"duration": @(status.duration),
        @"fileSize": @(status.fileSize),
        @"errorCode": @(status.errorCode),
        @"errorMessage": status.errorMessage ?: @""
    };
    
    NSError *error;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:statusDict options:0 error:&error];
    
    if (error) {
        NSLog(@"JSON serialization error: %@", error.localizedDescription);
        return strdup("{}");
    }
    
    NSString *jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    return strdup(jsonString.UTF8String);
}

// MARK: - Unity回调设置

extern "C" void SausageReplaySDK_SetRecordingStartedCallback(UnityCallback callback) {
    g_onRecordingStarted = callback;
}

extern "C" void SausageReplaySDK_SetRecordingProgressCallback(UnityCallbackWithLongLong callback) {
    g_onRecordingProgress = callback;
}

extern "C" void SausageReplaySDK_SetRecordingStoppedCallback(void (*callback)(bool, const char*, long long, float)) {
    g_onRecordingStopped = callback;
}

extern "C" void SausageReplaySDK_SetRecordingErrorCallback(UnityCallbackWithIntString callback) {
    g_onRecordingError = callback;
}