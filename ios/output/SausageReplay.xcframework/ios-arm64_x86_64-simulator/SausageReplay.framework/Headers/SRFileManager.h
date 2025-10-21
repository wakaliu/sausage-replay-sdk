//
//  SRFileManager.h
//  SausageReplay
//
//  Created by Waka on 2025/10/10.
//

#import <Foundation/Foundation.h>
#import "SRModels.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * 文件管理器
 * 负责文件操作和格式转换
 */
@interface SRFileManager : NSObject

/**
 * 生成输出文件路径
 * @param format 输出格式
 * @return 文件路径
 */
+ (NSString *)generateOutputPathForFormat:(SROutputFormat)format;

/**
 * 检查文件是否存在
 * @param filePath 文件路径
 * @return 是否存在
 */
+ (BOOL)fileExistsAtPath:(NSString *)filePath;

/**
 * 获取文件大小
 * @param filePath 文件路径
 * @return 文件大小（字节）
 */
+ (long long)fileSizeAtPath:(NSString *)filePath;

/**
 * 删除文件
 * @param filePath 文件路径
 * @return 是否成功删除
 */
+ (BOOL)deleteFileAtPath:(NSString *)filePath;

/**
 * 清理临时文件
 */
+ (void)cleanupTempFiles;

/**
 * 转换视频格式
 * @param inputPath 输入文件路径
 * @param outputFormat 目标格式
 * @param callback 转换结果回调
 */
+ (void)convertVideoFormat:(NSString *)inputPath
              outputFormat:(SROutputFormat)outputFormat
                  callback:(void(^)(BOOL success, NSString * _Nullable outputPath, NSError * _Nullable error))callback;

/**
 * 检查存储空间是否足够
 * @param requiredBytes 需要的字节数
 * @return 是否足够
 */
+ (BOOL)hasEnoughStorageSpace:(long long)requiredBytes;

/**
 * 获取可用存储空间
 * @return 可用空间（字节）
 */
+ (long long)getAvailableStorageSpace;

@end

NS_ASSUME_NONNULL_END
