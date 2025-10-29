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
#import "SRPermissionManager.h"
#import <VideoToolbox/VideoToolbox.h>
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
@property (nonatomic, assign) BOOL hasStartedWriterSession;
// 直接追加写入，不使用队列式 draining，避免状态0时机问题

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
        _hasStartedWriterSession = NO;
    }
    return self;
}

#pragma mark - Public Methods

+ (BOOL)startRecordingWithConfig:(SRRecordingConfig *)config
                        callback:(nullable id<SRRecordingCallback>)callback {
    return [[self sharedInstance] startRecordingWithConfig:config callback:callback];
}

+ (BOOL)startRecordingWithCallback:(nullable id<SRRecordingCallback>)callback {
    SRRecordingConfig *config = [SRRecordingConfig defaultConfig];
    // 强制仅 MP4
    config.outputFormat = SROutputFormatMP4;
    return [self startRecordingWithConfig:config callback:callback];
}

+ (void)stopRecording:(void(^)(SRRecordingResult *result))callback {
    [[self sharedInstance] stopRecording:callback];
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
    
    // 使用 ReplayKit startCapture + AVAssetWriter，强制 MP4(H.264+AAC)
    __weak typeof(self) weakSelf = self;
    [self setupAssetWriterWithConfig:config completion:^(BOOL success, NSError *error) {
        if (!success) {
            weakSelf.currentStatus = SRRecordingStatusIdle;
            if (weakSelf.recordingCallback) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [weakSelf.recordingCallback onRecordingError:2005 errorMessage:error.localizedDescription ?: @"Failed to init writer"];
                });
            }
            return;
        }
        [weakSelf startScreenRecording];
    }];
    
    return YES;
}

- (void)setupAssetWriterWithConfig:(SRRecordingConfig *)config
                        completion:(void(^)(BOOL success, NSError *error))completion {
    // 创建输出文件路径（使用临时目录，后续保存到相册后删除，不在沙盒长期保留）
    NSString *fileName = [NSString stringWithFormat:@"replay_%ld.mp4", (long)[[NSDate date] timeIntervalSince1970]];
    NSString *tempDir = NSTemporaryDirectory();
    NSURL *outputURL = [NSURL fileURLWithPath:[tempDir stringByAppendingPathComponent:fileName]];
    self.outputURL = outputURL;
    
    // 删除已存在的文件
    [[NSFileManager defaultManager] removeItemAtURL:outputURL error:nil];
    
    // 延迟到首帧再创建 AVAssetWriter 与输入，避免 status=0 时序问题
    self.assetWriter = nil;
    self.videoInput = nil;
    self.audioInput = nil;
    self.hasStartedWriterSession = NO;
    completion(YES, nil);
}

