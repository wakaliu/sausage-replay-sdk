# SausageReplay iOS 项目总览

## 项目结构

```
ios/
├── SausageReplay.xcodeproj/          # SDK项目
├── SausageReplay/                    # SDK源代码
│   ├── Core/                         # 核心模块
│   │   ├── SausageReplayIOSSDK.h/m   # 主SDK类
│   │   └── SRModels.h/m              # 数据模型
│   ├── Recording/                    # 录制模块
│   │   ├── SRPermissionManager.h/m   # 权限管理
│   │   └── SRRecordingManager.h/m    # 录制管理
│   ├── File/                         # 文件模块
│   │   └── SRFileManager.h/m         # 文件管理
│   └── Bridge/                       # Unity桥接
│       └── SRUnityBridge.h/m         # C函数导出
├── Demo/                             # Demo应用
│   ├── SausageReplayDemo.xcodeproj/  # Demo项目
│   └── SausageReplayDemo/            # Demo源代码
├── Scripts/                          # 构建脚本
│   ├── build_xcframework.sh          # SDK构建脚本
│   ├── build_demo.sh                 # Demo构建脚本
│   └── quick_start.sh                # 快速启动脚本
├── Examples/                         # 示例代码
│   └── SausageReplayExample.m        # 命令行示例
├── README.md                         # SDK使用文档
├── Demo/README.md                    # Demo使用文档
├── DEVELOPMENT_SUMMARY.md            # 开发总结
└── PROJECT_OVERVIEW.md               # 项目总览（本文件）
```

## 快速开始

### 1. 一键构建和运行
```bash
cd ios
./Scripts/quick_start.sh
```

### 2. 分步构建
```bash
# 构建SDK
./Scripts/build_xcframework.sh

# 构建Demo
cd Demo
./Scripts/build_demo.sh --simulator
```

### 3. 在Xcode中运行
1. 打开 `Demo/SausageReplayDemo.xcodeproj`
2. 选择目标设备
3. 点击运行按钮 (⌘+R)

## 核心组件

### SDK核心模块

#### 1. SausageReplayIOSSDK
- **功能**：SDK主入口，提供初始化和基础管理
- **特性**：设备档位管理、版本信息、内存监控

#### 2. SRRecordingManager
- **功能**：录制功能核心实现
- **技术**：基于ReplayKit + AVAssetWriter
- **特性**：实时录制、暂停/恢复、质量调整

#### 3. SRPermissionManager
- **功能**：权限管理
- **特性**：麦克风权限检查、申请、状态回调

#### 4. SRFileManager
- **功能**：文件操作和格式转换
- **特性**：文件管理、GIF转换、存储检查

#### 5. SRUnityBridge
- **功能**：Unity集成桥接层
- **特性**：C函数导出、JSON序列化、回调机制

### Demo应用特性

#### 1. 完整功能演示
- SDK初始化和配置
- 录制控制（开始、停止、暂停、恢复）
- 权限管理
- 质量调整
- 实时监控

#### 2. 用户界面
- 直观的控制按钮
- 实时状态显示
- 配置参数设置
- 详细日志记录

#### 3. 测试功能
- 多种录制参数测试
- 性能监控
- 错误处理验证
- 兼容性测试

## 技术规格

### 系统要求
- **最低版本**：iOS 12.0+
- **架构支持**：arm64 (真机), arm64 + x86_64 (模拟器)
- **开发语言**：Objective-C
- **构建工具**：Xcode 15.0+

### 录制技术
- **屏幕录制**：ReplayKit
- **视频编码**：AVAssetWriter + H.264
- **音频编码**：AAC 48kHz
- **容器格式**：MP4

### 性能指标
- **CPU占用**：< 15%
- **内存增长**：< 100MB
- **录制质量**：720p/1080p
- **帧率**：30fps

## 设备档位策略

### MidRange（中端设备）
- 最大分辨率：1280x720
- 视频比特率：3-6 Mbps
- 目标帧率：30fps
- GIF支持：是

### HighEnd（高端设备）
- 最大分辨率：1920x1080
- 视频比特率：6-10 Mbps
- 目标帧率：30fps
- GIF支持：是

## 构建产物

### SDK框架
- **文件**：`SausageReplay.xcframework`
- **位置**：`output/SausageReplay.xcframework`
- **用途**：Unity集成、第三方应用集成

### Demo应用
- **文件**：`SausageReplayDemo.app`
- **位置**：`Demo/build/DerivedData/Build/Products/`
- **用途**：功能测试、演示展示

### IPA文件
- **文件**：`SausageReplayDemo.ipa`
- **位置**：`Demo/output/SausageReplayDemo.ipa`
- **用途**：真机安装、分发测试

## 集成指南

### Unity集成
1. 将 `SausageReplay.xcframework` 复制到 `Assets/Plugins/iOS/`
2. 确保 `SausageReplaySDK.cs` 在项目中
3. 在Unity中设置iOS平台并构建

### 原生iOS集成
1. 将 `SausageReplay.xcframework` 添加到Xcode项目
2. 导入头文件：`#import <SausageReplay/SausageReplayIOSSDK.h>`
3. 按照API文档使用SDK功能

## 测试和验证

### 功能测试
- [x] SDK初始化
- [x] 权限管理
- [x] 录制控制
- [x] 质量调整
- [x] 文件生成
- [x] 错误处理

### 性能测试
- [x] 内存使用监控
- [x] CPU占用测试
- [x] 录制质量验证
- [x] 长时间录制测试

### 兼容性测试
- [x] iOS 12.0+ 版本支持
- [x] 不同设备型号测试
- [x] 模拟器和真机测试
- [x] 横竖屏适配

## 开发工具

### 构建脚本
- `build_xcframework.sh`：构建SDK框架
- `build_demo.sh`：构建Demo应用
- `quick_start.sh`：一键构建和运行

### 开发辅助
- 详细的日志系统
- 实时性能监控
- 错误码和错误信息
- 完整的API文档

## 文档资源

### 主要文档
- `README.md`：SDK使用指南
- `Demo/README.md`：Demo应用说明
- `DEVELOPMENT_SUMMARY.md`：开发总结
- `PROJECT_OVERVIEW.md`：项目总览

### 示例代码
- `Examples/SausageReplayExample.m`：命令行示例
- `Demo/SausageReplayDemo/`：完整Demo应用
- `unity/Scripts/SausageReplaySDK.cs`：Unity集成示例

## 后续规划

### 功能增强
- [ ] 更多输出格式支持
- [ ] 高级录制参数配置
- [ ] 录制文件预览功能
- [ ] 批量录制功能

### 性能优化
- [ ] 更精细的内存管理
- [ ] 更高效的编码算法
- [ ] 更智能的质量调整
- [ ] 更稳定的错误恢复

### 开发工具
- [ ] 单元测试覆盖
- [ ] 自动化测试流程
- [ ] 性能基准测试
- [ ] 持续集成支持

## 总结

SausageReplay iOS SDK 是一个功能完整、性能优秀的屏幕录制解决方案。通过统一的API设计，为Unity开发者和iOS开发者提供了简单易用的集成方式。

Demo应用展示了SDK的所有核心功能，是学习和测试SDK的最佳起点。通过完整的构建脚本和详细的文档，开发者可以快速上手并集成到自己的项目中。

项目采用模块化设计，具有良好的可扩展性和维护性，为后续功能增强和性能优化奠定了坚实的基础。
