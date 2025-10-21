//
//  SRFileManager.m
//  SausageReplay
//
//  Created by Waka on 2025/10/10.
//

#import "SRFileManager.h"
#import <AVFoundation/AVFoundation.h>
#import <ImageIO/ImageIO.h>
#import <MobileCoreServices/MobileCoreServices.h>

@implementation SRFileManager

+ (NSString *)generateOutputPathForFormat:(SROutputFormat)format {
    // 创建输出目录
    NSURL *documentsURL = [[[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] firstObject];
    NSURL *replayURL = [documentsURL URLByAppendingPathComponent:@"replay"];
    
    NSError *error;
    [[NSFileManager defaultManager] createDirectoryAtURL:replayURL
                              withIntermediateDirectories:YES
                                               attributes:nil
                                                    error:&error];
    
    if (error) {
        NSLog(@"Failed to create replay directory: %@", error.localizedDescription);
        return nil;
    }
    
    // 生成文件名
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.dateFormat = @"yyyyMMdd_HHmmss";
    NSString *timestamp = [formatter stringFromDate:[NSDate date]];
    
    NSString *extension;
    switch (format) {
        case SROutputFormatMP4:
            extension = @"mp4";
            break;
        case SROutputFormatGIF:
            extension = @"gif";
            break;
        case SROutputFormatWEBM:
            extension = @"webm";
            break;
        case SROutputFormatAVI:
            extension = @"avi";
            break;
    }
    
    NSString *fileName = [NSString stringWithFormat:@"replay_%@.%@", timestamp, extension];
    NSURL *outputURL = [replayURL URLByAppendingPathComponent:fileName];
    
    return outputURL.path;
}

+ (BOOL)fileExistsAtPath:(NSString *)filePath {
    return [[NSFileManager defaultManager] fileExistsAtPath:filePath];
}

+ (long long)fileSizeAtPath:(NSString *)filePath {
    NSError *error;
    NSDictionary *attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:filePath error:&error];
    if (error) {
        NSLog(@"Failed to get file size: %@", error.localizedDescription);
        return 0;
    }
    return [attributes[NSFileSize] longLongValue];
}

+ (BOOL)deleteFileAtPath:(NSString *)filePath {
    NSError *error;
    BOOL success = [[NSFileManager defaultManager] removeItemAtPath:filePath error:&error];
    if (error) {
        NSLog(@"Failed to delete file: %@", error.localizedDescription);
    }
    return success;
}

+ (void)cleanupTempFiles {
    NSURL *documentsURL = [[[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] firstObject];
    NSURL *replayURL = [documentsURL URLByAppendingPathComponent:@"replay"];
    
    NSError *error;
    NSArray *files = [[NSFileManager defaultManager] contentsOfDirectoryAtURL:replayURL
                                                    includingPropertiesForKeys:@[NSURLContentModificationDateKey]
                                                                       options:NSDirectoryEnumerationSkipsHiddenFiles
                                                                         error:&error];
    
    if (error) {
        NSLog(@"Failed to list replay files: %@", error.localizedDescription);
        return;
    }
    
    // 删除超过7天的文件
    NSDate *sevenDaysAgo = [NSDate dateWithTimeIntervalSinceNow:-7 * 24 * 60 * 60];
    
    for (NSURL *fileURL in files) {
        NSDate *modificationDate;
        [fileURL getResourceValue:&modificationDate forKey:NSURLContentModificationDateKey error:nil];
        
        if (modificationDate && [modificationDate compare:sevenDaysAgo] == NSOrderedAscending) {
            [[NSFileManager defaultManager] removeItemAtURL:fileURL error:nil];
        }
    }
}

+ (void)convertVideoFormat:(NSString *)inputPath
              outputFormat:(SROutputFormat)outputFormat
                  callback:(void(^)(BOOL success, NSString * _Nullable outputPath, NSError * _Nullable error))callback {
    
    if (!callback) {
        return;
    }
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSError *error;
        NSString *outputPath;
        BOOL success = NO;
        
        switch (outputFormat) {
            case SROutputFormatMP4:
                // MP4转换：直接复制
                outputPath = [self generateOutputPathForFormat:outputFormat];
                success = [[NSFileManager defaultManager] copyItemAtPath:inputPath toPath:outputPath error:&error];
                break;
                
            case SROutputFormatGIF:
                // GIF转换
                outputPath = [self generateOutputPathForFormat:outputFormat];
                success = [self convertToGIF:inputPath outputPath:outputPath error:&error];
                break;
                
            case SROutputFormatWEBM:
            case SROutputFormatAVI:
                // 暂不支持，返回错误
                error = [NSError errorWithDomain:@"SRFileManager" code:3004 userInfo:@{NSLocalizedDescriptionKey: @"Format not supported"}];
                break;
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            callback(success, success ? outputPath : nil, error);
        });
    });
}