// 基于首帧动态创建视频输入（使用 sourceFormatHint，直接 append CMSampleBuffer）
- (void)ensureVideoInputFromSampleBuffer:(CMSampleBufferRef)sampleBuffer config:(SRRecordingConfig *)config {
    if (self.videoInput) return;
    // 若尚未创建 writer，则此处创建
    if (!self.assetWriter) {
        NSError *err = nil;
        self.assetWriter = [[AVAssetWriter alloc] initWithURL:self.outputURL fileType:AVFileTypeMPEG4 error:&err];
        if (err) { NSLog(@"create writer failed: %@", err.localizedDescription); return; }
    }
    CMFormatDescriptionRef vfmt = CMSampleBufferGetFormatDescription(sampleBuffer);
    if (!vfmt) return;
    CMVideoDimensions dims = CMVideoFormatDescriptionGetDimensions(vfmt);
    NSInteger bitrate = [self calculateBitrateForPreset:config.qualityPreset];
    // 优先 60fps 画质
    NSInteger expectedFps = 60;
    if (expectedFps == 60) {
        bitrate = (NSInteger)(bitrate * 1.3); // 60fps 提升码率
    }

    // 优先 HEVC（iOS 11+），若设备不支持会在创建input时失败并回退H.264
    NSString *preferredCodec = AVVideoCodecTypeH264;
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 110000
    if (@available(iOS 11.0, *)) {
        preferredCodec = AVVideoCodecTypeHEVC; // iOS 11+ 尝试HEVC
    }
#endif

    // 构建压缩属性（根据编码器类型）
    NSMutableDictionary *compressionProps = [NSMutableDictionary dictionaryWithDictionary:@{
        AVVideoAverageBitRateKey: @(bitrate),
        AVVideoExpectedSourceFrameRateKey: @(expectedFps),
        AVVideoAllowFrameReorderingKey: @NO,
        AVVideoMaxKeyFrameIntervalKey: @(expectedFps * 2)
    }];
    
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 110000
    if ([preferredCodec isEqualToString:AVVideoCodecTypeHEVC]) {
        compressionProps[AVVideoProfileLevelKey] = (__bridge NSString *)kVTProfileLevel_HEVC_Main_AutoLevel;
    } else {
        compressionProps[AVVideoProfileLevelKey] = AVVideoProfileLevelH264HighAutoLevel;
        compressionProps[AVVideoH264EntropyModeKey] = AVVideoH264EntropyModeCABAC;
    }
#else
    compressionProps[AVVideoProfileLevelKey] = AVVideoProfileLevelH264HighAutoLevel;
    compressionProps[AVVideoH264EntropyModeKey] = AVVideoH264EntropyModeCABAC;
#endif
    
    NSDictionary *videoSettings = @{
        AVVideoCodecKey: preferredCodec,
        AVVideoWidthKey: @(dims.width),
        AVVideoHeightKey: @(dims.height),
        AVVideoCompressionPropertiesKey: compressionProps
    };
    self.videoInput = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeVideo outputSettings:videoSettings sourceFormatHint:vfmt];
    self.videoInput.expectsMediaDataInRealTime = YES;
    self.videoInput.transform = CGAffineTransformIdentity;
    
    // 如果HEVC不支持，回退到H.264
    if (![self.assetWriter canAddInput:self.videoInput] && [preferredCodec isEqualToString:AVVideoCodecTypeHEVC]) {
        // 回退到H.264
        NSMutableDictionary *h264Props = [compressionProps mutableCopy];
        h264Props[AVVideoProfileLevelKey] = AVVideoProfileLevelH264HighAutoLevel;
        h264Props[AVVideoH264EntropyModeKey] = AVVideoH264EntropyModeCABAC;
        
        NSDictionary *h264Settings = @{
            AVVideoCodecKey: AVVideoCodecTypeH264,
            AVVideoWidthKey: @(dims.width),
            AVVideoHeightKey: @(dims.height),
            AVVideoCompressionPropertiesKey: h264Props
        };
        
        self.videoInput = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeVideo outputSettings:h264Settings sourceFormatHint:vfmt];
        self.videoInput.expectsMediaDataInRealTime = YES;
        self.videoInput.transform = CGAffineTransformIdentity;
    }
    
    if ([self.assetWriter canAddInput:self.videoInput]) {
        [self.assetWriter addInput:self.videoInput];
    }
    // 确保调用 startWriting 与 startSessionAtSourceTime
    if (self.assetWriter.status == AVAssetWriterStatusUnknown) { [self.assetWriter startWriting]; }
}

