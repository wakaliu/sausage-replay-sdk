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
#import "SRLogger.h"
#import <ReplayKit/ReplayKit.h>
#import <sys/sysctl.h>
#import <mach/mach.h>

static SRVideoQualityPreset _currentPreset = SRVideoQualityPresetStandard;
static BOOL _isInitialized = NO;

@implementation SausageReplayIOSSDK

double SausageReplayVersionNumber = 1.0;
const unsigned char SausageReplayVersionString[] = "1.0.0";

+ (BOOL)initializeWithPreset:(SRVideoQualityPreset)preset enableDebugLog:(BOOL)enableDebugLog {
    if (_isInitialized) {
        [SRLogger info:@"SausageReplayIOSSDK" message:@"already initialized"];
        return YES;
    }
    [SRLogger setEnabled:enableDebugLog];
    [SRLogger debug:@"SausageReplayIOSSDK" message:[NSString stringWithFormat:@"initialize called, preset=%ld, debug=%@", (long)preset, enableDebugLog ? @"YES" : @"NO"]];
    
    // 检查平台支持
    if (![self isPlatformSupported]) {
        [SRLogger error:@"SausageReplayIOSSDK" message:@"Platform not supported"];
        return NO;
    }
    
    // 设置视频清晰度档位
    _currentPreset = preset;
    
    // 检查权限（内部使用，不暴露给Unity）
    if (![SRPermissionManager hasScreenRecordingPermission]) {
        [SRLogger warn:@"SausageReplayIOSSDK" message:@"Screen recording not supported on this device"];
        return NO;
    }
    
    // 清理临时文件
    [SRFileManager cleanupTempFiles];
    
    _isInitialized = YES;
    [SRLogger info:@"SausageReplayIOSSDK" message:[NSString stringWithFormat:@"initialized successfully, preset=%ld", (long)preset]];
    
    return YES;
}

// 兼容旧接口：默认开启日志
+ (BOOL)initializeWithPreset:(SRVideoQualityPreset)preset {
    return [self initializeWithPreset:preset enableDebugLog:YES];
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
    [SRLogger info:@"SausageReplayIOSSDK" message:@"released successfully"];
}

+ (SRVideoQualityPreset)getCurrentPreset {
    return _currentPreset;
}


@end
