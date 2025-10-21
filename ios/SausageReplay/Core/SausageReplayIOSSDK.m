//
//  SausageReplayIOSSDK.m
//  SausageReplay
//
//  Created by Waka on 2025/10/10.
//

#import "SausageReplayIOSSDK.h"
#import "SRRecordingManager.h"
#import "SRPermissionManager.h"
#import "SRFileManager.h"
#import <ReplayKit/ReplayKit.h>
#import <sys/sysctl.h>
#import <mach/mach.h>

static SRVideoQualityPreset _currentPreset = SRVideoQualityPresetStandard;
static SRDevicePerformanceTier _currentTier = SRDevicePerformanceTierMidRange;
static BOOL _isInitialized = NO;

@implementation SausageReplayIOSSDK

double SausageReplayVersionNumber = 1.0;
const unsigned char SausageReplayVersionString[] = "1.0.0";

+ (BOOL)initializeWithPreset:(SRVideoQualityPreset)preset {
    if (_isInitialized) {
        NSLog(@"SausageReplayIOSSDK already initialized");
        return YES;
    }
    
    // 检查平台支持
    if (![self isPlatformSupported]) {
        NSLog(@"Platform not supported");
        return NO;
    }
    
    // 设置视频清晰度档位
    _currentPreset = preset;
    
    // 根据视频清晰度档位映射到设备性能档位（兼容性）
    switch (preset) {
        case SRVideoQualityPresetBasic:
        case SRVideoQualityPresetSmooth:
            _currentTier = SRDevicePerformanceTierMidRange;
            break;
        case SRVideoQualityPresetStandard:
        case SRVideoQualityPresetHighFps:
        case SRVideoQualityPresetUltra:
            _currentTier = SRDevicePerformanceTierHighEnd;
            break;
    }
    
    // 清理临时文件
    [SRFileManager cleanupTempFiles];
    
    _isInitialized = YES;
    NSLog(@"SausageReplayIOSSDK initialized successfully with preset: %ld", (long)preset);
    
    return YES;
}

+ (BOOL)initializeWithTier:(SRDevicePerformanceTier)tier {
    if (_isInitialized) {
        NSLog(@"SausageReplayIOSSDK already initialized");
        return YES;
    }
    
    // 检查平台支持
    if (![self isPlatformSupported]) {
        NSLog(@"Platform not supported");
        return NO;
    }
    
    // 设置设备档位
    _currentTier = tier;
    
    // 根据设备性能档位映射到视频清晰度档位（兼容性）
    switch (tier) {
        case SRDevicePerformanceTierMidRange:
            _currentPreset = SRVideoQualityPresetStandard;
            break;
        case SRDevicePerformanceTierHighEnd:
            _currentPreset = SRVideoQualityPresetHighFps;
            break;
    }
    
    // 清理临时文件
    [SRFileManager cleanupTempFiles];
    
    _isInitialized = YES;
    NSLog(@"SausageReplayIOSSDK initialized successfully with tier: %ld", (long)tier);
    
    return YES;
}

+ (BOOL)isPlatformSupported {
    // 检查iOS版本
    if (@available(iOS 12.0, *)) {
        // 检查ReplayKit是否可用
        if ([RPScreenRecorder sharedRecorder].isAvailable) {
            return YES;
        }
    }
    return NO;
}

+ (NSString *)version {
    return @"1.0.0";
}

+ (void)releaseResources {
    if (!_isInitialized) {
        return;
    }
    
    // 停止录制
    if ([SRRecordingManager status] != SRRecordingStatusIdle) {
        [SRRecordingManager stopRecording:^(SRRecordingResult *result) {
            // 忽略回调
        }];
    }
    
    // 清理临时文件
    [SRFileManager cleanupTempFiles];
    
    _isInitialized = NO;
    NSLog(@"SausageReplayIOSSDK released successfully");
}