+ (BOOL)convertToGIF:(NSString *)inputPath outputPath:(NSString *)outputPath error:(NSError **)error {
    // 简化的GIF转换实现
    // 实际项目中应该使用更完善的GIF编码库
    
    AVAsset *asset = [AVAsset assetWithURL:[NSURL fileURLWithPath:inputPath]];
    if (!asset) {
        if (error) {
            *error = [NSError errorWithDomain:@"SRFileManager" code:3001 userInfo:@{NSLocalizedDescriptionKey: @"Invalid input file"}];
        }
        return NO;
    }
    
    // 获取视频时长
    CMTime duration = asset.duration;
    Float64 durationSeconds = CMTimeGetSeconds(duration);
    
    // 限制GIF时长（最长15秒）
    if (durationSeconds > 15.0) {
        if (error) {
            *error = [NSError errorWithDomain:@"SRFileManager" code:3002 userInfo:@{NSLocalizedDescriptionKey: @"Video too long for GIF conversion"}];
        }
        return NO;
    }
    
    // 创建图像生成器
    AVAssetImageGenerator *imageGenerator = [AVAssetImageGenerator assetImageGeneratorWithAsset:asset];
    imageGenerator.requestedTimeToleranceBefore = kCMTimeZero;
    imageGenerator.requestedTimeToleranceAfter = kCMTimeZero;
    imageGenerator.appliesPreferredTrackTransform = YES;
    
    // 设置最大尺寸
    imageGenerator.maximumSize = CGSizeMake(720, 720);
    
    // 计算帧数和时间间隔
    Float64 fps = 10.0; // GIF帧率
    NSInteger frameCount = (NSInteger)(durationSeconds * fps);
    CMTime frameDuration = CMTimeMakeWithSeconds(1.0 / fps, duration.timescale);
    
    // 创建GIF目标
    CGImageDestinationRef destination = CGImageDestinationCreateWithURL((__bridge CFURLRef)[NSURL fileURLWithPath:outputPath],
                                                                        kUTTypeGIF,
                                                                        frameCount,
                                                                        NULL);
    
    if (!destination) {
        if (error) {
            *error = [NSError errorWithDomain:@"SRFileManager" code:3003 userInfo:@{NSLocalizedDescriptionKey: @"Failed to create GIF destination"}];
        }
        return NO;
    }
    
    // 设置GIF属性
    NSDictionary *gifProperties = @{
        (NSString *)kCGImagePropertyGIFDictionary: @{
            (NSString *)kCGImagePropertyGIFLoopCount: @0, // 无限循环
            (NSString *)kCGImagePropertyGIFDelayTime: @(1.0 / fps)
        }
    };
    CGImageDestinationSetProperties(destination, (__bridge CFDictionaryRef)gifProperties);
    
    // 提取帧并添加到GIF
    for (NSInteger i = 0; i < frameCount; i++) {
        CMTime time = CMTimeMake(i, duration.timescale);
        time = CMTimeMultiplyByFloat64(time, 1.0 / fps);
        
        NSError *frameError;
        CGImageRef image = [imageGenerator copyCGImageAtTime:time actualTime:NULL error:&frameError];
        
        if (image) {
            // 设置帧属性
            NSDictionary *frameProperties = @{
                (NSString *)kCGImagePropertyGIFDictionary: @{
                    (NSString *)kCGImagePropertyGIFDelayTime: @(1.0 / fps)
                }
            };
            
            CGImageDestinationAddImage(destination, image, (__bridge CFDictionaryRef)frameProperties);
            CGImageRelease(image);
        }
    }
    
    // 完成GIF创建
    BOOL success = CGImageDestinationFinalize(destination);
    CFRelease(destination);
    
    if (!success && error) {
        *error = [NSError errorWithDomain:@"SRFileManager" code:3003 userInfo:@{NSLocalizedDescriptionKey: @"Failed to finalize GIF"}];
    }
    
    return success;
}

+ (BOOL)hasEnoughStorageSpace:(long long)requiredBytes {
    long long availableSpace = [self getAvailableStorageSpace];
    return availableSpace >= requiredBytes;
}

+ (long long)getAvailableStorageSpace {
    NSURL *documentsURL = [[[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] firstObject];
    
    NSError *error;
    NSDictionary *attributes = [[NSFileManager defaultManager] attributesOfFileSystemForPath:documentsURL.path error:&error];
    
    if (error) {
        NSLog(@"Failed to get storage space: %@", error.localizedDescription);
        return 0;
    }
    
    NSNumber *freeSpace = attributes[NSFileSystemFreeSize];
    return [freeSpace longLongValue];
}

@end
