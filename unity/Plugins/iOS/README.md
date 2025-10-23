# SausageReplay Unity iOS Plugin Integration Guide

This guide outlines the steps to integrate the SausageReplay iOS SDK into your Unity project for iOS builds.

## 1. Plugin Structure

The `unity/Plugins/iOS/` directory contains the following:

- `SausageReplay.xcframework/`: The compiled iOS SDK XCFramework.
- `SausageReplaySDK.h`: Objective-C header for Unity-iOS bridge.
- `SausageReplaySDK.mm`: Objective-C++ implementation for Unity-iOS bridge.

## 2. Integration Steps

### 2.1. Place the Plugin Files

Ensure the `SausageReplay.xcframework` and the bridge files (`SausageReplaySDK.h`, `SausageReplaySDK.mm`) are correctly placed under `Assets/Plugins/iOS/` in your Unity project.

### 2.2. Xcode Project Settings (After Unity Builds Xcode Project)

When Unity builds an Xcode project for iOS, you might need to manually adjust some settings in Xcode.

#### 2.2.1. Add Required Frameworks

In your Xcode project, navigate to your target's "Build Phases" -> "Link Binary With Libraries" and ensure the following frameworks are linked:

- `ReplayKit.framework`
- `AVFoundation.framework`
- `Photos.framework`
- `PhotosUI.framework`

#### 2.2.2. Embed & Sign XCFramework

Ensure that `SausageReplay.xcframework` is correctly embedded and signed.
- In "General" -> "Frameworks, Libraries, and Embedded Content", make sure `SausageReplay.xcframework` is listed and its "Embed" setting is set to "Embed & Sign".

#### 2.2.3. Header Search Paths

If you encounter "file not found" errors for SDK headers (e.g., `SausageReplayIOSSDK.h`), you might need to adjust the "Header Search Paths" in "Build Settings".
- Add `$(PROJECT_DIR)/Libraries/Plugins/RePlaySDK/iOS/SausageReplay.xcframework/ios-arm64/SausageReplay.framework/Headers` (and similar for simulator if needed) to "Header Search Paths" (recursive).
- Alternatively, ensure that the `SausageReplay.xcframework` is correctly added to your project and Xcode can automatically find its headers. Using angle brackets (`<SausageReplay/Header.h>`) for framework imports usually helps Xcode resolve paths correctly.

#### 2.2.4. Other Linker Flags

Ensure `-ObjC` is present in "Other Linker Flags" in "Build Settings" to correctly link Objective-C categories and classes from the SDK.

#### 2.2.5. Privacy Usage Descriptions

Add the following privacy descriptions to your `Info.plist` file:

- `Privacy - Photo Library Additions Usage Description`: `需要访问相册权限来保存录制的视频`
- `Privacy - Photo Library Usage Description`: `需要访问相册权限来保存录制的视频`
- `Privacy - Microphone Usage Description`: `需要访问麦克风权限来录制音频`

## 3. Usage in Unity C#

Refer to `SausageReplaySDK.cs` for the C# interface and example usage.

### 3.1. Basic Usage

```csharp
// Initialize SDK with video quality preset
bool success = SausageReplaySDK.Initialize(VideoQualityPreset.Standard);

// Check platform support
bool supported = SausageReplaySDK.IsPlatformSupported();

// Start recording
RecordingConfig config = new RecordingConfig
{
    qualityPreset = VideoQualityPreset.Standard,
    maxDurationSeconds = 300,
    maxFileSizeBytes = 100 * 1024 * 1024, // 100MB
    includeAudio = true,
    outputFormat = OutputFormat.MP4
};

bool started = SausageReplaySDK.StartRecording(config);

// Stop recording
SausageReplaySDK.StopRecording();

// Get recording status
RecordingStatus status = SausageReplaySDK.GetRecordingStatus();

// Get detailed status
DetailedStatus detailedStatus = SausageReplaySDK.GetDetailedStatus();
```

### 3.2. Available APIs

#### Initialization
- `Initialize(VideoQualityPreset preset)`: Initialize SDK with video quality preset
- `IsPlatformSupported()`: Check if screen recording is supported
- `GetVersion()`: Get SDK version string
- `Release()`: Release SDK resources
- `GetCurrentPreset()`: Get current video quality preset

#### Recording Control
- `StartRecording(RecordingConfig config)`: Start screen recording
- `StopRecording()`: Stop screen recording
- `GetRecordingStatus()`: Get current recording status

#### Quality Adjustment
- `AdjustRecordingQuality(VideoQuality quality)`: Adjust recording quality during recording

#### Status Monitoring
- `GetDetailedStatus()`: Get detailed recording status information

## 4. Video Quality Presets

The SDK supports the following video quality presets:

| Preset | Resolution | FPS | Bitrate | Use Case |
|--------|------------|-----|---------|----------|
| Basic | 720p | 30 | 2 Mbps | Low-end devices |
| Standard | 1080p | 30 | 4 Mbps | General use |
| Smooth | 720p | 60 | 4 Mbps | Smooth motion |
| HighFps | 1080p | 60 | 8 Mbps | High-quality recording |
| Ultra | 1440p | 30/60 | 12 Mbps | Premium devices |

## 5. Recording Configuration

```csharp
public class RecordingConfig
{
    public VideoQualityPreset qualityPreset = VideoQualityPreset.Standard;
    public int maxDurationSeconds = 300; // 5 minutes
    public long maxFileSizeBytes = 100 * 1024 * 1024; // 100MB
    public bool includeAudio = true;
    public OutputFormat outputFormat = OutputFormat.MP4;
}
```

## 6. Error Handling

The SDK uses unified error codes across platforms:

- `0`: Success
- `1000`: Platform not supported
- `1001`: SDK not initialized
- `2000`: Recording already in progress
- `2001`: Recording not started
- `3000`: Permission denied
- `4000`: File system error
- `5000`: Unknown error

## 7. Troubleshooting

### Common Issues

- **"Undefined symbols for architecture arm64"**: This usually means the native functions declared in C# `DllImport` cannot be found.
  - Ensure `SausageReplay.xcframework` is correctly linked and embedded.
  - Verify "Other Linker Flags" include `-ObjC`.
  - Check for any mismatches between C# `DllImport` signatures and native C function signatures in `SausageReplaySDK.h` and `SausageReplaySDK.mm`.

- **"file not found" for SDK headers**:
  - Check "Header Search Paths" in Xcode.
  - Ensure framework imports in `.mm` files use angle brackets (e.g., `#import <SausageReplay/SausageReplayIOSSDK.h>`).

- **Recording fails to start**:
  - Check if screen recording permission is granted.
  - Verify that the app is running in the foreground.
  - Ensure the device supports screen recording.

- **Video files are not playable**:
  - This is a known limitation with ReplayKit. The SDK uses the system's preview interface for saving videos.
  - Users must manually save videos through the system UI.

### Debug Tips

1. Check Xcode console for detailed error messages
2. Verify all required frameworks are linked
3. Ensure privacy usage descriptions are added to Info.plist
4. Test on both simulator and real device

## 8. Version Info

- **SDK Version**: 1.0.0
- **Minimum iOS Version**: 12.0
- **Unity Version**: 2020.3 LTS or later
- **Last Updated**: 2025/01/10

## 9. Update Log

### v1.0.0 (2025/01/10)
- Initial release with simplified API
- Support for video quality presets
- Basic screen recording functionality
- Unity bridge implementation
- iOS Demo application