+ (SRMemoryUsage *)getMemoryUsage {
    SRMemoryUsage *memoryUsage = [[SRMemoryUsage alloc] init];
    
    struct mach_task_basic_info info;
    mach_msg_type_number_t size = MACH_TASK_BASIC_INFO_COUNT;
    kern_return_t kerr = task_info(mach_task_self(), MACH_TASK_BASIC_INFO, (task_info_t)&info, &size);
    
    if (kerr == KERN_SUCCESS) {
        memoryUsage.usedMemory = info.resident_size;
        memoryUsage.totalMemory = info.virtual_size;
        memoryUsage.freeMemory = info.virtual_size - info.resident_size;
        memoryUsage.maxMemory = info.virtual_size;
        memoryUsage.usagePercentage = (NSInteger)((double)info.resident_size / info.virtual_size * 100);
    }
    
    return memoryUsage;
}

+ (SRDeviceTierInfo *)getDeviceTierInfo {
    SRDeviceTierInfo *tierInfo = [[SRDeviceTierInfo alloc] init];
    tierInfo.tier = _currentTier;
    
    // 根据视频清晰度档位设置参数
    switch (_currentPreset) {
        case SRVideoQualityPresetBasic:
            tierInfo.tierName = @"Basic";
            tierInfo.maxWidth = 1280;
            tierInfo.maxHeight = 720;
            tierInfo.targetFps = 30;
            tierInfo.videoBitrate = 2000000; // 2 Mbps
            tierInfo.gifSupported = YES;
            break;
        case SRVideoQualityPresetStandard:
            tierInfo.tierName = @"Standard";
            tierInfo.maxWidth = 1920;
            tierInfo.maxHeight = 1080;
            tierInfo.targetFps = 30;
            tierInfo.videoBitrate = 4000000; // 4 Mbps
            tierInfo.gifSupported = YES;
            break;
        case SRVideoQualityPresetSmooth:
            tierInfo.tierName = @"Smooth";
            tierInfo.maxWidth = 1280;
            tierInfo.maxHeight = 720;
            tierInfo.targetFps = 60;
            tierInfo.videoBitrate = 3000000; // 3 Mbps
            tierInfo.gifSupported = YES;
            break;
        case SRVideoQualityPresetHighFps:
            tierInfo.tierName = @"HighFps";
            tierInfo.maxWidth = 1920;
            tierInfo.maxHeight = 1080;
            tierInfo.targetFps = 60;
            tierInfo.videoBitrate = 6000000; // 6 Mbps
            tierInfo.gifSupported = YES;
            break;
        case SRVideoQualityPresetUltra:
            tierInfo.tierName = @"Ultra";
            tierInfo.maxWidth = 2560;
            tierInfo.maxHeight = 1440;
            tierInfo.targetFps = 30;
            tierInfo.videoBitrate = 8000000; // 8 Mbps
            tierInfo.gifSupported = YES;
            break;
    }
    
    return tierInfo;
}

+ (SRVideoQualityPreset)getCurrentPreset {
    return _currentPreset;
}

+ (BOOL)isGifConversionSupported {
    // 检查设备是否支持GIF转换
    SRDeviceTierInfo *tierInfo = [self getDeviceTierInfo];
    return tierInfo.gifSupported;
}

+ (SRGifConversionParams *)getGifConversionParams {
    SRGifConversionParams *params = [[SRGifConversionParams alloc] init];
    
    switch (_currentTier) {
        case SRDevicePerformanceTierMidRange:
            params.maxFps = 10;
            params.maxWidth = 720;
            params.maxHeight = 720;
            params.maxDurationSeconds = 15;
            break;
        case SRDevicePerformanceTierHighEnd:
            params.maxFps = 12;
            params.maxWidth = 1080;
            params.maxHeight = 1080;
            params.maxDurationSeconds = 15;
            break;
    }
    
    return params;
}

+ (BOOL)reloadDeviceTierConfig {
    // iOS版本暂不支持动态重新加载配置
    // 这里只是返回成功，实际配置在初始化时确定
    return YES;
}

@end
