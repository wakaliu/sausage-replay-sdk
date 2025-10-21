//
//  SRPermissionManager.h
//  SausageReplay
//
//  Created by Waka on 2025/10/10.
//

#import <Foundation/Foundation.h>
#import "SRModels.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * 权限管理器
 * 负责处理麦克风权限的检查和申请
 */
@interface SRPermissionManager : NSObject

/**
 * 检查是否有麦克风权限
 * @return 是否有权限
 */
+ (BOOL)hasMicrophonePermission;

/**
 * 请求麦克风权限
 * @param callback 权限结果回调
 */
+ (void)requestMicrophonePermission:(void(^)(SRPermissionResult *result))callback;

/**
 * 检查是否有屏幕录制权限
 * 注意：iOS的屏幕录制权限由系统管理，无法直接检查
 * @return 总是返回YES，实际权限由ReplayKit处理
 */
+ (BOOL)hasScreenRecordingPermission;

@end

NS_ASSUME_NONNULL_END
