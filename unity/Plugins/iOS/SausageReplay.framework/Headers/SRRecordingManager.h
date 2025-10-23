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
 * 停止录制
 * @param callback 停止结果回调
 */
+ (void)stopRecording:(void(^)(SRRecordingResult *result))callback;

/**
 * 暂停录制
 * @return 是否成功暂停
 */
+ (BOOL)pauseRecording;

/**
 * 恢复录制
 * @return 是否成功恢复
 */
+ (BOOL)resumeRecording;

/**
 * 获取当前录制状态
 * @return 录制状态
 */
+ (SRRecordingStatus)status;

/**
 * 调整录制质量
 * @param quality 目标质量
 * @return 是否成功调整
 */
+ (BOOL)adjustRecordingQuality:(SRVideoQuality)quality;

/**
 * 获取详细状态
 * @return 详细状态信息
 */
+ (SRDetailedStatus *)getDetailedStatus;

/**
 * 错误恢复
 * @return 是否成功恢复
 */
+ (BOOL)recoverFromError;

/**
 * 重置状态
 */
+ (void)resetStatus;

/**
 * 转换视频格式
 * @param inputPath 输入文件路径
 * @param outputFormat 目标格式
 * @param callback 转换结果回调
 */
+ (void)convertVideoFormat:(NSString *)inputPath
              outputFormat:(SROutputFormat)outputFormat
                  callback:(void(^)(BOOL success, NSString * _Nullable outputPath))callback;

@end

NS_ASSUME_NONNULL_END
