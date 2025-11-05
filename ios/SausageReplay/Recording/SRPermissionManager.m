//
//  SRPermissionManager.m
//  SausageReplay
//
//  Created by Waka on 2025/10/10.
//

#import "SRPermissionManager.h"
#import <AVFoundation/AVFoundation.h>
#import <Photos/Photos.h>

@implementation SRPermissionManager

+ (BOOL)hasMicrophonePermission {
    AVAuthorizationStatus status = [AVAudioSession sharedInstance].recordPermission;
    return status == AVAudioSessionRecordPermissionGranted;
}

+ (void)requestMicrophonePermission:(void(^)(BOOL granted, NSInteger errorCode, NSString *errorMessage))callback {
    if (!callback) {
        return;
    }
    
    // 检查当前权限状态
    AVAudioSessionRecordPermission currentStatus = [AVAudioSession sharedInstance].recordPermission;
    
    if (currentStatus == AVAudioSessionRecordPermissionGranted) {
        // 已有权限
        dispatch_async(dispatch_get_main_queue(), ^{
            callback(YES, 0, nil);
        });
        return;
    }
    
    if (currentStatus == AVAudioSessionRecordPermissionDenied) {
        // 权限被拒绝
        dispatch_async(dispatch_get_main_queue(), ^{
            callback(NO, 1002, @"Permission permanently denied");
        });
        return;
    }
    
    // 请求权限
    [[AVAudioSession sharedInstance] requestRecordPermission:^(BOOL granted) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (granted) {
                callback(YES, 0, nil);
            } else {
                callback(NO, 1001, @"Permission denied");
            }
        });
    }];
}

+ (BOOL)hasScreenRecordingPermission {
    // iOS的屏幕录制权限由ReplayKit系统管理
    // 无法直接检查，需要在录制时由系统处理
    return YES;
}

+ (BOOL)hasPhotoLibraryWritePermission {
    if (@available(iOS 14, *)) {
        PHAuthorizationStatus status = [PHPhotoLibrary authorizationStatusForAccessLevel:PHAccessLevelAddOnly];
        return status == PHAuthorizationStatusAuthorized || status == PHAuthorizationStatusLimited;
    } else {
        PHAuthorizationStatus status = [PHPhotoLibrary authorizationStatus];
        return status == PHAuthorizationStatusAuthorized;
    }
}

+ (void)requestPhotoLibraryWritePermission:(void(^)(BOOL granted, NSInteger errorCode, NSString *errorMessage))callback {
    if (!callback) { return; }
    void (^finish)(BOOL) = ^(BOOL granted){
        dispatch_async(dispatch_get_main_queue(), ^{
            if (granted) callback(YES, 0, nil);
            else callback(NO, 1101, @"Photo library permission denied");
        });
    };
    if (@available(iOS 14, *)) {
        [PHPhotoLibrary requestAuthorizationForAccessLevel:PHAccessLevelAddOnly handler:^(PHAuthorizationStatus status) {
            finish(status == PHAuthorizationStatusAuthorized || status == PHAuthorizationStatusLimited);
        }];
    } else {
        [PHPhotoLibrary requestAuthorization:^(PHAuthorizationStatus status) {
            finish(status == PHAuthorizationStatusAuthorized);
        }];
    }
}

@end
