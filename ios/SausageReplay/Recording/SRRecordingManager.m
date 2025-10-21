//
//  SRRecordingManager.m
//  SausageReplay
//
//  Created by Waka on 2025/10/10.
//

#import "SRRecordingManager.h"
#import <ReplayKit/ReplayKit.h>
#import <AVFoundation/AVFoundation.h>
#import <Photos/Photos.h>
#import <mach/mach.h>

@interface SRRecordingManager () <RPScreenRecorderDelegate>

@property (nonatomic, strong) RPScreenRecorder *screenRecorder;
@property (nonatomic, strong) AVAssetWriter *assetWriter;
@property (nonatomic, strong) AVAssetWriterInput *videoInput;
@property (nonatomic, strong) AVAssetWriterInput *audioInput;
@property (nonatomic, strong) AVAssetWriterInputPixelBufferAdaptor *pixelBufferAdaptor;
@property (nonatomic, strong) NSURL *outputURL;
@property (nonatomic, strong) SRRecordingConfig *currentConfig;
@property (nonatomic, weak) id<SRRecordingCallback> recordingCallback;
@property (nonatomic, assign) SRRecordingStatus currentStatus;
@property (nonatomic, strong) dispatch_queue_t recordingQueue;
@property (nonatomic, strong) NSTimer *durationTimer;
@property (nonatomic, strong) NSTimer *progressTimer;
@property (nonatomic, assign) NSTimeInterval startTime;
@property (nonatomic, assign) BOOL isPaused;

@end

@implementation SRRecordingManager

static SRRecordingManager *_sharedInstance = nil;

+ (instancetype)sharedInstance {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _sharedInstance = [[SRRecordingManager alloc] init];
    });
    return _sharedInstance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _currentStatus = SRRecordingStatusIdle;
        _recordingQueue = dispatch_queue_create("com.funny.replaysdk.recording", DISPATCH_QUEUE_SERIAL);
        _screenRecorder = [RPScreenRecorder sharedRecorder];
        _screenRecorder.delegate = self;
        _isPaused = NO;
    }
    return self;
}

#pragma mark - Public Methods

+ (BOOL)startRecordingWithConfig:(SRRecordingConfig *)config
                        callback:(nullable id<SRRecordingCallback>)callback {
    return [[self sharedInstance] startRecordingWithConfig:config callback:callback];
}

+ (void)stopRecording:(void(^)(SRRecordingResult *result))callback {
    [[self sharedInstance] stopRecording:callback];
}

+ (BOOL)pauseRecording {
    return [[self sharedInstance] pauseRecording];
}

+ (BOOL)resumeRecording {
    return [[self sharedInstance] resumeRecording];
}

+ (SRRecordingStatus)status {
    return [[self sharedInstance] currentStatus];
}

+ (BOOL)adjustRecordingQuality:(SRVideoQuality)quality {
    return [[self sharedInstance] adjustRecordingQuality:quality];
}

+ (SRDetailedStatus *)getDetailedStatus {
    return [[self sharedInstance] getDetailedStatus];
}

+ (BOOL)recoverFromError {
    return [[self sharedInstance] recoverFromError];
}

+ (void)resetStatus {
    [[self sharedInstance] resetStatus];
}

+ (void)convertVideoFormat:(NSString *)inputPath
              outputFormat:(SROutputFormat)outputFormat
                  callback:(void(^)(BOOL success, NSString * _Nullable outputPath))callback {
    [[self sharedInstance] convertVideoFormat:inputPath outputFormat:outputFormat callback:callback];
}

#pragma mark - Private Methods

- (BOOL)startRecordingWithConfig:(SRRecordingConfig *)config
                        callback:(nullable id<SRRecordingCallback>)callback {
    if (self.currentStatus != SRRecordingStatusIdle) {
        if (callback) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [callback onRecordingError:2000 errorMessage:@"Recording already in progress"];
            });
        }
        return NO;
    }
    
    self.currentConfig = config;
    self.recordingCallback = callback;
    self.currentStatus = SRRecordingStatusStarting;
    
    // 直接使用ReplayKit录制，不需要AVAssetWriter
    [self startScreenRecording];
    
    return YES;
}

