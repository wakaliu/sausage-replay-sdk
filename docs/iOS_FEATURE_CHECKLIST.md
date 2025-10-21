## Sausage Replay SDK - iOS 功能清单与验收标准

### 平台与产物
- [x] iOS 12.0+；仅 `arm64` 真机，模拟器包含 `arm64/x86_64`
- [x] 产物为 `XCFramework`；不提供 CocoaPods 发版
- [x] 语言为 Objective‑C

### 基础能力（与 Android 对齐）
- [ ] Initialize/Start/Pause/Resume/Stop API 与 Unity C# 对齐
- [ ] 回调：开始/暂停/恢复/停止/错误/进度/完成（主线程）
- [ ] 错误码集合与 Android 对齐；iOS 子码映射策略落地

### 录制与编码
- [ ] 应用内画面采集（`ReplayKit`）
- [ ] 应用内音频（游戏声音）与麦克风音频混录
- [ ] MP4 输出（H.264），关键帧间隔/帧率按档位配置
- [ ] 录制最长 60s（可配置）

### 存储与相册
- [ ] 默认保存到相册（`NSPhotoLibraryAddUsageDescription`）
- [ ] 可选保存到 App 沙盒目录（返回文件路径）

### 权限
- [ ] 麦克风权限系统弹窗（`NSMicrophoneUsageDescription`）
- [ ] 相册写入权限（仅需 AddUsageDescription）
- [ ] API 返回权限检查/申请结果，便于业务自定义弹窗

### 质量档位与设备档位
- [ ] 质量档位：高清/标清（`quality_profiles.json` 可配）
- [ ] 设备档位：`MidRange/HighEnd`，影响默认档位选择

### 文件大小控制
- [ ] 目标大小上限（字节）生效
- [ ] 静态回退策略：降码率→降分辨率→降帧率（不启用帧丢弃）

### Unity 集成
- [ ] C 导出接口与 `UnitySendMessage` 回调桥
- [ ] 回调集中封装在 `SausageReplaySDK.cs`，外部零改动集成
- [ ] 提供最小 Unity 场景用于联调验证

### 打包与交付
- [ ] Xcodeproj 示例（同 Workspace 包含 Demo 与 SDK）
- [ ] 手动打包 `XCFramework` 脚本与说明
- [ ] 不随库打包符号表（dSYM 可单独提供可选）

### 性能与稳定性
- [ ] 录制期 CPU < 15%，内存增长 < 100MB
- [ ] 主线程无重负载；回调主线程派发
- [ ] 出错路径覆盖（权限拒绝/磁盘不足/编码失败/相册失败）

### 文档
- [ ] 开发指南（本仓库 `docs/iOS_DEVELOPMENT_GUIDE.md`）
- [ ] 集成指南（Unity 接入步骤更新）
- [ ] API 对齐与错误码映射表

参考资料
- 预研文档：[飞书文档（内部）](https://sofunny.feishu.cn/wiki/UMrTwFmFjid6sBkwpgvceLR6n2b)


