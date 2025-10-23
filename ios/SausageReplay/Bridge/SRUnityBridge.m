//
//  SRUnityBridge.m
//  SausageReplay
//
//  Created by Waka on 2025/10/10.
//

#import "SRUnityBridge.h"
#import "SausageReplayIOSSDK.h"
#import "SRRecordingManager.h"
#import "SRPermissionManager.h"
#import "SRFileManager.h"
#import "SRModels.h"

// 全局回调存储
static void(*_recordingCallback)(const char* eventType, const char* data) = NULL;
static void(*_permissionCallback)(bool granted, int errorCode, const char* message) = NULL;
static void(*_conversionCallback)(bool success, const char* outputPath) = NULL;

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

- (void)onRecordingPaused {
    if (_recordingCallback) {
        _recordingCallback("onRecordingPaused", "");
    }
}

- (void)onRecordingResumed {
    if (_recordingCallback) {
        _recordingCallback("onRecordingResumed", "");
    }
}

- (void)onRecordingStopped:(SRRecordingResult *)result {
    if (_recordingCallback) {
        NSDictionary *data = @{
            @"isSuccess": @(result.isSuccess),
            @"filePath": result.filePath ?: @"",
            @"fileSize": @(result.fileSize),
            @"duration": @(result.duration),
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

- (void)onRecordingQualityAdjusted:(SRVideoQuality)quality {
    if (_recordingCallback) {
        NSDictionary *data = @{
            @"quality": @(quality)
        };
        NSData *jsonData = [NSJSONSerialization dataWithJSONObject:data options:0 error:nil];
        NSString *jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
        _recordingCallback("onRecordingQualityAdjusted", [jsonString UTF8String]);
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

bool SausageReplaySDK_StartRecording(const char* configJson) {
    if (!configJson) {
        return false;
    }
    
    NSString *jsonString = [NSString stringWithUTF8String:configJson];
    NSData *jsonData = [jsonString dataUsingEncoding:NSUTF8StringEncoding];
    
    NSError *error;
    NSDictionary *configDict = [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:&error];
    if (error) {
        NSLog(@"Failed to parse config JSON: %@", error.localizedDescription);
        return false;
    }
    
    // 创建配置对象
    SRRecordingConfig *config = [SRRecordingConfig defaultConfig];
    
    // 解析配置参数
    if (configDict[@"qualityPreset"]) {
        config.qualityPreset = [configDict[@"qualityPreset"] integerValue];
    }
    if (configDict[@"maxDurationSeconds"]) {
        config.maxDurationSeconds = [configDict[@"maxDurationSeconds"] integerValue];
    }
    if (configDict[@"maxFileSizeBytes"]) {
        config.maxFileSizeBytes = [configDict[@"maxFileSizeBytes"] longLongValue];
    }
    if (configDict[@"includeAudio"]) {
        config.includeAudio = [configDict[@"includeAudio"] boolValue];
    }
    if (configDict[@"outputFormat"]) {
        config.outputFormat = [configDict[@"outputFormat"] integerValue];
    }
    if (configDict[@"outputPath"]) {
        config.outputPath = configDict[@"outputPath"];
    }
    if (configDict[@"targetBitrate"]) {
        config.targetBitrate = configDict[@"targetBitrate"];
    }
    if (configDict[@"targetFps"]) {
        config.targetFps = [configDict[@"targetFps"] integerValue];
    }
    
    // 创建Unity回调
    if (!_unityCallback) {
        _unityCallback = [[SRUnityRecordingCallback alloc] init];
    }
    
    return [SRRecordingManager startRecordingWithConfig:config callback:_unityCallback];
}

void SausageReplaySDK_StopRecording(void) {
    [SRRecordingManager stopRecording:^(SRRecordingResult *result) {
        // 回调已在SRUnityRecordingCallback中处理
    }];
}

bool SausageReplaySDK_PauseRecording(void) {
    return [SRRecordingManager pauseRecording];
}

bool SausageReplaySDK_ResumeRecording(void) {
    return [SRRecordingManager resumeRecording];
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
        @"hasProjection": @(status.hasProjection),
        @"hasRecorder": @(status.hasRecorder),
        @"hasDisplay": @(status.hasDisplay),
        @"outputFile": status.outputFile ?: @"",
        @"outputFileSize": @(status.outputFileSize)
    };
    
    NSString *jsonString = createJSONString(statusDict);
    return createCString(jsonString);
}

const char* SausageReplaySDK_GetMemoryUsage(void) {
    SRMemoryUsage *memoryUsage = [SausageReplayIOSSDK getMemoryUsage];
    if (!memoryUsage) {
        return createCString(@"{}");
    }
    
    NSDictionary *memoryDict = @{
        @"totalMemory": @(memoryUsage.totalMemory),
        @"usedMemory": @(memoryUsage.usedMemory),
        @"freeMemory": @(memoryUsage.freeMemory),
        @"maxMemory": @(memoryUsage.maxMemory),
        @"usagePercentage": @(memoryUsage.usagePercentage)
    };
    
    NSString *jsonString = createJSONString(memoryDict);
    return createCString(jsonString);
}

bool SausageReplaySDK_RecoverFromError(void) {
    return [SRRecordingManager recoverFromError];
}

void SausageReplaySDK_ResetStatus(void) {
    [SRRecordingManager resetStatus];
}


bool SausageReplaySDK_IsGifConversionSupported(void) {
    return [SausageReplayIOSSDK isGifConversionSupported];
}

const char* SausageReplaySDK_GetGifConversionParams(void) {
    SRGifConversionParams *params = [SausageReplayIOSSDK getGifConversionParams];
    if (!params) {
        return createCString(@"{}");
    }
    
    NSDictionary *paramsDict = @{
        @"maxFps": @(params.maxFps),
        @"maxWidth": @(params.maxWidth),
        @"maxHeight": @(params.maxHeight),
        @"maxDurationSeconds": @(params.maxDurationSeconds)
    };
    
    NSString *jsonString = createJSONString(paramsDict);
    return createCString(jsonString);
}


void SausageReplaySDK_ConvertVideoFormat(const char* inputPath, int outputFormat, void(*callback)(bool success, const char* outputPath)) {
    if (!inputPath || !callback) {
        return;
    }
    
    _conversionCallback = callback;
    SROutputFormat format = (SROutputFormat)outputFormat;
    
    [SRFileManager convertVideoFormat:[NSString stringWithUTF8String:inputPath]
                         outputFormat:format
                             callback:^(BOOL success, NSString * _Nullable outputPath, NSError * _Nullable error) {
        if (_conversionCallback) {
            _conversionCallback(success, [outputPath UTF8String]);
        }
    }];
}

bool SausageReplaySDK_HasMicrophonePermission(void) {
    return [SRPermissionManager hasMicrophonePermission];
}

void SausageReplaySDK_RequestMicrophonePermission(void(*callback)(bool granted, int errorCode, const char* message)) {
    if (!callback) {
        return;
    }
    
    _permissionCallback = callback;
    
    [SRPermissionManager requestMicrophonePermission:^(SRPermissionResult *result) {
        if (_permissionCallback) {
            _permissionCallback(result.isGranted, (int)result.errorCode, [result.errorMessage UTF8String]);
        }
    }];
}