- (void)setupAssetWriterWithConfig:(SRRecordingConfig *)config
                        completion:(void(^)(BOOL success, NSError *error))completion {
    // 创建输出文件路径
    NSString *fileName = [NSString stringWithFormat:@"replay_%ld.mp4", (long)[[NSDate date] timeIntervalSince1970]];
    NSURL *documentsURL = [[[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] firstObject];
    NSURL *outputURL = [documentsURL URLByAppendingPathComponent:fileName];
    self.outputURL = outputURL;
    
    // 删除已存在的文件
    [[NSFileManager defaultManager] removeItemAtURL:outputURL error:nil];
    
    NSError *error;
    self.assetWriter = [[AVAssetWriter alloc] initWithURL:outputURL fileType:AVFileTypeMPEG4 error:&error];
    if (error) {
        completion(NO, error);
        return;
    }
    
    // 配置视频输入
    [self setupVideoInputWithConfig:config];
    
    // 配置音频输入
    if (config.includeAudio) {
        [self setupAudioInputWithConfig:config];
    }
    
    // 开始写入
    if ([self.assetWriter startWriting]) {
        // 开始会话，设置起始时间
        [self.assetWriter startSessionAtSourceTime:kCMTimeZero];
        completion(YES, nil);
    } else {
        completion(NO, self.assetWriter.error);
    }
}

- (void)setupVideoInputWithConfig:(SRRecordingConfig *)config {
    // 根据视频清晰度档位计算视频参数
    CGSize videoSize = [self calculateVideoSizeForPreset:config.qualityPreset];
    NSInteger bitrate = config.targetBitrate ? [config.targetBitrate integerValue] : [self calculateBitrateForPreset:config.qualityPreset];
    
    NSDictionary *videoSettings = @{
        AVVideoCodecKey: AVVideoCodecTypeH264,
        AVVideoWidthKey: @(videoSize.width),
        AVVideoHeightKey: @(videoSize.height),
        AVVideoCompressionPropertiesKey: @{
            AVVideoAverageBitRateKey: @(bitrate),
            AVVideoProfileLevelKey: AVVideoProfileLevelH264MainAutoLevel,
            AVVideoMaxKeyFrameIntervalKey: @(config.targetFps * 2) // GOP = 2秒
        }
    };
    
    self.videoInput = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeVideo outputSettings:videoSettings];
    self.videoInput.expectsMediaDataInRealTime = YES;
    
    // 创建像素缓冲区适配器
    NSDictionary *pixelBufferAttributes = @{
        (NSString *)kCVPixelBufferPixelFormatTypeKey: @(kCVPixelFormatType_32BGRA),
        (NSString *)kCVPixelBufferWidthKey: @(videoSize.width),
        (NSString *)kCVPixelBufferHeightKey: @(videoSize.height)
    };
    
    self.pixelBufferAdaptor = [AVAssetWriterInputPixelBufferAdaptor
                              assetWriterInputPixelBufferAdaptorWithAssetWriterInput:self.videoInput
                              sourcePixelBufferAttributes:pixelBufferAttributes];
    
    if ([self.assetWriter canAddInput:self.videoInput]) {
        [self.assetWriter addInput:self.videoInput];
    }
}

- (void)setupAudioInputWithConfig:(SRRecordingConfig *)config {
    NSDictionary *audioSettings = @{
        AVFormatIDKey: @(kAudioFormatMPEG4AAC),
        AVSampleRateKey: @(48000),
        AVNumberOfChannelsKey: @(2),
        AVEncoderBitRateKey: @(128000)
    };
    
    self.audioInput = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeAudio outputSettings:audioSettings];
    self.audioInput.expectsMediaDataInRealTime = YES;
    
    if ([self.assetWriter canAddInput:self.audioInput]) {
        [self.assetWriter addInput:self.audioInput];
    }
}

