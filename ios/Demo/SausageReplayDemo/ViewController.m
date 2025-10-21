//
//  ViewController.m
//  SausageReplayDemo
//
//  Created by Waka on 2025/10/10.
//

#import "ViewController.h"
#import <SausageReplay/SausageReplayIOSSDK.h>
#import <SausageReplay/SRRecordingManager.h>
#import <SausageReplay/SRPermissionManager.h>
#import <SausageReplay/SRModels.h>
#import <Photos/Photos.h>

@interface ViewController () <SRRecordingCallback>

// 状态变量
@property (nonatomic, assign) BOOL isInitialized;
@property (nonatomic, assign) BOOL isRecording;
@property (nonatomic, assign) BOOL isPaused;
@property (nonatomic, strong) NSTimer *memoryTimer;
@property (nonatomic, strong) NSString *lastRecordedVideoPath;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self setupUIProgrammatically];
    [self updateUI];
    [self startMemoryMonitoring];
}

- (void)setupUIProgrammatically {
    // 设置初始状态
    self.isInitialized = NO;
    self.isRecording = NO;
    self.isPaused = NO;
    
    // 创建滚动视图
    UIScrollView *scrollView = [[UIScrollView alloc] init];
    scrollView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:scrollView];
    
    // 创建主堆栈视图
    UIStackView *mainStackView = [[UIStackView alloc] init];
    mainStackView.axis = UILayoutConstraintAxisVertical;
    mainStackView.spacing = 16;
    mainStackView.translatesAutoresizingMaskIntoConstraints = NO;
    [scrollView addSubview:mainStackView];
    
    // 状态信息区域
    UIStackView *statusStackView = [[UIStackView alloc] init];
    statusStackView.axis = UILayoutConstraintAxisVertical;
    statusStackView.spacing = 8;
    
    self.statusLabel = [[UILabel alloc] init];
    self.statusLabel.text = @"状态: 未初始化";
    self.statusLabel.textAlignment = NSTextAlignmentCenter;
    self.statusLabel.font = [UIFont systemFontOfSize:17 weight:UIFontWeightSemibold];
    self.statusLabel.textColor = [UIColor systemGrayColor];
    [statusStackView addArrangedSubview:self.statusLabel];
    
    self.versionLabel = [[UILabel alloc] init];
    self.versionLabel.text = @"版本: 1.0.0";
    self.versionLabel.textAlignment = NSTextAlignmentCenter;
    self.versionLabel.font = [UIFont systemFontOfSize:14];
    [statusStackView addArrangedSubview:self.versionLabel];
    
    self.presetLabel = [[UILabel alloc] init];
    self.presetLabel.text = @"清晰度档位: 未初始化";
    self.presetLabel.textAlignment = NSTextAlignmentCenter;
    self.presetLabel.font = [UIFont systemFontOfSize:14];
    [statusStackView addArrangedSubview:self.presetLabel];
    
    self.permissionLabel = [[UILabel alloc] init];
    self.permissionLabel.text = @"麦克风权限: 未授权";
    self.permissionLabel.textAlignment = NSTextAlignmentCenter;
    self.permissionLabel.font = [UIFont systemFontOfSize:14];
    [statusStackView addArrangedSubview:self.permissionLabel];
    
    self.memoryLabel = [[UILabel alloc] init];
    self.memoryLabel.text = @"内存: 未初始化";
    self.memoryLabel.textAlignment = NSTextAlignmentCenter;
    self.memoryLabel.font = [UIFont systemFontOfSize:14];
    [statusStackView addArrangedSubview:self.memoryLabel];
    
    [mainStackView addArrangedSubview:statusStackView];
    
    // 控制按钮区域
    UIStackView *controlStackView = [[UIStackView alloc] init];
    controlStackView.axis = UILayoutConstraintAxisVertical;
    controlStackView.spacing = 12;
    
    // 初始化按钮
    self.sdkInitButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.sdkInitButton setTitle:@"初始化 SDK" forState:UIControlStateNormal];
    self.sdkInitButton.backgroundColor = [UIColor systemBlueColor];
    [self.sdkInitButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.sdkInitButton.layer.cornerRadius = 8;
    [self.sdkInitButton addTarget:self action:@selector(initButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
    [controlStackView addArrangedSubview:self.sdkInitButton];
    
    // 录制控制按钮
    UIStackView *recordingStackView = [[UIStackView alloc] init];
    recordingStackView.axis = UILayoutConstraintAxisHorizontal;
    recordingStackView.distribution = UIStackViewDistributionFillEqually;
    recordingStackView.spacing = 8;
    
    self.startButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.startButton setTitle:@"开始录制" forState:UIControlStateNormal];
    self.startButton.backgroundColor = [UIColor systemGreenColor];
    [self.startButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.startButton.layer.cornerRadius = 8;
    [self.startButton addTarget:self action:@selector(startButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
    [recordingStackView addArrangedSubview:self.startButton];
    
    self.stopButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.stopButton setTitle:@"停止录制" forState:UIControlStateNormal];
    self.stopButton.backgroundColor = [UIColor systemRedColor];
    [self.stopButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.stopButton.layer.cornerRadius = 8;
    [self.stopButton addTarget:self action:@selector(stopButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
    [recordingStackView addArrangedSubview:self.stopButton];
    
    [controlStackView addArrangedSubview:recordingStackView];
    
    // 暂停/恢复按钮
    UIStackView *pauseResumeStackView = [[UIStackView alloc] init];
    pauseResumeStackView.axis = UILayoutConstraintAxisHorizontal;
    pauseResumeStackView.distribution = UIStackViewDistributionFillEqually;
    pauseResumeStackView.spacing = 8;
    
    self.pauseButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.pauseButton setTitle:@"暂停" forState:UIControlStateNormal];
    self.pauseButton.backgroundColor = [UIColor systemOrangeColor];
    [self.pauseButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.pauseButton.layer.cornerRadius = 8;
    [self.pauseButton addTarget:self action:@selector(pauseButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
    [pauseResumeStackView addArrangedSubview:self.pauseButton];
    
    self.resumeButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.resumeButton setTitle:@"恢复" forState:UIControlStateNormal];
    self.resumeButton.backgroundColor = [UIColor systemBlueColor];
    [self.resumeButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.resumeButton.layer.cornerRadius = 8;
    [self.resumeButton addTarget:self action:@selector(resumeButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
    [pauseResumeStackView addArrangedSubview:self.resumeButton];
    
    [controlStackView addArrangedSubview:pauseResumeStackView];
    
    // 其他控制按钮
    UIStackView *otherStackView = [[UIStackView alloc] init];
    otherStackView.axis = UILayoutConstraintAxisHorizontal;
    otherStackView.distribution = UIStackViewDistributionFillEqually;
    otherStackView.spacing = 8;
    
    self.permissionButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.permissionButton setTitle:@"请求权限" forState:UIControlStateNormal];
    self.permissionButton.backgroundColor = [UIColor systemBlueColor];
    [self.permissionButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.permissionButton.layer.cornerRadius = 8;
    [self.permissionButton addTarget:self action:@selector(permissionButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
    [otherStackView addArrangedSubview:self.permissionButton];
    
    
    [controlStackView addArrangedSubview:otherStackView];
    
    // 清空日志按钮
    self.clearLogButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.clearLogButton setTitle:@"清空日志" forState:UIControlStateNormal];
    self.clearLogButton.backgroundColor = [UIColor systemGrayColor];
    [self.clearLogButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.clearLogButton.layer.cornerRadius = 8;
    [self.clearLogButton addTarget:self action:@selector(clearLogButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
    [controlStackView addArrangedSubview:self.clearLogButton];
    
    // 保存到相册按钮
    self.saveToAlbumButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.saveToAlbumButton setTitle:@"保存到相册" forState:UIControlStateNormal];
    self.saveToAlbumButton.backgroundColor = [UIColor systemBlueColor];
    [self.saveToAlbumButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.saveToAlbumButton.layer.cornerRadius = 8;
    [self.saveToAlbumButton addTarget:self action:@selector(saveToAlbumButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
    [controlStackView addArrangedSubview:self.saveToAlbumButton];
    
    [mainStackView addArrangedSubview:controlStackView];
    
    // 配置区域
    UIStackView *configStackView = [[UIStackView alloc] init];
    configStackView.axis = UILayoutConstraintAxisVertical;
    configStackView.spacing = 12;
    
    // 视频清晰度档位选择
    UIStackView *presetStackView = [[UIStackView alloc] init];
    presetStackView.axis = UILayoutConstraintAxisHorizontal;
    presetStackView.alignment = UIStackViewAlignmentCenter;
    presetStackView.spacing = 12;
    
    UILabel *presetLabel = [[UILabel alloc] init];
    presetLabel.text = @"清晰度档位:";
    presetLabel.font = [UIFont systemFontOfSize:14];
    [presetStackView addArrangedSubview:presetLabel];
    
    self.presetSegmentedControl = [[UISegmentedControl alloc] initWithItems:@[@"Basic", @"Standard", @"Smooth", @"HighFps", @"Ultra"]];
    self.presetSegmentedControl.selectedSegmentIndex = 1; // 默认Standard
    [presetStackView addArrangedSubview:self.presetSegmentedControl];
    
    [configStackView addArrangedSubview:presetStackView];
    
    
    // 音频开关
    UIStackView *audioStackView = [[UIStackView alloc] init];
    audioStackView.axis = UILayoutConstraintAxisHorizontal;
    audioStackView.alignment = UIStackViewAlignmentCenter;
    audioStackView.spacing = 12;
    
    UILabel *audioLabel = [[UILabel alloc] init];
    audioLabel.text = @"音频:";
    audioLabel.font = [UIFont systemFontOfSize:14];
    [audioStackView addArrangedSubview:audioLabel];
    
    self.audioSwitch = [[UISwitch alloc] init];
    self.audioSwitch.on = YES;
    [audioStackView addArrangedSubview:self.audioSwitch];
    
    [configStackView addArrangedSubview:audioStackView];
    
    // 时长滑块
    UIStackView *durationStackView = [[UIStackView alloc] init];
    durationStackView.axis = UILayoutConstraintAxisVertical;
    durationStackView.spacing = 4;
    
    self.durationLabel = [[UILabel alloc] init];
    self.durationLabel.text = @"录制时长: 30秒";
    self.durationLabel.textAlignment = NSTextAlignmentCenter;
    self.durationLabel.font = [UIFont systemFontOfSize:14];
    [durationStackView addArrangedSubview:self.durationLabel];
    
    self.durationSlider = [[UISlider alloc] init];
    self.durationSlider.minimumValue = 5;
    self.durationSlider.maximumValue = 120;
    self.durationSlider.value = 30;
    [self.durationSlider addTarget:self action:@selector(durationSliderChanged:) forControlEvents:UIControlEventValueChanged];
    [durationStackView addArrangedSubview:self.durationSlider];
    
    [configStackView addArrangedSubview:durationStackView];
    
    [mainStackView addArrangedSubview:configStackView];
    
    // 日志区域
    UIStackView *logStackView = [[UIStackView alloc] init];
    logStackView.axis = UILayoutConstraintAxisVertical;
    logStackView.spacing = 8;
    
    UILabel *logTitleLabel = [[UILabel alloc] init];
    logTitleLabel.text = @"日志:";
    logTitleLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightSemibold];
    [logStackView addArrangedSubview:logTitleLabel];
    
    self.logTextView = [[UITextView alloc] init];
    self.logTextView.text = @"=== SausageReplay Demo ===\n";
    self.logTextView.editable = NO;
    self.logTextView.font = [UIFont systemFontOfSize:12];
    if (@available(iOS 13.0, *)) {
        self.logTextView.backgroundColor = [UIColor systemBackgroundColor];
    } else {
        self.logTextView.backgroundColor = [UIColor whiteColor];
    }
    self.logTextView.layer.borderColor = [UIColor systemGrayColor].CGColor;
    self.logTextView.layer.borderWidth = 1;
    self.logTextView.layer.cornerRadius = 8;
    [logStackView addArrangedSubview:self.logTextView];
    
    [mainStackView addArrangedSubview:logStackView];
    
    // 设置约束
    [NSLayoutConstraint activateConstraints:@[
        // ScrollView约束
        [scrollView.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
        [scrollView.leadingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.leadingAnchor],
        [scrollView.trailingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.trailingAnchor],
        [scrollView.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor],
        
        // MainStackView约束
        [mainStackView.topAnchor constraintEqualToAnchor:scrollView.topAnchor constant:16],
        [mainStackView.leadingAnchor constraintEqualToAnchor:scrollView.leadingAnchor constant:16],
        [mainStackView.trailingAnchor constraintEqualToAnchor:scrollView.trailingAnchor constant:-16],
        [mainStackView.bottomAnchor constraintEqualToAnchor:scrollView.bottomAnchor constant:-16],
        [mainStackView.widthAnchor constraintEqualToAnchor:scrollView.widthAnchor constant:-32],
        
        // 按钮高度约束
        [self.sdkInitButton.heightAnchor constraintEqualToConstant:44],
        [self.startButton.heightAnchor constraintEqualToConstant:44],
        [self.stopButton.heightAnchor constraintEqualToConstant:44],
        [self.pauseButton.heightAnchor constraintEqualToConstant:44],
        [self.resumeButton.heightAnchor constraintEqualToConstant:44],
        [self.permissionButton.heightAnchor constraintEqualToConstant:44],
        [self.clearLogButton.heightAnchor constraintEqualToConstant:44],
        [self.saveToAlbumButton.heightAnchor constraintEqualToConstant:44],
        
        // 视频清晰度档位选择器高度约束
        [self.presetSegmentedControl.heightAnchor constraintEqualToConstant:32],
        
        // 日志文本视图高度约束
        [self.logTextView.heightAnchor constraintEqualToConstant:200]
    ]];
    
    // 添加日志
    [self addLog:@"Demo应用启动"];
    [self addLog:[NSString stringWithFormat:@"SDK版本: %@", [SausageReplayIOSSDK version]]];
    [self addLog:[NSString stringWithFormat:@"平台支持: %@", [SausageReplayIOSSDK isPlatformSupported] ? @"是" : @"否"]];
}

- (void)updateUI {
    // 更新按钮状态
    self.sdkInitButton.enabled = !self.isInitialized;
    self.startButton.enabled = self.isInitialized && !self.isRecording;
    self.stopButton.enabled = self.isRecording;
    self.pauseButton.enabled = self.isRecording && !self.isPaused;
    self.resumeButton.enabled = self.isRecording && self.isPaused;
    self.permissionButton.enabled = self.isInitialized;
    
    // 更新状态标签
    if (self.isRecording) {
        self.statusLabel.text = self.isPaused ? @"录制中 (已暂停)" : @"录制中";
        self.statusLabel.textColor = self.isPaused ? [UIColor orangeColor] : [UIColor redColor];
    } else {
        self.statusLabel.text = self.isInitialized ? @"就绪" : @"未初始化";
        self.statusLabel.textColor = self.isInitialized ? [UIColor greenColor] : [UIColor grayColor];
    }
    
    // 更新版本信息
    self.versionLabel.text = [NSString stringWithFormat:@"版本: %@", [SausageReplayIOSSDK version]];
    
    // 更新清晰度档位信息
    if (self.isInitialized) {
        SRDeviceTierInfo *tierInfo = [SausageReplayIOSSDK getDeviceTierInfo];
        self.presetLabel.text = [NSString stringWithFormat:@"清晰度档位: %@", tierInfo.tierName];
    } else {
        self.presetLabel.text = @"清晰度档位: 未初始化";
    }
    
    // 更新权限状态
    BOOL hasPermission = [SRPermissionManager hasMicrophonePermission];
    self.permissionLabel.text = [NSString stringWithFormat:@"麦克风权限: %@", hasPermission ? @"已授权" : @"未授权"];
    self.permissionLabel.textColor = hasPermission ? [UIColor greenColor] : [UIColor redColor];
}

- (void)updateDurationLabel {
    int duration = (int)self.durationSlider.value;
    self.durationLabel.text = [NSString stringWithFormat:@"录制时长: %d秒", duration];
}

- (void)startMemoryMonitoring {
    self.memoryTimer = [NSTimer scheduledTimerWithTimeInterval:1.0
                                                        target:self
                                                      selector:@selector(updateMemoryInfo)
                                                      userInfo:nil
                                                       repeats:YES];
}

- (void)updateMemoryInfo {
    if (self.isInitialized) {
        SRMemoryUsage *memoryUsage = [SausageReplayIOSSDK getMemoryUsage];
        self.memoryLabel.text = [NSString stringWithFormat:@"内存: %.1fMB / %.1fMB (%.1f%%)",
                                memoryUsage.usedMemory / 1024.0 / 1024.0,
                                memoryUsage.maxMemory / 1024.0 / 1024.0,
                                (long)memoryUsage.usagePercentage];
    } else {
        self.memoryLabel.text = @"内存: 未初始化";
    }
}

- (void)addLog:(NSString *)message {
    NSString *timestamp = [NSDateFormatter localizedStringFromDate:[NSDate date]
                                                         dateStyle:NSDateFormatterNoStyle
                                                         timeStyle:NSDateFormatterMediumStyle];
    NSString *logMessage = [NSString stringWithFormat:@"[%@] %@\n", timestamp, message];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        self.logTextView.text = [self.logTextView.text stringByAppendingString:logMessage];
        
        // 自动滚动到底部
        NSRange bottom = NSMakeRange(self.logTextView.text.length - 1, 1);
        [self.logTextView scrollRangeToVisible:bottom];
    });
}

#pragma mark - Actions

- (IBAction)initButtonTapped:(UIButton *)sender {
    if (self.isInitialized) {
        [self addLog:@"SDK已经初始化"];
        return;
    }
    
    // 获取选中的清晰度档位
    SRVideoQualityPreset selectedPreset = (SRVideoQualityPreset)self.presetSegmentedControl.selectedSegmentIndex;
    NSString *presetName = [self presetNameForPreset:selectedPreset];
    
    [self addLog:[NSString stringWithFormat:@"初始化SDK，使用清晰度档位: %@", presetName]];
    
    BOOL success = [SausageReplayIOSSDK initializeWithPreset:selectedPreset];
    if (success) {
        self.isInitialized = YES;
        [self addLog:@"✅ SDK初始化成功"];
        
        // 更新UI状态
        
        // 获取设备信息
        SRDeviceTierInfo *tierInfo = [SausageReplayIOSSDK getDeviceTierInfo];
        [self addLog:[NSString stringWithFormat:@"视频清晰度档位: %@", tierInfo.tierName]];
        [self addLog:[NSString stringWithFormat:@"最大分辨率: %ldx%ld", (long)tierInfo.maxWidth, (long)tierInfo.maxHeight]];
        [self addLog:[NSString stringWithFormat:@"目标帧率: %ld", (long)tierInfo.targetFps]];
        [self addLog:[NSString stringWithFormat:@"视频比特率: %lld", tierInfo.videoBitrate]];
        [self addLog:[NSString stringWithFormat:@"GIF支持: %@", tierInfo.gifSupported ? @"是" : @"否"]];
        
        // 更新清晰度档位信息显示
        self.presetLabel.text = [NSString stringWithFormat:@"清晰度档位: %@ (%@x%@@%ldfps)", 
                                presetName, 
                                @(tierInfo.maxWidth), 
                                @(tierInfo.maxHeight), 
                                (long)tierInfo.targetFps];
    } else {
        [self addLog:@"❌ SDK初始化失败"];
    }
    
    [self updateUI];
}

- (IBAction)startButtonTapped:(UIButton *)sender {
    if (!self.isInitialized) {
        [self addLog:@"❌ 请先初始化SDK"];
        return;
    }
    
    // 创建录制配置
    SRRecordingConfig *config = [SRRecordingConfig defaultConfig];
    config.qualityPreset = [SausageReplayIOSSDK getCurrentPreset]; // 使用当前视频清晰度档位
    config.maxDurationSeconds = (int)self.durationSlider.value;
    config.includeAudio = self.audioSwitch.isOn;
    config.outputFormat = SROutputFormatMP4;
    
    [self addLog:[NSString stringWithFormat:@"开始录制 - 清晰度档位: %ld, 时长: %d秒, 音频: %@",
                  (long)config.qualityPreset, config.maxDurationSeconds, config.includeAudio ? @"是" : @"否"]];
    
    BOOL success = [SRRecordingManager startRecordingWithConfig:config callback:self];
    if (success) {
        self.isRecording = YES;
        [self addLog:@"✅ 录制开始"];
    } else {
        [self addLog:@"❌ 录制开始失败"];
    }
    
    [self updateUI];
}

- (IBAction)stopButtonTapped:(UIButton *)sender {
    [self addLog:@"停止录制..."];
    
    [SRRecordingManager stopRecording:^(SRRecordingResult *result) {
        dispatch_async(dispatch_get_main_queue(), ^{
            self.isRecording = NO;
            self.isPaused = NO;
            
            if (result.isSuccess) {
                [self addLog:@"✅ 录制停止成功"];
                [self addLog:[NSString stringWithFormat:@"文件路径: %@", result.filePath]];
                [self addLog:[NSString stringWithFormat:@"文件大小: %.2f MB", result.fileSize / 1024.0 / 1024.0]];
                [self addLog:[NSString stringWithFormat:@"录制时长: %.2f 秒", result.duration]];
            } else {
                [self addLog:[NSString stringWithFormat:@"❌ 录制停止失败: %@", result.errorMessage]];
            }
            
            [self updateUI];
        });
    }];
}

- (IBAction)pauseButtonTapped:(UIButton *)sender {
    BOOL success = [SRRecordingManager pauseRecording];
    if (success) {
        self.isPaused = YES;
        [self addLog:@"⏸️ 录制暂停"];
    } else {
        [self addLog:@"❌ 暂停失败"];
    }
    
    [self updateUI];
}

- (IBAction)resumeButtonTapped:(UIButton *)sender {
    BOOL success = [SRRecordingManager resumeRecording];
    if (success) {
        self.isPaused = NO;
        [self addLog:@"▶️ 录制恢复"];
    } else {
        [self addLog:@"❌ 恢复失败"];
    }
    
    [self updateUI];
}

- (IBAction)permissionButtonTapped:(UIButton *)sender {
    [self addLog:@"请求麦克风权限..."];
    
    [SRPermissionManager requestMicrophonePermission:^(SRPermissionResult *result) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (result.isGranted) {
                [self addLog:@"✅ 麦克风权限授权成功"];
            } else {
                [self addLog:[NSString stringWithFormat:@"❌ 麦克风权限授权失败: %@", result.errorMessage]];
            }
            
            [self updateUI];
        });
    }];
}


- (IBAction)durationSliderChanged:(UISlider *)sender {
    [self updateDurationLabel];
}

- (IBAction)clearLogButtonTapped:(UIButton *)sender {
    self.logTextView.text = @"=== 日志已清空 ===\n";
}

#pragma mark - SRRecordingCallback

- (void)onRecordingStarted {
    [self addLog:@"🎬 录制开始回调"];
}

- (void)onRecordingProgress:(long long)durationMs fileSizeBytes:(long long)fileSizeBytes {
    // 每秒更新一次进度
    static long long lastUpdateTime = 0;
    long long currentTime = durationMs / 1000;
    if (currentTime > lastUpdateTime) {
        lastUpdateTime = currentTime;
        [self addLog:[NSString stringWithFormat:@"📊 录制进度: %lld秒, 估算文件大小: %.2f MB", 
                      currentTime, fileSizeBytes / 1024.0 / 1024.0]];
    }
}

- (void)onRecordingPaused {
    [self addLog:@"⏸️ 录制暂停回调"];
}

- (void)onRecordingResumed {
    [self addLog:@"▶️ 录制恢复回调"];
}

- (void)onRecordingStopped:(SRRecordingResult *)result {
    [self addLog:@"🛑 录制停止回调"];
    
    if (result.isSuccess && result.filePath) {
        self.lastRecordedVideoPath = result.filePath;
        [self addLog:[NSString stringWithFormat:@"📁 视频已保存到: %@", result.filePath]];
        [self addLog:[NSString stringWithFormat:@"📊 文件大小: %.2f MB, 时长: %.1f秒", 
                      result.fileSize / 1024.0 / 1024.0, result.duration]];
        [self addLog:@"💡 点击'保存到相册'按钮将视频保存到系统相册"];
    } else {
        [self addLog:[NSString stringWithFormat:@"❌ 录制失败: %@", result.errorMessage ?: @"未知错误"]];
    }
}

- (void)onRecordingError:(NSInteger)errorCode errorMessage:(nullable NSString *)errorMessage {
    [self addLog:[NSString stringWithFormat:@"❌ 录制错误: %ld - %@", (long)errorCode, errorMessage]];
}

- (void)onRecordingQualityAdjusted:(SRVideoQuality)quality {
    [self addLog:[NSString stringWithFormat:@"🎯 质量调整回调: %ld", (long)quality]];
}

#pragma mark - Save to Album

- (void)saveToAlbumButtonTapped:(UIButton *)sender {
    if (!self.lastRecordedVideoPath) {
        [self addLog:@"❌ 没有可保存的视频文件"];
        return;
    }
    
    NSURL *videoURL = [NSURL fileURLWithPath:self.lastRecordedVideoPath];
    if (![[NSFileManager defaultManager] fileExistsAtPath:self.lastRecordedVideoPath]) {
        [self addLog:@"❌ 视频文件不存在"];
        return;
    }
    
    [self addLog:@"📱 开始保存视频到相册..."];
    
    // 检查相册权限
    PHAuthorizationStatus status = [PHPhotoLibrary authorizationStatus];
    if (status == PHAuthorizationStatusNotDetermined) {
        [PHPhotoLibrary requestAuthorization:^(PHAuthorizationStatus status) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (status == PHAuthorizationStatusAuthorized || status == PHAuthorizationStatusLimited) {
                    [self saveVideoToAlbum:videoURL];
                } else {
                    [self addLog:@"❌ 相册权限被拒绝"];
                }
            });
        }];
    } else if (status == PHAuthorizationStatusAuthorized || status == PHAuthorizationStatusLimited) {
        [self saveVideoToAlbum:videoURL];
    } else {
        [self addLog:@"❌ 没有相册权限，请在设置中开启"];
    }
}

- (void)saveVideoToAlbum:(NSURL *)videoURL {
    [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
        [PHAssetChangeRequest creationRequestForAssetFromVideoAtFileURL:videoURL];
    } completionHandler:^(BOOL success, NSError * _Nullable error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (success) {
                [self addLog:@"✅ 视频已成功保存到相册"];
            } else {
                [self addLog:[NSString stringWithFormat:@"❌ 保存到相册失败: %@", error.localizedDescription]];
            }
        });
    }];
}



- (NSString *)presetNameForPreset:(SRVideoQualityPreset)preset {
    switch (preset) {
        case SRVideoQualityPresetBasic:
            return @"Basic (720p30)";
        case SRVideoQualityPresetStandard:
            return @"Standard (1080p30)";
        case SRVideoQualityPresetSmooth:
            return @"Smooth (720p60)";
        case SRVideoQualityPresetHighFps:
            return @"HighFps (1080p60)";
        case SRVideoQualityPresetUltra:
            return @"Ultra (1440p30)";
    }
}

#pragma mark - Memory Management

- (void)dealloc {
    [self.memoryTimer invalidate];
    self.memoryTimer = nil;
}

@end
