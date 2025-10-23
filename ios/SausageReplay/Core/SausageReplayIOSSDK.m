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
    
    // 检查权限（内部使用，不暴露给Unity）
    if (![SRPermissionManager hasScreenRecordingPermission]) {
        NSLog(@"Screen recording not supported on this device");
        return NO;
    }
    
    // 清理临时文件
    [SRFileManager cleanupTempFiles];
    
    _isInitialized = YES;
    NSLog(@"SausageReplayIOSSDK initialized successfully with preset: %ld", (long)preset);
    
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

+ (SRVideoQualityPreset)getCurrentPreset {
    return _currentPreset;
}


@end