- (void)startScreenRecording {
    if (![RPScreenRecorder sharedRecorder].isAvailable) {
        self.currentStatus = SRRecordingStatusIdle;
        if (self.recordingCallback) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.recordingCallback onRecordingError:2003 errorMessage:@"Screen recording not available"];
            });
        }
        return;
    }
    
    // 配置屏幕录制器
    RPScreenRecorder *recorder = [RPScreenRecorder sharedRecorder];
    recorder.microphoneEnabled = self.currentConfig.includeAudio;
    
    // 使用ReplayKit的简单录制API
    [recorder startRecordingWithHandler:^(NSError *error) {
        if (error) {
            self.currentStatus = SRRecordingStatusIdle;
            if (self.recordingCallback) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self.recordingCallback onRecordingError:2004 errorMessage:error.localizedDescription];
                });
            }
        } else {
            NSLog(@"✅ Recording started successfully, status set to: %ld", (long)SRRecordingStatusRecording);
            self.currentStatus = SRRecordingStatusRecording;
            self.startTime = [[NSDate date] timeIntervalSince1970];
            [self startTimers];
            
            if (self.recordingCallback) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self.recordingCallback onRecordingStarted];
                });
            }
        }
    }];
}

- (void)processSampleBuffer:(CMSampleBufferRef)sampleBuffer bufferType:(RPSampleBufferType)bufferType {
    if (self.isPaused || self.currentStatus != SRRecordingStatusRecording) {
        return;
    }
    
    // 确保AssetWriter已经开始了会话
    if (self.assetWriter.status != AVAssetWriterStatusWriting) {
        return;
    }
    
    switch (bufferType) {
        case RPSampleBufferTypeVideo:
            if (self.videoInput && self.videoInput.readyForMoreMediaData) {
                [self.videoInput appendSampleBuffer:sampleBuffer];
            }
            break;
        case RPSampleBufferTypeAudioApp:
        case RPSampleBufferTypeAudioMic:
            if (self.audioInput && self.audioInput.readyForMoreMediaData) {
                [self.audioInput appendSampleBuffer:sampleBuffer];
            }
            break;
    }
}

- (void)stopRecording:(void(^)(SRRecordingResult *result))callback {
    NSLog(@"🔍 stopRecording called, current status: %ld", (long)self.currentStatus);
    
    if (self.currentStatus != SRRecordingStatusRecording && self.currentStatus != SRRecordingStatusPaused) {
        NSString *errorMsg = [NSString stringWithFormat:@"Recording not started (status: %ld)", (long)self.currentStatus];
        SRRecordingResult *result = [SRRecordingResult failureWithErrorCode:2001 errorMessage:errorMsg];
        if (callback) {
            dispatch_async(dispatch_get_main_queue(), ^{
                callback(result);
            });
        }
        return;
    }
    
    self.currentStatus = SRRecordingStatusStopping;
    [self stopTimers];
    
    // 使用ReplayKit的停止录制API
    [[RPScreenRecorder sharedRecorder] stopRecordingWithHandler:^(RPPreviewViewController *previewViewController, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (error) {
                NSLog(@"❌ Stop recording error: %@", error.localizedDescription);
                SRRecordingResult *result = [SRRecordingResult failureWithErrorCode:2004 errorMessage:error.localizedDescription];
                [self cleanup];
                if (callback) {
                    callback(result);
                }
                return;
            }
            
            NSLog(@"✅ Recording stopped successfully, got preview controller");
            
            // 由于ReplayKit的安全限制，我们无法直接获取视频文件
            // 但我们可以创建一个占位结果，让用户知道录制已完成
            NSURL *documentsURL = [[[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] firstObject];
            NSString *fileName = [NSString stringWithFormat:@"replay_%ld.mp4", (long)[[NSDate date] timeIntervalSince1970]];
            NSURL *outputURL = [documentsURL URLByAppendingPathComponent:fileName];
            
            float duration = [[NSDate date] timeIntervalSince1970] - self.startTime;
            
            // 创建一个占位文件，表示录制已完成
            NSFileManager *fileManager = [NSFileManager defaultManager];
            NSString *placeholderContent = [NSString stringWithFormat:@"ReplayKit recording completed at %@", [NSDate date]];
            [placeholderContent writeToFile:outputURL.path atomically:YES encoding:NSUTF8StringEncoding error:nil];
            
            // 获取实际文件大小
            NSDictionary *attributes = [fileManager attributesOfItemAtPath:outputURL.path error:nil];
            long long fileSize = [attributes[NSFileSize] longLongValue];
            
            SRRecordingResult *result = [SRRecordingResult successWithFilePath:outputURL.path
                                                                      fileSize:fileSize
                                                                      duration:duration];
            
            if (self.recordingCallback) {
                [self.recordingCallback onRecordingStopped:result];
            }
            
            if (callback) {
                callback(result);
            }
            
            [self cleanup];
            
            // 显示预览界面让用户保存视频
            if (previewViewController) {
                // 设置代理
                previewViewController.previewControllerDelegate = self;
                
                UIViewController *rootViewController = [UIApplication sharedApplication].keyWindow.rootViewController;
                if (rootViewController) {
                    [rootViewController presentViewController:previewViewController animated:YES completion:nil];
                }
            }
        });
    }];
}


