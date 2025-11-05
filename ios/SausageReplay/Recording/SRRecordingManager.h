//
//  SRRecordingManager.h
//  SausageReplay
//
//  Created by Waka on 2025/10/10.
//

#import <Foundation/Foundation.h>
#import <ReplayKit/ReplayKit.h>
#import "SRModels.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * 录制管理器
 * 负责屏幕录制功能的核心实现
 */
@interface SRRecordingManager : NSObject <RPPreviewViewControllerDelegate>

/**
 * 开始录制
 * @param config 录制配置
 * @param callback 录制回调
 * @return 是否成功开始
 */
+ (BOOL)startRecordingWithConfig:(SRRecordingConfig *)config
                        callback:(nullable id<SRRecordingCallback>)callback;

/**
 * 开始录制（无参版本，使用默认配置）
 * @param callback 录制回调
 * @return 是否成功开始
 */
+ (BOOL)startRecordingWithCallback:(nullable id<SRRecordingCallback>)callback;

/**
 * 停止录制
 * @param callback 停止结果回调
 */
+ (void)stopRecording:(void(^)(SRRecordingResult *result))callback;


/**
 * 获取当前录制状态
 * @return 录制状态
 */
+ (SRRecordingStatus)status;


/**
 * 获取详细状态
 * @return 详细状态信息
 */
+ (SRDetailedStatus *)getDetailedStatus;

/**
 * 调整录制质量
 * @param quality 目标质量
 * @return 是否调整成功
 */
+ (BOOL)adjustRecordingQuality:(SRVideoQuality)quality;

/**
 * 重置状态
 */
+ (void)resetStatus;


@end

NS_ASSUME_NONNULL_END