// 懒创建音频输入（使用 sourceFormatHint）
- (void)ensureAudioInputFromSampleBuffer:(CMSampleBufferRef)sampleBuffer config:(SRRecordingConfig *)config {
    if (self.audioInput || !config.includeAudio) return;
    if (!self.assetWriter) return;
    CMFormatDescriptionRef afmt = CMSampleBufferGetFormatDescription(sampleBuffer);
    if (!afmt) return;
    NSDictionary *audioSettings = @{
        AVFormatIDKey: @(kAudioFormatMPEG4AAC),
        AVSampleRateKey: @(48000),
        AVNumberOfChannelsKey: @(2),
        AVEncoderBitRateKey: @(128000)
    };
    self.audioInput = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeAudio outputSettings:audioSettings sourceFormatHint:afmt];
    self.audioInput.expectsMediaDataInRealTime = YES;
    if ([self.assetWriter canAddInput:self.audioInput]) { [self.assetWriter addInput:self.audioInput]; }
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
    
    // 配置屏幕录制器并开始捕获 SampleBuffer
    RPScreenRecorder *recorder = [RPScreenRecorder sharedRecorder];
    recorder.microphoneEnabled = self.currentConfig.includeAudio;
    __weak typeof(self) weakSelf = self;
    [recorder startCaptureWithHandler:^(CMSampleBufferRef  _Nonnull sampleBuffer, RPSampleBufferType bufferType, NSError * _Nullable error) {
        if (error) {
            NSLog(@"❌ Capture error: %@", error.localizedDescription);
            return;
        }
        // 精简日志：去除首帧提示
        [weakSelf processSampleBuffer:sampleBuffer bufferType:bufferType];
    } completionHandler:^(NSError * _Nullable error) {
        if (error) {
            weakSelf.currentStatus = SRRecordingStatusIdle;
            if (weakSelf.recordingCallback) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [weakSelf.recordingCallback onRecordingError:2004 errorMessage:error.localizedDescription];
                });
            }
            return;
        }
        NSLog(@"✅ Recording started successfully, status set to: %ld", (long)SRRecordingStatusRecording);
        weakSelf.currentStatus = SRRecordingStatusRecording;
        weakSelf.startTime = [[NSDate date] timeIntervalSince1970];
        [weakSelf startTimers];
        if (weakSelf.recordingCallback) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [weakSelf.recordingCallback onRecordingStarted];
            });
        }
    }];
}

- (void)processSampleBuffer:(CMSampleBufferRef)sampleBuffer bufferType:(RPSampleBufferType)bufferType {
    if (self.isPaused || self.currentStatus != SRRecordingStatusRecording) {
        return;
    }
    
    // 仅在发生失败时提前返回
    if (self.assetWriter.status == AVAssetWriterStatusFailed) {
        NSLog(@"assetWriter failed: %@", self.assetWriter.error.localizedDescription);
        return;
    }
    
    switch (bufferType) {
        case RPSampleBufferTypeVideo:
            // 确保视频输入按首帧尺寸创建
            [self ensureVideoInputFromSampleBuffer:sampleBuffer config:self.currentConfig];
            // 确保 writer 已进入 Writing；若仍为 Unknown，这里补发 startWriting
            if (self.assetWriter && self.assetWriter.status == AVAssetWriterStatusUnknown) {
                [self.assetWriter startWriting];
            }
            // 在首帧视频到达时，用其时间戳启动会话
            if (!self.hasStartedWriterSession) {
                CMTime pts = CMSampleBufferGetPresentationTimeStamp(sampleBuffer);
                [self.assetWriter startSessionAtSourceTime:pts];
                self.hasStartedWriterSession = YES;
            }
            if (self.videoInput && CMSampleBufferDataIsReady(sampleBuffer) && self.videoInput.isReadyForMoreMediaData) {
                BOOL ok = [self.videoInput appendSampleBuffer:sampleBuffer];
                if (!ok) NSLog(@"append video failed: %@", self.assetWriter.error.localizedDescription);
            }
            break;
        case RPSampleBufferTypeAudioApp:
        case RPSampleBufferTypeAudioMic:
            // 仅在视频会话已启动后写入音频，保证时间线一致
            if (self.hasStartedWriterSession) {
                [self ensureAudioInputFromSampleBuffer:sampleBuffer config:self.currentConfig];
                if (self.audioInput && CMSampleBufferDataIsReady(sampleBuffer) && self.audioInput.isReadyForMoreMediaData) {
                    BOOL ok = [self.audioInput appendSampleBuffer:sampleBuffer];
                    if (!ok) NSLog(@"append audio failed: %@", self.assetWriter.error.localizedDescription);
                }
            }
            break;
    }
}