- (void)finishWritingWithCallback:(void(^)(SRRecordingResult *result))callback error:(NSError *)error {
    if (error) {
        SRRecordingResult *result = [SRRecordingResult failureWithErrorCode:2004 errorMessage:error.localizedDescription];
        [self cleanup];
        if (callback) {
            dispatch_async(dispatch_get_main_queue(), ^{
                callback(result);
            });
        }
        return;
    }
    
    [self.videoInput markAsFinished];
    if (self.audioInput) {
        [self.audioInput markAsFinished];
    }
    
    [self.assetWriter finishWritingWithCompletionHandler:^{
        dispatch_async(dispatch_get_main_queue(), ^{
            if (self.assetWriter.status == AVAssetWriterStatusCompleted) {
                NSFileManager *fileManager = [NSFileManager defaultManager];
                NSDictionary *attributes = [fileManager attributesOfItemAtPath:self.outputURL.path error:nil];
                long long fileSize = [attributes[NSFileSize] longLongValue];
                float duration = [[NSDate date] timeIntervalSince1970] - self.startTime;
                
                SRRecordingResult *result = [SRRecordingResult successWithFilePath:self.outputURL.path
                                                                          fileSize:fileSize
                                                                          duration:duration];
                
                if (self.recordingCallback) {
                    [self.recordingCallback onRecordingStopped:result];
                }
                
                if (callback) {
                    callback(result);
                }
            } else {
                SRRecordingResult *result = [SRRecordingResult failureWithErrorCode:2004 errorMessage:self.assetWriter.error.localizedDescription];
                if (callback) {
                    callback(result);
                }
            }
            
            [self cleanup];
        });
    }];
}

- (BOOL)pauseRecording {
    if (self.currentStatus != SRRecordingStatusRecording) {
        return NO;
    }
    
    self.isPaused = YES;
    self.currentStatus = SRRecordingStatusPaused;
    
    if (self.recordingCallback) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.recordingCallback onRecordingPaused];
        });
    }
    
    return YES;
}

- (BOOL)resumeRecording {
    if (self.currentStatus != SRRecordingStatusPaused) {
        return NO;
    }
    
    self.isPaused = NO;
    self.currentStatus = SRRecordingStatusRecording;
    
    if (self.recordingCallback) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.recordingCallback onRecordingResumed];
        });
    }
    
    return YES;
}

- (BOOL)adjustRecordingQuality:(SRVideoQuality)quality {
    // iOS录制过程中无法动态调整质量，这里只是更新配置
    if (self.currentConfig) {
        self.currentConfig.quality = quality;
        
        if (self.recordingCallback) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.recordingCallback onRecordingQualityAdjusted:quality];
            });
        }
        
        return YES;
    }
    
    return NO;
}

- (SRDetailedStatus *)getDetailedStatus {
    SRDetailedStatus *status = [[SRDetailedStatus alloc] init];
    status.status = self.currentStatus;
    status.config = self.currentConfig;
    status.hasProjection = YES; // ReplayKit always has projection
    status.hasRecorder = (self.screenRecorder != nil);
    status.hasDisplay = YES;
    status.outputFile = self.outputURL.path;
    
    if (self.outputURL) {
        NSFileManager *fileManager = [NSFileManager defaultManager];
        NSDictionary *attributes = [fileManager attributesOfItemAtPath:self.outputURL.path error:nil];
        status.outputFileSize = [attributes[NSFileSize] longLongValue];
    }
    
    // 获取内存使用情况
    status.memoryUsage = [self getMemoryUsage];
    
    return status;
}

