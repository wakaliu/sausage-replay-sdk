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
 * @return 是否初始化成功
 */
+ (BOOL)initializeWithPreset:(SRVideoQualityPreset)preset;

/**
 * 初始化SDK（兼容旧版本，使用设备性能档位）
 * @param tier 设备性能档位
 * @return 是否初始化成功
 */
+ (BOOL)initializeWithTier:(SRDevicePerformanceTier)tier;

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
 * 获取内存使用情况
 * @return 内存使用信息
 */
+ (SRMemoryUsage *)getMemoryUsage;

/**
 * 获取设备档位信息
 * @return 设备档位信息
 */
+ (SRDeviceTierInfo *)getDeviceTierInfo;

/**
 * 获取当前视频清晰度档位
 * @return 当前视频清晰度档位
 */
+ (SRVideoQualityPreset)getCurrentPreset;

/**
 * 检查GIF转换是否支持
 * @return 是否支持
 */
+ (BOOL)isGifConversionSupported;

/**
 * 获取GIF转换参数
 * @return GIF转换参数
 */
+ (SRGifConversionParams *)getGifConversionParams;

/**
 * 重新加载设备档位配置
 * @return 是否成功重新加载
 */
+ (BOOL)reloadDeviceTierConfig;

@end

NS_ASSUME_NONNULL_END