- (void)stopRecording:(void(^)(SRRecordingResult *result))callback {
    NSLog(@"🔍 stopRecording called, current status: %ld", (long)self.currentStatus);
    
    if (self.currentStatus != SRRecordingStatusRecording) {
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
    
    // 使用 startCapture 路径：停止捕获 -> 完成写入 -> 保存到相册
    [[RPScreenRecorder sharedRecorder] stopCaptureWithHandler:^(NSError * _Nullable error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (error) {
                NSLog(@"❌ Stop capture error: %@", error.localizedDescription);
                SRRecordingResult *result = [SRRecordingResult failureWithErrorCode:2004 errorMessage:error.localizedDescription];
                [self cleanup];
                if (callback) { callback(result); }
                return;
            }
            [self finishWritingWithCallback:^(SRRecordingResult *result) {
                // 保存到相册
                [self saveOutputToPhotoLibrary:self.outputURL completion:^(BOOL success, NSString * _Nullable localId, NSError * _Nullable err) {
                    // 成功后删除临时文件；失败则保留以便排查
                    if (success && self.outputURL) {
                        [[NSFileManager defaultManager] removeItemAtURL:self.outputURL error:nil];
                    }

                    // 回调时不返回本地沙盒路径
                    SRRecordingResult *finalResult = [[SRRecordingResult alloc] init];
                    finalResult.isSuccess = result.isSuccess && success;
                    finalResult.filePath = nil; // 不返回沙盒路径
                    finalResult.fileSize = result.fileSize;
                    finalResult.duration = result.duration;
                    finalResult.errorCode = success ? 0 : 1203;
                    finalResult.errorMessage = success ? nil : (err.localizedDescription ?: @"Save to Photos failed");

                    if (self.recordingCallback) { [self.recordingCallback onRecordingStopped:finalResult]; }
                    if (callback) { callback(finalResult); }

                    [self cleanup];
                }];
            } error:nil];
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
    
    // 仅当 writer 正在写入且已启动会话时才结束写入
    if (self.assetWriter && self.assetWriter.status == AVAssetWriterStatusWriting && self.hasStartedWriterSession) {
        if (self.videoInput) {
            @try { [self.videoInput markAsFinished]; }
            @catch (NSException *e) { NSLog(@"markAsFinished(video) skipped: %@", e.reason); }
        }
        if (self.audioInput) {
            @try { [self.audioInput markAsFinished]; }
            @catch (NSException *e) { NSLog(@"markAsFinished(audio) skipped: %@", e.reason); }
        }
    } else {
        // 未开始写入（可能用户秒停或无首帧），直接返回失败结果
        SRRecordingResult *result = [SRRecordingResult failureWithErrorCode:2006 errorMessage:@"Writer not started or no frames captured"];
        if (callback) { callback(result); }
        [self cleanup];
        return;
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

// 保存到相册（需要相册写入权限）
- (void)saveOutputToPhotoLibrary:(NSURL *)fileURL
                      completion:(void(^)(BOOL success, NSString *_Nullable localId, NSError *_Nullable error))completion {
    if (!fileURL) { if (completion) completion(NO, nil, [NSError errorWithDomain:@"com.funny.replaysdk" code:1201 userInfo:@{NSLocalizedDescriptionKey:@"Output URL is nil"}]); return; }
    // 动态权限
    if (![SRPermissionManager hasPhotoLibraryWritePermission]) {
        [SRPermissionManager requestPhotoLibraryWritePermission:^(BOOL granted, NSInteger errorCode, NSString *errorMessage) {
            if (!granted) {
                if (completion) completion(NO, nil, [NSError errorWithDomain:@"com.funny.replaysdk" code:1202 userInfo:@{NSLocalizedDescriptionKey:errorMessage ?: @"Photo permission denied"}]);
                return;
            }
            [self saveOutputToPhotoLibrary:fileURL completion:completion];
        }];
        return;
    }
    [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
        PHAssetChangeRequest *req = [PHAssetChangeRequest creationRequestForAssetFromVideoAtFileURL:fileURL];
        (void)req;
    } completionHandler:^(BOOL success, NSError * _Nullable error) {
        if (completion) completion(success, nil, error);
    }];
}


- (BOOL)adjustRecordingQuality:(SRVideoQuality)quality {
    // iOS录制过程中无法动态调整质量，这里只是更新配置
    if (self.currentConfig) {
        // 将SRVideoQuality映射到SRVideoQualityPreset
        SRVideoQualityPreset preset;
        switch (quality) {
            case SRVideoQualityLow:
                preset = SRVideoQualityPresetBasic;
                break;
            case SRVideoQualityMedium:
                preset = SRVideoQualityPresetStandard;
                break;
            case SRVideoQualityHigh:
                preset = SRVideoQualityPresetHighFps;
                break;
        }
        self.currentConfig.qualityPreset = preset;
        
        
        return YES;
    }
    
    return NO;
}

- (SRDetailedStatus *)getDetailedStatus {
    SRDetailedStatus *status = [[SRDetailedStatus alloc] init];
    status.status = self.currentStatus;
    status.isRecording = (self.currentStatus == SRRecordingStatusRecording);
    status.isPaused = NO; // 简化版本不支持暂停
    // 计算录制时长
    if (self.currentStatus == SRRecordingStatusRecording && self.startTime > 0) {
        status.duration = [[NSDate date] timeIntervalSince1970] - self.startTime;
    } else {
        status.duration = 0;
    }
    status.fileSize = 0; // 简化版本不提供文件大小
    status.errorCode = 0;
    status.errorMessage = nil;
    
    return status;
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

- (CGSize)calculateVideoSizeForQuality:(SRVideoQuality)quality preset:(SRVideoQualityPreset)preset {
    switch (preset) {
        case SRVideoQualityPresetBasic:
            return CGSizeMake(1280, 720); // 720p
        case SRVideoQualityPresetStandard:
            return CGSizeMake(1920, 1080); // 1080p
        case SRVideoQualityPresetSmooth:
            return CGSizeMake(1280, 720); // 720p
        case SRVideoQualityPresetHighFps:
            return CGSizeMake(1920, 1080); // 1080p
        case SRVideoQualityPresetUltra:
            return CGSizeMake(2560, 1440); // 1440p
        default:
            return CGSizeMake(1920, 1080); // 默认1080p
    }
}

- (NSInteger)calculateBitrateForPreset:(SRVideoQualityPreset)preset {
    switch (preset) {
        case SRVideoQualityPresetBasic:
            return 4000000;  // 4 Mbps（提高清晰度）
        case SRVideoQualityPresetStandard:
            return 8000000;  // 8 Mbps
        case SRVideoQualityPresetSmooth:
            return 6000000;  // 6 Mbps（更高帧率适当加码）
        case SRVideoQualityPresetHighFps:
            return 12000000; // 12 Mbps
        case SRVideoQualityPresetUltra:
            return 16000000; // 16 Mbps
    }
    return 8000000; // 默认8 Mbps
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
    self.hasStartedWriterSession = NO;
    self.currentStatus = SRRecordingStatusIdle;  // 重置状态为空闲
}

#pragma mark - RPScreenRecorderDelegate

- (void)screenRecorder:(RPScreenRecorder *)screenRecorder didStopRecordingWithPreviewViewController:(RPPreviewViewController *)previewViewController error:(NSError *)error {
    // 录制停止时的处理
}

// 预览功能暂时屏蔽：保留空实现以兼容协议，但不展示 UI
// #pragma mark - RPPreviewViewControllerDelegate

@end