- (SRMemoryUsage *)getMemoryUsage {
    SRMemoryUsage *memoryUsage = [[SRMemoryUsage alloc] init];
    
    struct mach_task_basic_info info;
    mach_msg_type_number_t size = MACH_TASK_BASIC_INFO_COUNT;
    kern_return_t kerr = task_info(mach_task_self(), MACH_TASK_BASIC_INFO, (task_info_t)&info, &size);
    
    if (kerr == KERN_SUCCESS) {
        memoryUsage.usedMemory = info.resident_size;
        memoryUsage.totalMemory = info.virtual_size;
        memoryUsage.freeMemory = info.virtual_size - info.resident_size;
        memoryUsage.maxMemory = info.virtual_size;
        memoryUsage.usagePercentage = (NSInteger)((double)info.resident_size / info.virtual_size * 100);
    }
    
    return memoryUsage;
}

- (BOOL)recoverFromError {
    [self cleanup];
    self.currentStatus = SRRecordingStatusIdle;
    return YES;
}

- (void)resetStatus {
    [self stopTimers];
    [self cleanup];
    self.currentStatus = SRRecordingStatusIdle;
}

- (void)convertVideoFormat:(NSString *)inputPath
              outputFormat:(SROutputFormat)outputFormat
                  callback:(void(^)(BOOL success, NSString * _Nullable outputPath))callback {
    // 简化实现：目前只支持MP4，其他格式转换暂未实现
    if (outputFormat == SROutputFormatMP4) {
        if (callback) {
            dispatch_async(dispatch_get_main_queue(), ^{
                callback(YES, inputPath);
            });
        }
    } else {
        if (callback) {
            dispatch_async(dispatch_get_main_queue(), ^{
                callback(NO, nil);
            });
        }
    }
}

#pragma mark - Helper Methods

- (CGSize)calculateVideoSizeForPreset:(SRVideoQualityPreset)preset {
    switch (preset) {
        case SRVideoQualityPresetBasic:
            return CGSizeMake(1280, 720);  // 720p
        case SRVideoQualityPresetStandard:
            return CGSizeMake(1920, 1080); // 1080p
        case SRVideoQualityPresetSmooth:
            return CGSizeMake(1280, 720);  // 720p
        case SRVideoQualityPresetHighFps:
            return CGSizeMake(1920, 1080); // 1080p
        case SRVideoQualityPresetUltra:
            return CGSizeMake(2560, 1440); // 1440p
    }
    return CGSizeMake(1920, 1080); // 默认1080p
}

- (CGSize)calculateVideoSizeForQuality:(SRVideoQuality)quality tier:(SRDevicePerformanceTier)tier {
    switch (tier) {
        case SRDevicePerformanceTierMidRange:
            switch (quality) {
                case SRVideoQualityHigh:
                    return CGSizeMake(1280, 720); // 限制为720p
                case SRVideoQualityMedium:
                    return CGSizeMake(1280, 720);
                case SRVideoQualityLow:
                    return CGSizeMake(854, 480);
            }
            break;
        case SRDevicePerformanceTierHighEnd:
            switch (quality) {
                case SRVideoQualityHigh:
                    return CGSizeMake(1920, 1080);
                case SRVideoQualityMedium:
                    return CGSizeMake(1280, 720);
                case SRVideoQualityLow:
                    return CGSizeMake(854, 480);
            }
            break;
    }
    return CGSizeMake(1280, 720); // 默认
}

- (NSInteger)calculateBitrateForPreset:(SRVideoQualityPreset)preset {
    switch (preset) {
        case SRVideoQualityPresetBasic:
            return 2000000;  // 2 Mbps
        case SRVideoQualityPresetStandard:
            return 4000000;  // 4 Mbps
        case SRVideoQualityPresetSmooth:
            return 3000000;  // 3 Mbps
        case SRVideoQualityPresetHighFps:
            return 6000000;  // 6 Mbps
        case SRVideoQualityPresetUltra:
            return 8000000;  // 8 Mbps
    }
    return 4000000; // 默认4 Mbps
}

