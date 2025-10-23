//
//  SRModels.m
//  SausageReplay
//
//  Created by Waka on 2025/10/10.
//

#import "SRModels.h"

@implementation SRRecordingConfig

+ (instancetype)defaultConfig {
    SRRecordingConfig *config = [[SRRecordingConfig alloc] init];
    config.qualityPreset = SRVideoQualityPresetStandard; // 默认使用Standard档位
    config.maxDurationSeconds = 1800; // 30分钟 (30 * 60 = 1800秒)
    config.maxFileSizeBytes = 300L * 1024 * 1024; // 300MB
    config.includeAudio = YES;
    config.outputFormat = SROutputFormatMP4;
    config.outputPath = nil;
    config.targetBitrate = nil;
    config.targetFps = 30;
    return config;
}

@end

@implementation SRRecordingResult

+ (instancetype)successWithFilePath:(NSString *)filePath
                           fileSize:(long long)fileSize
                           duration:(float)duration {
    SRRecordingResult *result = [[SRRecordingResult alloc] init];
    result.isSuccess = YES;
    result.filePath = filePath;
    result.fileSize = fileSize;
    result.duration = duration;
    result.errorCode = 0;
    result.errorMessage = nil;
    return result;
}

+ (instancetype)failureWithErrorCode:(NSInteger)errorCode
                        errorMessage:(nullable NSString *)errorMessage {
    SRRecordingResult *result = [[SRRecordingResult alloc] init];
    result.isSuccess = NO;
    result.filePath = nil;
    result.fileSize = 0;
    result.duration = 0.0f;
    result.errorCode = errorCode;
    result.errorMessage = errorMessage;
    return result;
}

@end

@implementation SRMemoryUsage

@end

@implementation SRDetailedStatus

@end

@implementation SRDeviceTierInfo

@end

@implementation SRGifConversionParams

@end

@implementation SRPerformanceMetrics

@end

@implementation SRPermissionResult

+ (instancetype)granted {
    SRPermissionResult *result = [[SRPermissionResult alloc] init];
    result.isGranted = YES;
    result.errorCode = 0;
    result.errorMessage = nil;
    return result;
}

+ (instancetype)deniedWithErrorCode:(NSInteger)errorCode errorMessage:(nullable NSString *)errorMessage {
    SRPermissionResult *result = [[SRPermissionResult alloc] init];
    result.isGranted = NO;
    result.errorCode = errorCode;
    result.errorMessage = errorMessage;
    return result;
}

@end
