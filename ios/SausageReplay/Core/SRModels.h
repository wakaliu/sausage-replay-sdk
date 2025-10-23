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

// MARK: - 录制配置
@interface SRRecordingConfig : NSObject

@property (nonatomic, assign) SRVideoQualityPreset qualityPreset; // 视频清晰度档位
@property (nonatomic, assign) NSInteger maxDurationSeconds;     // 最大录制时长（秒）
@property (nonatomic, assign) long long maxFileSizeBytes;       // 最大文件大小（字节）
@property (nonatomic, assign) BOOL includeAudio;                // 是否包含音频
@property (nonatomic, copy, nullable) NSString *outputPath;     // 输出路径
@property (nonatomic, assign, nullable) NSNumber *targetBitrate; // 目标比特率
@property (nonatomic, assign) NSInteger targetFps;              // 目标帧率

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
@property (nonatomic, strong, nullable) SRRecordingConfig *config; // 当前配置
@property (nonatomic, assign) BOOL hasProjection;               // 是否有投影
@property (nonatomic, assign) BOOL hasRecorder;                 // 是否有录制器
@property (nonatomic, assign) BOOL hasDisplay;                  // 是否有显示
@property (nonatomic, copy, nullable) NSString *outputFile;     // 输出文件
@property (nonatomic, assign) long long outputFileSize;         // 输出文件大小

@end

// MARK: - 设备档位信息（已废弃）
@interface SRDeviceTierInfo : NSObject

@property (nonatomic, assign) SRVideoQualityPreset preset;     // 视频清晰度档位
@property (nonatomic, copy) NSString *tierName;                 // 档位名称
@property (nonatomic, assign) NSInteger maxWidth;               // 最大宽度
@property (nonatomic, assign) NSInteger maxHeight;              // 最大高度
@property (nonatomic, assign) NSInteger targetFps;              // 目标帧率
@property (nonatomic, assign) long long videoBitrate;           // 视频比特率
@property (nonatomic, assign) BOOL gifSupported;                // 是否支持GIF

@end


// MARK: - 性能指标
@interface SRPerformanceMetrics : NSObject

@property (nonatomic, assign) NSInteger currentFps;             // 当前帧率
@property (nonatomic, assign) double frameDropRate;             // 丢帧率
@property (nonatomic, assign) NSInteger queueDepth;             // 队列深度
@property (nonatomic, assign) long long encodingBlockTime;      // 编码阻塞时间
@property (nonatomic, assign) long long totalFrames;            // 总帧数
@property (nonatomic, assign) long long droppedFrames;          // 丢帧数

@end

// MARK: - 权限结果
@interface SRPermissionResult : NSObject

@property (nonatomic, assign) BOOL isGranted;                   // 是否授权
@property (nonatomic, assign) NSInteger errorCode;              // 错误码
@property (nonatomic, copy, nullable) NSString *errorMessage;   // 错误信息

+ (instancetype)granted;
+ (instancetype)deniedWithErrorCode:(NSInteger)errorCode errorMessage:(nullable NSString *)errorMessage;

@end

// MARK: - 录制回调协议
@protocol SRRecordingCallback <NSObject>

@optional
- (void)onRecordingStarted;
- (void)onRecordingProgress:(long long)durationMs fileSizeBytes:(long long)fileSizeBytes;
- (void)onRecordingStopped:(SRRecordingResult *)result;
- (void)onRecordingError:(NSInteger)errorCode errorMessage:(nullable NSString *)errorMessage;

@end

// MARK: - 性能监控回调协议
@protocol SRPerformanceCallback <NSObject>

@optional
- (void)onPerformanceMetrics:(SRPerformanceMetrics *)metrics;
- (void)onBitrateReduction:(double)reduction;
- (void)onBitrateRecovery:(double)reduction;
- (void)onResolutionDegradation:(NSInteger)width height:(NSInteger)height;
- (void)onResolutionRecovery:(NSInteger)width height:(NSInteger)height;
- (void)onFpsDegradation:(NSInteger)fps;
- (void)onFpsRecovery:(NSInteger)fps;

@end

NS_ASSUME_NONNULL_END
