//
//  ViewController.h
//  SausageReplayDemo
//
//  Created by Waka on 2025/10/10.
//

#import <UIKit/UIKit.h>

@interface ViewController : UIViewController

// 状态标签
@property (strong, nonatomic) UILabel *statusLabel;
@property (strong, nonatomic) UILabel *versionLabel;
@property (strong, nonatomic) UILabel *presetLabel;

// 控制按钮
@property (strong, nonatomic) UIButton *sdkInitButton;
@property (strong, nonatomic) UIButton *startButton;
@property (strong, nonatomic) UIButton *stopButton;
@property (strong, nonatomic) UIButton *clearLogButton;
@property (strong, nonatomic) UIButton *saveToAlbumButton;

// 配置控件
@property (strong, nonatomic) UISwitch *audioSwitch;
@property (strong, nonatomic) UISlider *durationSlider;
@property (strong, nonatomic) UILabel *durationLabel;

// 视频清晰度档位选择
@property (strong, nonatomic) UISegmentedControl *presetSegmentedControl;

// 日志
@property (strong, nonatomic) UITextView *logTextView;

@end
