//
//  SausageReplaySDK.mm
//  SausageReplay Unity Bridge
//
//  Created by Waka on 2025/10/10.
//

#import <Foundation/Foundation.h>
#import <ReplayKit/ReplayKit.h>
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

extern "C" {
    
    // MARK: - 初始化与基础功能
    
    /// 初始化SDK
    /// @param preset 视频清晰度档位 (0=Basic, 1=Standard, 2=Smooth, 3=HighFps, 4=Ultra)
    /// @return 是否初始化成功
    bool SausageReplaySDK_Initialize(int preset) {
        InitializeCallback();
        SRVideoQualityPreset qualityPreset = (SRVideoQualityPreset)preset;
        return [SausageReplayIOSSDK initializeWithPreset:qualityPreset];
    }
    
    /// 使用设备性能档位初始化SDK（兼容性方法）
    /// @param tier 设备性能档位 (0=MidRange, 1=HighEnd)
    /// @return 是否初始化成功
    bool SausageReplaySDK_InitializeWithTier(int tier) {
        InitializeCallback();
        SRDevicePerformanceTier deviceTier = (SRDevicePerformanceTier)tier;
        return [SausageReplayIOSSDK initializeWithTier:deviceTier];
    }
    
    /// 检查平台支持
    /// @return 是否支持屏幕录制
    bool SausageReplaySDK_IsPlatformSupported() {
        return [SausageReplayIOSSDK isPlatformSupported];
    }
    
    /// 获取SDK版本
    /// @return 版本字符串
    const char* SausageReplaySDK_GetVersion() {
        NSString* version = [SausageReplayIOSSDK version];
        return strdup([version UTF8String]);
    }
    
    /// 释放SDK资源
    void SausageReplaySDK_Release() {
        [SausageReplayIOSSDK release];
    }
    
    /// 获取当前视频清晰度档位
    /// @return 当前档位
    int SausageReplaySDK_GetCurrentPreset() {
        return (int)[SausageReplayIOSSDK getCurrentPreset];
    }
    
    // MARK: - 录制控制
    
    /// 开始录制
    /// @param configJson 录制配置JSON字符串
    /// @return 是否开始成功
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
    
    /// 停止录制
    void SausageReplaySDK_StopRecording() {
        [SRRecordingManager stopRecording:^(SRRecordingResult *result) {
            // 结果通过回调处理
        }];
    }
    
    /// 暂停录制
    /// @return 是否暂停成功
    bool SausageReplaySDK_PauseRecording() {
        return [SRRecordingManager pauseRecording];
    }
    
    /// 恢复录制
    /// @return 是否恢复成功
    bool SausageReplaySDK_ResumeRecording() {
        return [SRRecordingManager resumeRecording];
    }
    
    /// 获取录制状态
    /// @return 录制状态 (0=Idle, 1=Starting, 2=Recording, 3=Paused, 4=Stopping)
    int SausageReplaySDK_GetRecordingStatus() {
        return (int)[SRRecordingManager status];
    }
    
    // MARK: - 质量调整
    
    /// 调整录制质量
    /// @param quality 目标质量 (0=LOW, 1=MEDIUM, 2=HIGH)
    /// @return 是否调整成功
    bool SausageReplaySDK_AdjustRecordingQuality(int quality) {
        SRVideoQuality videoQuality = (SRVideoQuality)quality;
        return [SRRecordingManager adjustRecordingQuality:videoQuality];
    }
    
    // MARK: - 状态监控
    
    /// 获取详细状态
    /// @return 详细状态JSON字符串
    const char* SausageReplaySDK_GetDetailedStatus() {
        SRDetailedStatus* status = [SRRecordingManager getDetailedStatus];
        if (!status) return strdup("{}");
        
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
        if (error) return strdup("{}");
        
        NSString* jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
        return strdup([jsonString UTF8String]);
    }
    
    /// 获取内存使用情况
    /// @return 内存使用JSON字符串
    const char* SausageReplaySDK_GetMemoryUsage() {
        SRMemoryUsage* memoryUsage = [SausageReplayIOSSDK getMemoryUsage];
        if (!memoryUsage) return strdup("{}");
        
        NSDictionary* memoryDict = @{
            @"usedMemory": @(memoryUsage.usedMemory),
            @"maxMemory": @(memoryUsage.maxMemory),
            @"usagePercentage": @(memoryUsage.usagePercentage)
        };
        
        NSError* error;
        NSData* jsonData = [NSJSONSerialization dataWithJSONObject:memoryDict options:0 error:&error];
        if (error) return strdup("{}");
        
        NSString* jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
        return strdup([jsonString UTF8String]);
    }
    
    // MARK: - 错误恢复
    
    /// 从错误中恢复
    /// @return 是否恢复成功
    bool SausageReplaySDK_RecoverFromError() {
        return [SRRecordingManager recoverFromError];
    }
    
    /// 重置状态
    void SausageReplaySDK_ResetStatus() {
        [SRRecordingManager resetStatus];
    }
    
    // MARK: - 设备信息
    
    /// 获取设备档位信息
    /// @return 设备信息JSON字符串
    const char* SausageReplaySDK_GetDeviceTierInfo() {
        SRDeviceTierInfo* tierInfo = [SausageReplayIOSSDK getDeviceTierInfo];
        if (!tierInfo) return strdup("{}");
        
        NSDictionary* tierDict = @{
            @"tierName": tierInfo.tierName ?: @"",
            @"maxWidth": @(tierInfo.maxWidth),
            @"maxHeight": @(tierInfo.maxHeight),
            @"targetFps": @(tierInfo.targetFps),
            @"videoBitrate": @(tierInfo.videoBitrate),
            @"gifSupported": @(tierInfo.gifSupported)
        };
        
        NSError* error;
        NSData* jsonData = [NSJSONSerialization dataWithJSONObject:tierDict options:0 error:&error];
        if (error) return strdup("{}");
        
        NSString* jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
        return strdup([jsonString UTF8String]);
    }
    
    // MARK: - 格式转换
    
    /// 检查GIF转换支持
    /// @return 是否支持GIF转换
    bool SausageReplaySDK_IsGifConversionSupported() {
        return [SausageReplayIOSSDK isGifConversionSupported];
    }
    
    /// 获取GIF转换参数
    /// @return GIF转换参数JSON字符串
    const char* SausageReplaySDK_GetGifConversionParams() {
        SRGifConversionParams* params = [SausageReplayIOSSDK getGifConversionParams];
        if (!params) return strdup("{}");
        
        NSDictionary* paramsDict = @{
            @"maxWidth": @(params.maxWidth),
            @"maxHeight": @(params.maxHeight),
            @"maxFrames": @(params.maxFrames),
            @"frameRate": @(params.frameRate),
            @"quality": @(params.quality)
        };
        
        NSError* error;
        NSData* jsonData = [NSJSONSerialization dataWithJSONObject:paramsDict options:0 error:&error];
        if (error) return strdup("{}");
        
        NSString* jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
        return strdup([jsonString UTF8String]);
    }
    
    /// 重新加载设备档位配置
    /// @return 是否重新加载成功
    bool SausageReplaySDK_ReloadDeviceTierConfig() {
        return [SausageReplayIOSSDK reloadDeviceTierConfig];
    }
    
    /// 转换视频格式
    /// @param inputPath 输入文件路径
    /// @param outputFormat 输出格式 (0=MP4, 1=GIF, 2=WEBM, 3=AVI)
    /// @param callback 转换完成回调
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
    
    /// 检查麦克风权限
    /// @return 是否有麦克风权限
    bool SausageReplaySDK_HasMicrophonePermission() {
        return [SRPermissionManager hasMicrophonePermission];
    }
    
    /// 请求麦克风权限
    /// @param callback 权限请求回调
    void SausageReplaySDK_RequestMicrophonePermission(void* callback) {
        [SRPermissionManager requestMicrophonePermission:^(BOOL granted) {
            if (callback) {
                ((void(*)(bool))callback)(granted);
            }
        }];
    }
    
    // MARK: - Unity回调注册
    
    /// 注册录制开始回调
    void SausageReplaySDK_RegisterOnRecordingStarted(UnityCallback callback) {
        g_onRecordingStarted = callback;
    }
    
    /// 注册录制进度回调
    void SausageReplaySDK_RegisterOnRecordingProgress(UnityCallbackWithLongLong callback) {
        g_onRecordingProgress = callback;
    }
    
    /// 注册录制暂停回调
    void SausageReplaySDK_RegisterOnRecordingPaused(UnityCallback callback) {
        g_onRecordingPaused = callback;
    }
    
    /// 注册录制恢复回调
    void SausageReplaySDK_RegisterOnRecordingResumed(UnityCallback callback) {
        g_onRecordingResumed = callback;
    }
    
    /// 注册录制停止回调
    void SausageReplaySDK_RegisterOnRecordingStopped(void (*callback)(bool, const char*, long long, float)) {
        g_onRecordingStopped = callback;
    }
    
    /// 注册录制错误回调
    void SausageReplaySDK_RegisterOnRecordingError(UnityCallbackWithIntString callback) {
        g_onRecordingError = callback;
    }
    
    /// 注册质量调整回调
    void SausageReplaySDK_RegisterOnRecordingQualityAdjusted(UnityCallbackWithInt callback) {
        g_onRecordingQualityAdjusted = callback;
    }
    
    /// 注册转换完成回调
    void SausageReplaySDK_RegisterOnConvertCompleted(UnityCallbackWithBoolString callback) {
        g_onConvertCompleted = callback;
    }
    
}