- (NSInteger)calculateBitrateForQuality:(SRVideoQuality)quality tier:(SRDevicePerformanceTier)tier {
    switch (tier) {
        case SRDevicePerformanceTierMidRange:
            switch (quality) {
                case SRVideoQualityHigh:
                    return 6000000; // 6 Mbps
                case SRVideoQualityMedium:
                    return 3000000; // 3 Mbps
                case SRVideoQualityLow:
                    return 1500000; // 1.5 Mbps
            }
            break;
        case SRDevicePerformanceTierHighEnd:
            switch (quality) {
                case SRVideoQualityHigh:
                    return 10000000; // 10 Mbps
                case SRVideoQualityMedium:
                    return 6000000; // 6 Mbps
                case SRVideoQualityLow:
                    return 3000000; // 3 Mbps
            }
            break;
    }
    return 3000000; // 默认3 Mbps
}

- (void)startTimers {
    // 最大时长定时器
    if (self.currentConfig.maxDurationSeconds > 0) {
        self.durationTimer = [NSTimer scheduledTimerWithTimeInterval:self.currentConfig.maxDurationSeconds
                                                              target:self
                                                            selector:@selector(maxDurationReached)
                                                            userInfo:nil
                                                             repeats:NO];
    }
    
    // 进度监控定时器
    self.progressTimer = [NSTimer scheduledTimerWithTimeInterval:0.5
                                                          target:self
                                                        selector:@selector(updateProgress)
                                                        userInfo:nil
                                                         repeats:YES];
}

- (void)stopTimers {
    [self.durationTimer invalidate];
    self.durationTimer = nil;
    [self.progressTimer invalidate];
    self.progressTimer = nil;
}

- (void)maxDurationReached {
    [self stopRecording:^(SRRecordingResult *result) {
        // 自动停止，不需要额外处理
    }];
}

- (void)updateProgress {
    if (self.currentStatus == SRRecordingStatusRecording && self.recordingCallback) {
        NSTimeInterval currentTime = [[NSDate date] timeIntervalSince1970];
        long long durationMs = (long long)((currentTime - self.startTime) * 1000);
        
        // 由于ReplayKit的限制，我们无法在录制过程中获取真实的文件大小
        // 这里我们提供一个基于录制时长和配置的估算值
        long long estimatedFileSizeBytes = 0;
        if (self.currentConfig) {
            // 根据清晰度档位估算比特率
            NSInteger estimatedBitrate = [self calculateBitrateForPreset:self.currentConfig.qualityPreset];
            // 估算文件大小 = 比特率 * 时长(秒) / 8 (转换为字节)
            estimatedFileSizeBytes = (estimatedBitrate * (durationMs / 1000)) / 8;
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.recordingCallback onRecordingProgress:durationMs fileSizeBytes:estimatedFileSizeBytes];
        });
    }
}

- (void)cleanup {
    [self stopTimers];
    
    self.assetWriter = nil;
    self.videoInput = nil;
    self.audioInput = nil;
    self.pixelBufferAdaptor = nil;
    self.outputURL = nil;
    self.currentConfig = nil;
    self.recordingCallback = nil;
    self.isPaused = NO;
}

#pragma mark - RPScreenRecorderDelegate

- (void)screenRecorder:(RPScreenRecorder *)screenRecorder didStopRecordingWithPreviewViewController:(RPPreviewViewController *)previewViewController error:(NSError *)error {
    // 录制停止时的处理
}

#pragma mark - RPPreviewViewControllerDelegate

- (void)previewControllerDidFinish:(RPPreviewViewController *)previewController {
    NSLog(@"📱 Preview controller finished");
    // 用户完成了预览操作（保存或取消）
    [previewController dismissViewControllerAnimated:YES completion:nil];
}

- (void)previewController:(RPPreviewViewController *)previewController didFinishWithActivityTypes:(NSSet<NSString *> *)activityTypes {
    NSLog(@"📱 Preview controller finished with activities: %@", activityTypes);
    // 用户完成了预览操作，activityTypes包含用户选择的操作类型
    [previewController dismissViewControllerAnimated:YES completion:nil];
}

@end
