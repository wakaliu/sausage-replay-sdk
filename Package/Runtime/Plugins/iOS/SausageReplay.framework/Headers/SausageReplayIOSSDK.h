//
//  SausageReplayIOSSDK.h
//  SausageReplay
//
//  Created by Waka on 2025/10/10.
//

#import <Foundation/Foundation.h>
#import "SRModels.h"

//! Project version number for SausageReplay.
FOUNDATION_EXPORT double SausageReplayVersionNumber;

//! Project version string for SausageReplay.
FOUNDATION_EXPORT const unsigned char SausageReplayVersionString[];

NS_ASSUME_NONNULL_BEGIN

/**
 * Sausage Replay iOS SDK 主接口
 * 提供屏幕录制功能的统一入口
 */
@interface SausageReplayIOSSDK : NSObject

/**
 * 初始化SDK（使用视频清晰度档位）
 * @param preset 视频清晰度档位
 * @param enableDebugLog 是否开启内部日志
 * @return 是否初始化成功
 */
+ (BOOL)initializeWithPreset:(SRVideoQualityPreset)preset enableDebugLog:(BOOL)enableDebugLog;

/** 兼容旧接口：默认开启日志 */
+ (BOOL)initializeWithPreset:(SRVideoQualityPreset)preset;

/**
 * 检查平台支持
 * @return 是否支持
 */
+ (BOOL)isPlatformSupported;

/**
 * 获取SDK版本
 * @return 版本号
 */
+ (NSString *)version;

/**
 * 释放SDK资源
 */
+ (void)releaseResources;

/**
 * 获取当前视频清晰度档位
 * @return 当前视频清晰度档位
 */
+ (SRVideoQualityPreset)getCurrentPreset;

@end

NS_ASSUME_NONNULL_END
