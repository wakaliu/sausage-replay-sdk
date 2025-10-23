//
//  SRPermissionManager.m
//  SausageReplay
//
//  Created by Waka on 2025/10/10.
//

#import "SRPermissionManager.h"
#import <AVFoundation/AVFoundation.h>

@implementation SRPermissionManager

+ (BOOL)hasMicrophonePermission {
    AVAuthorizationStatus status = [AVAudioSession sharedInstance].recordPermission;
    return status == AVAudioSessionRecordPermissionGranted;
}

+ (void)requestMicrophonePermission:(void(^)(SRPermissionResult *result))callback {
    if (!callback) {
        return;
    }
    
    // 检查当前权限状态
    AVAudioSessionRecordPermission currentStatus = [AVAudioSession sharedInstance].recordPermission;
    
    if (currentStatus == AVAudioSessionRecordPermissionGranted) {
        // 已有权限
        dispatch_async(dispatch_get_main_queue(), ^{
            callback([SRPermissionResult granted]);
        });
        return;
    }
    
    if (currentStatus == AVAudioSessionRecordPermissionDenied) {
        // 权限被拒绝
        dispatch_async(dispatch_get_main_queue(), ^{
            callback([SRPermissionResult deniedWithErrorCode:1002 errorMessage:@"Permission permanently denied"]);
        });
        return;
    }
    
    // 请求权限
    [[AVAudioSession sharedInstance] requestRecordPermission:^(BOOL granted) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (granted) {
                callback([SRPermissionResult granted]);
            } else {
                callback([SRPermissionResult deniedWithErrorCode:1001 errorMessage:@"Permission denied"]);
            }
        });
    }];
}

+ (BOOL)hasScreenRecordingPermission {
    // iOS的屏幕录制权限由ReplayKit系统管理
    // 无法直接检查，需要在录制时由系统处理
    return YES;
}

@end
