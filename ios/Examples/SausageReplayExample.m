//
//  SausageReplayExample.m
//  SausageReplay
//
//  Created by Waka on 2025/10/10.
//

#import <Foundation/Foundation.h>
#import "SausageReplayIOSSDK.h"
#import "SRRecordingManager.h"
#import "SRPermissionManager.h"
#import "SRModels.h"

@interface SausageReplayExample : NSObject <SRRecordingCallback>
@end

@implementation SausageReplayExample

- (void)runExample {
    NSLog(@"=== SausageReplay iOS SDK 示例 ===");
    
    // 1. 初始化SDK
    NSLog(@"1. 初始化SDK...");
    BOOL initialized = [SausageReplayIOSSDK initializeWithTier:SRDevicePerformanceTierMidRange];
    if (!initialized) {
        NSLog(@"❌ SDK初始化失败");
        return;
    }
    NSLog(@"✅ SDK初始化成功");
    
    // 2. 检查平台支持
    NSLog(@"2. 检查平台支持...");
    BOOL supported = [SausageReplayIOSSDK isPlatformSupported];
    NSLog(@"平台支持: %@", supported ? @"✅ 支持" : @"❌ 不支持");
    
    // 3. 获取版本信息
    NSLog(@"3. 获取版本信息...");
    NSString *version = [SausageReplayIOSSDK version];
    NSLog(@"SDK版本: %@", version);
    
    // 4. 检查麦克风权限
    NSLog(@"4. 检查麦克风权限...");
    BOOL hasPermission = [SRPermissionManager hasMicrophonePermission];
    NSLog(@"麦克风权限: %@", hasPermission ? @"✅ 已授权" : @"❌ 未授权");
    
    if (!hasPermission) {
        NSLog(@"请求麦克风权限...");
        [SRPermissionManager requestMicrophonePermission:^(SRPermissionResult *result) {
            NSLog(@"权限请求结果: %@", result.isGranted ? @"✅ 授权成功" : @"❌ 授权失败");
        }];
    }
    
    // 5. 获取设备档位信息
    NSLog(@"5. 获取设备档位信息...");
    SRDeviceTierInfo *tierInfo = [SausageReplayIOSSDK getDeviceTierInfo];
    NSLog(@"设备档位: %@", tierInfo.tierName);
    NSLog(@"最大分辨率: %ldx%ld", (long)tierInfo.maxWidth, (long)tierInfo.maxHeight);
    NSLog(@"目标帧率: %ld", (long)tierInfo.targetFps);
    NSLog(@"视频比特率: %lld", tierInfo.videoBitrate);
    NSLog(@"GIF支持: %@", tierInfo.gifSupported ? @"✅ 支持" : @"❌ 不支持");
    
    // 6. 获取内存使用情况
    NSLog(@"6. 获取内存使用情况...");
    SRMemoryUsage *memoryUsage = [SausageReplayIOSSDK getMemoryUsage];
    NSLog(@"内存使用: %lld / %lld MB (%.1f%%)", 
          memoryUsage.usedMemory / 1024 / 1024,
          memoryUsage.maxMemory / 1024 / 1024,
          memoryUsage.usagePercentage);
    
    // 7. 创建录制配置
    NSLog(@"7. 创建录制配置...");
    SRRecordingConfig *config = [SRRecordingConfig defaultConfig];
    config.quality = SRVideoQualityMedium;
    config.maxDurationSeconds = 30;
    config.includeAudio = YES;
    config.outputFormat = SROutputFormatMP4;
    NSLog(@"录制配置创建完成");
    
    // 8. 开始录制（模拟）
    NSLog(@"8. 开始录制...");
    BOOL started = [SRRecordingManager startRecordingWithConfig:config callback:self];
    NSLog(@"录制开始: %@", started ? @"✅ 成功" : @"❌ 失败");
    
    if (started) {
        // 模拟录制5秒
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            NSLog(@"停止录制...");
            [SRRecordingManager stopRecording:^(SRRecordingResult *result) {
                NSLog(@"录制结果: %@", result.isSuccess ? @"✅ 成功" : @"❌ 失败");
                if (result.isSuccess) {
                    NSLog(@"文件路径: %@", result.filePath);
                    NSLog(@"文件大小: %lld bytes", result.fileSize);
                    NSLog(@"录制时长: %.2f 秒", result.duration);
                } else {
                    NSLog(@"错误码: %ld", (long)result.errorCode);
                    NSLog(@"错误信息: %@", result.errorMessage);
                }
            }];
        });
    }
    
    // 9. 清理资源
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(10.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        NSLog(@"9. 清理资源...");
        [SausageReplayIOSSDK releaseResources];
        NSLog(@"✅ 资源清理完成");
    });
}

#pragma mark - SRRecordingCallback

- (void)onRecordingStarted {
    NSLog(@"🎬 录制开始");
}

- (void)onRecordingProgress:(long long)durationMs fileSizeBytes:(long long)fileSizeBytes {
    NSLog(@"📊 录制进度: %.1f秒, 文件大小: %lld bytes", durationMs / 1000.0, fileSizeBytes);
}

- (void)onRecordingPaused {
    NSLog(@"⏸️ 录制暂停");
}

- (void)onRecordingResumed {
    NSLog(@"▶️ 录制恢复");
}

- (void)onRecordingStopped:(SRRecordingResult *)result {
    NSLog(@"🛑 录制停止: %@", result.isSuccess ? @"成功" : @"失败");
}

- (void)onRecordingError:(NSInteger)errorCode errorMessage:(nullable NSString *)errorMessage {
    NSLog(@"❌ 录制错误: %ld - %@", (long)errorCode, errorMessage);
}

- (void)onRecordingQualityAdjusted:(SRVideoQuality)quality {
    NSLog(@"🎯 质量调整: %ld", (long)quality);
}

@end

// 主函数
int main(int argc, const char * argv[]) {
    @autoreleasepool {
        SausageReplayExample *example = [[SausageReplayExample alloc] init];
        [example runExample];
        
        // 保持程序运行
        [[NSRunLoop currentRunLoop] run];
    }
    return 0;
}
