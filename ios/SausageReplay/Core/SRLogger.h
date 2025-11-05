//
//  SRLogger.h
//  SausageReplay
//
//  Created by Waka on 2025/10/10.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * 统一日志管理类
 * 提供全局开关控制所有 SDK 日志输出
 */
@interface SRLogger : NSObject

/**
 * 设置日志是否启用
 * @param enabled YES 启用日志，NO 禁用日志
 */
+ (void)setEnabled:(BOOL)enabled;

/**
 * 输出 Debug 级别日志
 * @param tag 日志标签
 * @param message 日志消息
 */
+ (void)debug:(NSString *)tag message:(NSString *)message;

/**
 * 输出 Info 级别日志
 * @param tag 日志标签
 * @param message 日志消息
 */
+ (void)info:(NSString *)tag message:(NSString *)message;

/**
 * 输出 Warn 级别日志
 * @param tag 日志标签
 * @param message 日志消息
 */
+ (void)warn:(NSString *)tag message:(NSString *)message;

/**
 * 输出 Error 级别日志
 * @param tag 日志标签
 * @param message 日志消息
 */
+ (void)error:(NSString *)tag message:(NSString *)message;

/**
 * 输出 Error 级别日志（带 NSError）
 * @param tag 日志标签
 * @param message 日志消息
 * @param error 错误对象
 */
+ (void)error:(NSString *)tag message:(NSString *)message error:(nullable NSError *)error;

@end

NS_ASSUME_NONNULL_END

