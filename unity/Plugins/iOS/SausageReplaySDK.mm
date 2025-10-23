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
#import "SausageReplayIOSSDK.h"
#import "SRRecordingManager.h"
#import "SRPermissionManager.h"
#import "SRModels.h"

// Unity回调函数指针类型定义
typedef void (*UnityCallback)();
typedef void (*UnityCallbackWithInt)(int);
typedef void (*UnityCallbackWithString)(const char*);
typedef void (*UnityCallbackWithIntString)(int, const char*);
typedef void (*UnityCallbackWithLongLong)(long long, long long);
typedef void (*UnityCallbackWithBoolString)(bool, const char*);

// 全局回调函数指针
static UnityCallback g_onRecordingStarted = nullptr;
static UnityCallback g_onRecordingPaused = nullptr;
static UnityCallback g_onRecordingResumed = nullptr;
static UnityCallbackWithLongLong g_onRecordingProgress = nullptr;
static UnityCallbackWithIntString g_onRecordingError = nullptr;
static UnityCallbackWithInt g_onRecordingQualityAdjusted = nullptr;
static UnityCallbackWithBoolString g_onConvertCompleted = nullptr;

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

- (void)onRecordingPaused {
    if (g_onRecordingPaused) {
        g_onRecordingPaused();
    }
}

- (void)onRecordingResumed {
    if (g_onRecordingResumed) {
        g_onRecordingResumed();
    }
}

- (void)onRecordingStopped:(SRRecordingResult *)result {
    if (g_onRecordingStopped) {
        const char* filePath = result.filePath ? [result.filePath UTF8String] : "";
        const char* errorMessage = result.errorMessage ? [result.errorMessage UTF8String] : "";
        g_onRecordingStopped(result.isSuccess, filePath, result.fileSize, result.duration);
    }
}

- (void)onRecordingError:(NSInteger)errorCode errorMessage:(NSString *)errorMessage {
    if (g_onRecordingError) {
        const char* errorMsg = errorMessage ? [errorMessage UTF8String] : "";
        g_onRecordingError((int)errorCode, errorMsg);
    }
}

- (void)onRecordingQualityAdjusted:(SRVideoQuality)quality {
    if (g_onRecordingQualityAdjusted) {
        g_onRecordingQualityAdjusted((int)quality);
    }
}

@end

// 全局回调实例
static UnityRecordingCallback* g_recordingCallback = nil;

// 初始化回调实例
static void InitializeCallback() {
    if (!g_recordingCallback) {
        g_recordingCallback = [[UnityRecordingCallback alloc] init];
    }
}

// 辅助函数
static char* createCString(NSString *string) {
    if (!string) return NULL;
    
    const char *cString = [string UTF8String];
    size_t length = strlen(cString) + 1;
    char *result = malloc(length);
    if (result) {
        strcpy(result, cString);
    }
    return result;
}

