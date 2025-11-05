//
//  SRUnityBridge.m
//  SausageReplay
//
//  Created by Waka on 2025/10/10.
//

#import "SRUnityBridge.h"
#import "SausageReplayIOSSDK.h"
#import "SRRecordingManager.h"
#import "SRModels.h"

// 全局回调存储
static void(*_recordingCallback)(const char* eventType, const char* data) = NULL;

// 录制回调实现
@interface SRUnityRecordingCallback : NSObject <SRRecordingCallback>
@end

@implementation SRUnityRecordingCallback

- (void)onRecordingStarted {
    if (_recordingCallback) {
        _recordingCallback("onRecordingStarted", "");
    }
}

- (void)onRecordingProgress:(long long)durationMs fileSizeBytes:(long long)fileSizeBytes {
    if (_recordingCallback) {
        NSDictionary *data = @{
            @"durationMs": @(durationMs),
            @"fileSizeBytes": @(fileSizeBytes)
        };
        NSData *jsonData = [NSJSONSerialization dataWithJSONObject:data options:0 error:nil];
        NSString *jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
        _recordingCallback("onRecordingProgress", [jsonString UTF8String]);
    }
}


- (void)onRecordingStopped:(SRRecordingResult *)result {
    if (_recordingCallback) {
        NSDictionary *data = @{
            @"isSuccess": @(result.isSuccess),
            @"filePath": result.filePath ?: @"",
            @"fileSize": @(result.fileSize),
            @"duration": @(result.duration),
            @"fileMd5": result.fileMd5 ?: @"",
            @"assetLocalId": result.assetLocalId ?: @"",
            @"errorCode": @(result.errorCode),
            @"errorMessage": result.errorMessage ?: @""
        };
        NSData *jsonData = [NSJSONSerialization dataWithJSONObject:data options:0 error:nil];
        NSString *jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
        _recordingCallback("onRecordingStopped", [jsonString UTF8String]);
    }
}

- (void)onRecordingError:(NSInteger)errorCode errorMessage:(nullable NSString *)errorMessage {
    if (_recordingCallback) {
        NSDictionary *data = @{
            @"errorCode": @(errorCode),
            @"errorMessage": errorMessage ?: @""
        };
        NSData *jsonData = [NSJSONSerialization dataWithJSONObject:data options:0 error:nil];
        NSString *jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
        _recordingCallback("onRecordingError", [jsonString UTF8String]);
    }
}


@end

static SRUnityRecordingCallback *_unityCallback = nil;

// 辅助函数
static NSString* _Nullable createJSONString(id object) {
    if (!object) return nil;
    
    NSError *error;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:object options:0 error:&error];
    if (error) {
        NSLog(@"JSON serialization error: %@", error.localizedDescription);
        return nil;
    }
    
    return [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
}

static char* _Nullable createCString(NSString *string) {
    if (!string) return NULL;
    
    const char *cString = [string UTF8String];
    size_t length = strlen(cString) + 1;
    char *result = malloc(length);
    if (result) {
        strcpy(result, cString);
    }
    return result;
}

// MARK: - C函数实现

bool SausageReplaySDK_Initialize(int preset) {
    SRVideoQualityPreset videoPreset = (SRVideoQualityPreset)preset;
    return [SausageReplayIOSSDK initializeWithPreset:videoPreset];
}


bool SausageReplaySDK_IsPlatformSupported(void) {
    return [SausageReplayIOSSDK isPlatformSupported];
}

const char* SausageReplaySDK_GetVersion(void) {
    NSString *version = [SausageReplayIOSSDK version];
    return createCString(version);
}

void SausageReplaySDK_Release(void) {
    [SausageReplayIOSSDK releaseResources];
}

int SausageReplaySDK_GetCurrentPreset(void) {
    return (int)[SausageReplayIOSSDK getCurrentPreset];
}

bool SausageReplaySDK_StartRecording(void) {
    // 创建Unity回调
    if (!_unityCallback) {
        _unityCallback = [[SRUnityRecordingCallback alloc] init];
    }
    
    // 无参版本：使用SDK默认配置（仅MP4，自动保存相册）
    return [SRRecordingManager startRecordingWithCallback:_unityCallback];
}

void SausageReplaySDK_StopRecording(void) {
    [SRRecordingManager stopRecording:^(SRRecordingResult *result) {
        // 回调已在SRUnityRecordingCallback中处理
    }];
}


int SausageReplaySDK_GetRecordingStatus(void) {
    return (int)[SRRecordingManager status];
}

bool SausageReplaySDK_AdjustRecordingQuality(int quality) {
    SRVideoQuality videoQuality = (SRVideoQuality)quality;
    return [SRRecordingManager adjustRecordingQuality:videoQuality];
}

const char* SausageReplaySDK_GetDetailedStatus(void) {
    SRDetailedStatus *status = [SRRecordingManager getDetailedStatus];
    if (!status) {
        return createCString(@"{}");
    }
    
    NSDictionary *statusDict = @{
        @"status": @(status.status),
        @"isRecording": @(status.isRecording),
        @"isPaused": @(status.isPaused),
        @"duration": @(status.duration),
        @"fileSize": @(status.fileSize),
        @"errorCode": @(status.errorCode),
        @"errorMessage": status.errorMessage ?: @""
    };
    
    NSString *jsonString = createJSONString(statusDict);
    return createCString(jsonString);
}


