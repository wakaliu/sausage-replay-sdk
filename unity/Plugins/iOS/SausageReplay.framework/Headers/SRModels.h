//
//  SRModels.h
//  SausageReplay
//
//  Created by Waka on 2025/10/10.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

// MARK: - 视频清晰度档位
typedef NS_ENUM(NSInteger, SRVideoQualityPreset) {
    SRVideoQualityPresetBasic = 0,      // 720p30
    SRVideoQualityPresetStandard = 1,   // 1080p30
    SRVideoQualityPresetSmooth = 2,     // 720p60
    SRVideoQualityPresetHighFps = 3,    // 1080p60
    SRVideoQualityPresetUltra = 4       // 1440p30/60
};




// MARK: - 录制状态
typedef NS_ENUM(NSInteger, SRRecordingStatus) {
    SRRecordingStatusIdle = 0,     // 空闲
    SRRecordingStatusStarting = 1, // 开始中
    SRRecordingStatusRecording = 2, // 录制中
    SRRecordingStatusStopping = 3  // 停止中
};

// MARK: - 视频质量等级
typedef NS_ENUM(NSInteger, SRVideoQuality) {
    SRVideoQualityLow = 0,    // 低质量 (480p)
    SRVideoQualityMedium = 1, // 中等质量 (720p)
    SRVideoQualityHigh = 2    // 高质量 (1080p)
};

// MARK: - 输出格式
typedef NS_ENUM(NSInteger, SROutputFormat) {
    SROutputFormatMP4 = 0,   // MP4格式
    SROutputFormatGIF = 1,   // GIF格式
    SROutputFormatWEBM = 2,  // WebM格式
    SROutputFormatAVI = 3    // AVI格式
};

// MARK: - 录制配置
@interface SRRecordingConfig : NSObject

@property (nonatomic, assign) SRVideoQualityPreset qualityPreset; // 视频清晰度档位
@property (nonatomic, assign) NSInteger maxDurationSeconds;     // 最大录制时长（秒）
@property (nonatomic, assign) long long maxFileSizeBytes;       // 最大文件大小（字节）
@property (nonatomic, assign) BOOL includeAudio;                // 是否包含音频
@property (nonatomic, assign) SROutputFormat outputFormat;      // 输出格式

+ (instancetype)defaultConfig;

@end

// MARK: - 录制结果
@interface SRRecordingResult : NSObject

@property (nonatomic, assign) BOOL isSuccess;                   // 是否成功
@property (nonatomic, copy, nullable) NSString *filePath;       // 文件路径
@property (nonatomic, assign) long long fileSize;               // 文件大小
@property (nonatomic, assign) float duration;                   // 录制时长
@property (nonatomic, assign) NSInteger errorCode;              // 错误码
@property (nonatomic, copy, nullable) NSString *errorMessage;   // 错误信息

+ (instancetype)successWithFilePath:(NSString *)filePath
                           fileSize:(long long)fileSize
                           duration:(float)duration;

+ (instancetype)failureWithErrorCode:(NSInteger)errorCode
                        errorMessage:(nullable NSString *)errorMessage;

@end


// MARK: - 详细状态信息
@interface SRDetailedStatus : NSObject

@property (nonatomic, assign) SRRecordingStatus status;         // 录制状态
@property (nonatomic, assign) BOOL isRecording;                 // 是否正在录制
@property (nonatomic, assign) BOOL isPaused;                    // 是否已暂停
@property (nonatomic, assign) long long duration;               // 录制时长
@property (nonatomic, assign) long long fileSize;               // 文件大小
@property (nonatomic, assign) NSInteger errorCode;              // 错误码
@property (nonatomic, copy, nullable) NSString *errorMessage;   // 错误信息

@end

// MARK: - 录制回调协议
@protocol SRRecordingCallback <NSObject>

@optional
- (void)onRecordingStarted;
- (void)onRecordingProgress:(long long)durationMs fileSizeBytes:(long long)fileSizeBytes;
- (void)onRecordingStopped:(SRRecordingResult *)result;
- (void)onRecordingError:(NSInteger)errorCode errorMessage:(nullable NSString *)errorMessage;

@end

NS_ASSUME_NONNULL_END