extern "C" {
    
    // MARK: - 初始化与基础功能
    
    bool SausageReplaySDK_Initialize(int preset) {
        InitializeCallback();
        SRVideoQualityPreset qualityPreset = (SRVideoQualityPreset)preset;
        return [SausageReplayIOSSDK initializeWithPreset:qualityPreset];
    }
    
    bool SausageReplaySDK_IsPlatformSupported() {
        return [SausageReplayIOSSDK isPlatformSupported];
    }
    
    const char* SausageReplaySDK_GetVersion() {
        NSString* version = [SausageReplayIOSSDK version];
        return createCString(version);
    }
    
    void SausageReplaySDK_Release() {
        [SausageReplayIOSSDK releaseResources];
    }
    
    int SausageReplaySDK_GetCurrentPreset() {
        return (int)[SausageReplayIOSSDK getCurrentPreset];
    }
    
    // MARK: - 录制控制
    
    bool SausageReplaySDK_StartRecording(const char* configJson) {
        if (!configJson) return false;
        
        NSString* jsonString = [NSString stringWithUTF8String:configJson];
        NSData* jsonData = [jsonString dataUsingEncoding:NSUTF8StringEncoding];
        NSError* error;
        NSDictionary* configDict = [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:&error];
        
        if (error || !configDict) {
            return false;
        }
        
        // 创建录制配置
        SRRecordingConfig* config = [SRRecordingConfig defaultConfig];
        
        // 解析配置参数
        if (configDict[@"qualityPreset"]) {
            config.qualityPreset = [configDict[@"qualityPreset"] intValue];
        }
        if (configDict[@"includeAudio"]) {
            config.includeAudio = [configDict[@"includeAudio"] boolValue];
        }
        if (configDict[@"maxDurationSeconds"]) {
            config.maxDurationSeconds = [configDict[@"maxDurationSeconds"] intValue];
        }
        if (configDict[@"outputFormat"]) {
            config.outputFormat = [configDict[@"outputFormat"] intValue];
        }
        if (configDict[@"outputPath"]) {
            config.outputPath = configDict[@"outputPath"];
        }
        if (configDict[@"targetBitrate"]) {
            config.targetBitrate = configDict[@"targetBitrate"];
        }
        
        return [SRRecordingManager startRecordingWithConfig:config callback:g_recordingCallback];
    }
    
    void SausageReplaySDK_StopRecording() {
        [SRRecordingManager stopRecording:^(SRRecordingResult *result) {
            // 结果通过回调处理
        }];
    }
    
    bool SausageReplaySDK_PauseRecording() {
        return [SRRecordingManager pauseRecording];
    }
    
    bool SausageReplaySDK_ResumeRecording() {
        return [SRRecordingManager resumeRecording];
    }
    
    int SausageReplaySDK_GetRecordingStatus() {
        return (int)[SRRecordingManager status];
    }
    
    // MARK: - 质量调整
    
    bool SausageReplaySDK_AdjustRecordingQuality(int quality) {
        SRVideoQuality videoQuality = (SRVideoQuality)quality;
        return [SRRecordingManager adjustRecordingQuality:videoQuality];
    }
    
    // MARK: - 状态监控
    
    const char* SausageReplaySDK_GetDetailedStatus() {
        SRDetailedStatus* status = [SRRecordingManager getDetailedStatus];
        if (!status) return createCString(@"{}");
        
        NSDictionary* statusDict = @{
            @"status": @(status.status),
            @"isRecording": @(status.isRecording),
            @"isPaused": @(status.isPaused),
            @"duration": @(status.duration),
            @"fileSize": @(status.fileSize),
            @"errorCode": @(status.errorCode),
            @"errorMessage": status.errorMessage ?: @""
        };
        
        NSError* error;
        NSData* jsonData = [NSJSONSerialization dataWithJSONObject:statusDict options:0 error:&error];
        if (error) return createCString(@"{}");
        
        NSString* jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
        return createCString(jsonString);
    }
    
    const char* SausageReplaySDK_GetMemoryUsage() {
        SRMemoryUsage* memoryUsage = [SausageReplayIOSSDK getMemoryUsage];
        if (!memoryUsage) return createCString(@"{}");
        
        NSDictionary* memoryDict = @{
            @"usedMemory": @(memoryUsage.usedMemory),
            @"maxMemory": @(memoryUsage.maxMemory),
            @"usagePercentage": @(memoryUsage.usagePercentage)
        };
        
        NSError* error;
        NSData* jsonData = [NSJSONSerialization dataWithJSONObject:memoryDict options:0 error:&error];
        if (error) return createCString(@"{}");
        
        NSString* jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
        return createCString(jsonString);
    }
    
    // MARK: - 错误恢复
    
    bool SausageReplaySDK_RecoverFromError() {
        return [SRRecordingManager recoverFromError];
    }
    
    void SausageReplaySDK_ResetStatus() {
        [SRRecordingManager resetStatus];
    }
    
    // MARK: - 格式转换
    
    bool SausageReplaySDK_IsGifConversionSupported() {
        return [SausageReplayIOSSDK isGifConversionSupported];
    }
    
    const char* SausageReplaySDK_GetGifConversionParams() {
        SRGifConversionParams* params = [SausageReplayIOSSDK getGifConversionParams];
        if (!params) return createCString(@"{}");
        
        NSDictionary* paramsDict = @{
            @"maxWidth": @(params.maxWidth),
            @"maxHeight": @(params.maxHeight),
            @"maxFrames": @(params.maxFps),
            @"frameRate": @(params.maxFps),
            @"quality": @(params.maxDurationSeconds)
        };
        
        NSError* error;
        NSData* jsonData = [NSJSONSerialization dataWithJSONObject:paramsDict options:0 error:&error];
        if (error) return createCString(@"{}");
        
        NSString* jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
        return createCString(jsonString);
    }
    
    void SausageReplaySDK_ConvertVideoFormat(const char* inputPath, int outputFormat, void* callback) {
        if (!inputPath) return;
        
        NSString* inputPathStr = [NSString stringWithUTF8String:inputPath];
        SROutputFormat format = (SROutputFormat)outputFormat;
        
        [SRRecordingManager convertVideoFormat:inputPathStr
                                 outputFormat:format
                                     callback:^(BOOL success, NSString *outputPath) {
            if (callback) {
                const char* outputPathStr = outputPath ? [outputPath UTF8String] : "";
                ((void(*)(bool, const char*))callback)(success, outputPathStr);
            }
        }];
    }
    
    // MARK: - 权限管理
    
    bool SausageReplaySDK_HasMicrophonePermission() {
        return [SRPermissionManager hasMicrophonePermission];
    }
    
    void SausageReplaySDK_RequestMicrophonePermission(void* callback) {
        [SRPermissionManager requestMicrophonePermission:^(BOOL granted) {
            if (callback) {
                ((void(*)(bool))callback)(granted);
            }
        }];
    }
    
}
