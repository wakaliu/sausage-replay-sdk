using System;
using System.Runtime.InteropServices;
using UnityEngine;

namespace SausageReplay
{
    // 回调实现已迁移到 UnityRecordingCallbacks.cs

    /// <summary>
    /// Sausage Replay SDK 主接口
    /// 提供屏幕录制功能的Unity C# 桥接
    /// </summary>
    public static class SausageReplaySDK
    {
        #region 枚举定义

        /// <summary>
        /// 视频清晰度档位
        /// </summary>
        public enum VideoQualityPreset
        {
            Basic = 0,      // 720p30
            Standard = 1,   // 1080p30
            Smooth = 2,     // 720p60
            HighFPS = 3,    // 1080p60
            Ultra = 4       // 1440p30/60
        }

        /// <summary>
        /// 视频质量等级
        /// </summary>
        public enum VideoQuality
        {
            LOW = 0,    // 低质量 (480p)
            MEDIUM = 1, // 中等质量 (720p)
            HIGH = 2    // 高质量 (1080p)
        }

        /// <summary>
        /// 输出格式
        /// </summary>
        public enum OutputFormat
        {
            MP4 = 0,   // MP4格式
            GIF = 1,   // GIF格式
            WEBM = 2,  // WebM格式
            AVI = 3    // AVI格式
        }

        /// <summary>
        /// 录制状态
        /// </summary>
        public enum RecordingStatus
        {
            IDLE = 0,     // 空闲
            RECORDING = 1, // 录制中
            PAUSED = 2,   // 已暂停
            STOPPING = 3  // 停止中
        }

        #endregion

        #region 数据结构

        /// <summary>
        /// 录制配置（内部使用，Unity 层不再需要手动配置）
        /// 配置现在由 Android 层根据设备档位自动生成
        /// </summary>
        [Serializable]
        public class RecordingConfig
        {
            public VideoQuality quality = VideoQuality.MEDIUM;
            public int maxDurationSeconds = 60;
            public long maxFileSizeBytes = 50L * 1024 * 1024;
            public bool includeAudio = true;
            public OutputFormat outputFormat = OutputFormat.MP4;
            public string outputPath = null;
            public int? targetBitrate = null;
            public int targetFps = 30;
            public int performanceTier = 1; // 默认使用 STANDARD 档位
        }

        /// <summary>
        /// 录制结果
        /// </summary>
        [Serializable]
        public class RecordingResult
        {
            public bool isSuccess;
            public string filePath;
            public long fileSize;
            public float duration;
            public int errorCode;
            public string errorMessage;
        }

        /// <summary>
        /// 内存使用情况
        /// </summary>
        [Serializable]
        public class MemoryUsage
        {
            public long totalMemory;
            public long usedMemory;
            public long freeMemory;
            public long maxMemory;
            public int usagePercentage;
        }

        /// <summary>
        /// 详细状态信息
        /// </summary>
        [Serializable]
        public class DetailedStatus
        {
            public RecordingStatus status;
            public MemoryUsage memoryUsage;
            public DeviceTierInfo deviceTierInfo; // 替换为设备档位信息
            public bool hasProjection;
            public bool hasRecorder;
            public bool hasDisplay;
            public string outputFile;
            public long outputFileSize;
        }

        /// <summary>
        /// 设备档位信息
        /// </summary>
        [Serializable]
        public class DeviceTierInfo
        {
            public int tier;
            public string tierName;
            public int maxWidth;
            public int maxHeight;
            public int targetFps;
            public long videoBitrate;
            public bool gifSupported;
        }

        /// <summary>
        /// GIF转换参数
        /// </summary>
        [Serializable]
        public class GifConversionParams
        {
            public int maxFps;
            public int maxWidth;
            public int maxHeight;
            public int maxDurationSeconds;
        }

        /// <summary>
        /// 性能指标
        /// </summary>
        [Serializable]
        public class PerformanceMetrics
        {
            public int currentFps;
            public double frameDropRate;
            public int queueDepth;
            public long encodingBlockTime;
            public long totalFrames;
            public long droppedFrames;
        }

        #endregion

        #region 回调接口

        /// <summary>
        /// 录制回调接口
        /// </summary>
        public interface IRecordingCallback
        {
            void OnRecordingStarted();
            void OnRecordingProgress(long durationMs, long fileSizeBytes);
            void OnRecordingPaused();
            void OnRecordingResumed();
            void OnRecordingStopped(RecordingResult result);
            void OnRecordingError(int errorCode, string errorMessage);
            void OnRecordingQualityAdjusted(VideoQuality quality);
        }

        /// <summary>
        /// 性能监控回调接口
        /// </summary>
        public interface IPerformanceCallback
        {
            void OnPerformanceMetrics(PerformanceMetrics metrics);
            void OnBitrateReduction(double reduction);
            void OnBitrateRecovery(double reduction);
            void OnResolutionDegradation(int width, int height);
            void OnResolutionRecovery(int width, int height);
            void OnFpsDegradation(int fps);
            void OnFpsRecovery(int fps);
        }

        #endregion

        #region 事件定义

        /// <summary>
        /// 录制开始事件
        /// </summary>
        public static event Action OnRecordingStarted;

        /// <summary>
        /// 录制进度事件
        /// </summary>
        public static event Action<long, long> OnRecordingProgress;

        /// <summary>
        /// 录制暂停事件
        /// </summary>
        public static event Action OnRecordingPaused;

        /// <summary>
        /// 录制恢复事件
        /// </summary>
        public static event Action OnRecordingResumed;

        /// <summary>
        /// 录制停止事件
        /// </summary>
        public static event Action<RecordingResult> OnRecordingStopped;

        /// <summary>
        /// 录制错误事件
        /// </summary>
        public static event Action<int, string> OnRecordingError;

        /// <summary>
        /// 质量调整事件
        /// </summary>
        public static event Action<VideoQuality> OnRecordingQualityAdjusted;

        /// <summary>
        /// 转换完成事件
        /// </summary>
        public static event Action<bool, string> OnConvertCompleted;

        #endregion

        #region 事件触发方法（供回调类使用）

        /// <summary>
        /// 触发录制开始事件
        /// </summary>
        internal static void TriggerOnRecordingStarted()
        {
            OnRecordingStarted?.Invoke();
        }

        /// <summary>
        /// 触发录制进度事件
        /// </summary>
        internal static void TriggerOnRecordingProgress(long durationMs, long fileSizeBytes)
        {
            OnRecordingProgress?.Invoke(durationMs, fileSizeBytes);
        }

        /// <summary>
        /// 触发录制暂停事件
        /// </summary>
        internal static void TriggerOnRecordingPaused()
        {
            OnRecordingPaused?.Invoke();
        }

        /// <summary>
        /// 触发录制恢复事件
        /// </summary>
        internal static void TriggerOnRecordingResumed()
        {
            OnRecordingResumed?.Invoke();
        }

        /// <summary>
        /// 触发录制停止事件
        /// </summary>
        internal static void TriggerOnRecordingStopped(RecordingResult result)
        {
            OnRecordingStopped?.Invoke(result);
        }

        /// <summary>
        /// 触发录制错误事件
        /// </summary>
        internal static void TriggerOnRecordingError(int errorCode, string errorMessage)
        {
            OnRecordingError?.Invoke(errorCode, errorMessage);
        }

        /// <summary>
        /// 触发质量调整事件
        /// </summary>
        internal static void TriggerOnRecordingQualityAdjusted(VideoQuality quality)
        {
            OnRecordingQualityAdjusted?.Invoke(quality);
        }

        /// <summary>
        /// 触发转换完成事件
        /// </summary>
        internal static void TriggerOnConvertCompleted(bool success, string outputPath)
        {
            OnConvertCompleted?.Invoke(success, outputPath);
        }

        #endregion

        #region 私有字段

        private static IRecordingCallback _recordingCallback;
        private static IPerformanceCallback _performanceCallback;
        private static bool _isInitialized = false;

        #endregion

        #region 公共API

        /// <summary>
        /// 初始化SDK
        /// </summary>
        /// <param name="preset">视频清晰度档位</param>
        /// <returns>是否初始化成功</returns>
        public static bool Initialize(VideoQualityPreset preset = VideoQualityPreset.Standard)
        {
            if (_isInitialized)
            {
                Debug.LogWarning("SausageReplaySDK already initialized");
                return true;
            }

            if (Application.platform != RuntimePlatform.Android)
            {
                Debug.LogError("SausageReplaySDK only supports Android platform");
                return false;
            }

            try
            {
                bool result = SausageReplaySDK_Initialize((int)preset);
                if (result)
                {
                    _isInitialized = true;
                    Debug.Log($"SausageReplaySDK initialized successfully with preset: {preset}");
                }
                else
                {
                    Debug.LogError("Failed to initialize SausageReplaySDK");
                }
                return result;
            }
            catch (Exception e)
            {
                Debug.LogError($"Exception during SausageReplaySDK initialization: {e.Message}");
                return false;
            }
        }

        /// <summary>
        /// 检查平台支持
        /// </summary>
        /// <returns>是否支持</returns>
        public static bool IsPlatformSupported()
        {
            if (!_isInitialized)
            {
                Debug.LogWarning("SausageReplaySDK not initialized");
                return false;
            }

            try
            {
                return SausageReplaySDK_IsPlatformSupported();
            }
            catch (Exception e)
            {
                Debug.LogError($"Exception checking platform support: {e.Message}");
                return false;
            }
        }

        /// <summary>
        /// 获取SDK版本
        /// </summary>
        /// <returns>版本号</returns>
        public static string GetVersion()
        {
            try
            {
                return SausageReplaySDK_GetVersion();
            }
            catch (Exception e)
            {
                Debug.LogError($"Exception getting version: {e.Message}");
                return "Unknown";
            }
        }

        /// <summary>
        /// 开始录制
        /// </summary>
        /// <param name="callback">录制回调</param>
        /// <returns>是否成功开始</returns>
        public static bool StartRecording(IRecordingCallback callback = null)
        {
            if (!_isInitialized)
            {
                Debug.LogError("SausageReplaySDK not initialized");
                return false;
            }

            // 防重复开始：录制中或停止中，直接忽略
            var status = GetRecordingStatus();
            if (status == RecordingStatus.RECORDING || status == RecordingStatus.STOPPING)
            {
                Debug.LogWarning("Recording already in progress, ignore duplicate start");
                return false;
            }

            try
            {
                _recordingCallback = callback;
                return SausageReplaySDK_StartRecording();
            }
            catch (Exception e)
            {
                Debug.LogError($"Exception starting recording: {e.Message}");
                return false;
            }
        }

        /// <summary>
        /// 停止录制
        /// </summary>
        public static void StopRecording()
        {
            if (!_isInitialized)
            {
                Debug.LogError("SausageReplaySDK not initialized");
                return;
            }

            // 添加状态检查，避免重复停止
            var status = GetRecordingStatus();
            if (status != RecordingStatus.RECORDING && status != RecordingStatus.PAUSED)
            {
                Debug.LogWarning($"Cannot stop recording, current status: {status}");
                return;
            }

            try
            {
                SausageReplaySDK_StopRecording();
            }
            catch (Exception e)
            {
                Debug.LogError($"Exception stopping recording: {e.Message}");
            }
        }

        /// <summary>
        /// 强制停止录制（绕过状态检查）
        /// 用于解决 Unity 项目状态不同步的问题
        /// </summary>
        public static void ForceStopRecording()
        {
            if (!_isInitialized)
            {
                Debug.LogError("SausageReplaySDK not initialized");
                return;
            }

            Debug.LogWarning("Force stopping recording (bypassing status check)");
            try
            {
                SausageReplaySDK_StopRecording();
            }
            catch (Exception e)
            {
                Debug.LogError($"Exception force stopping recording: {e.Message}");
            }
        }

        /// <summary>
        /// 暂停录制
        /// </summary>
        /// <returns>是否成功暂停</returns>
        public static bool PauseRecording()
        {
            if (!_isInitialized)
            {
                Debug.LogError("SausageReplaySDK not initialized");
                return false;
            }

            try
            {
                return SausageReplaySDK_PauseRecording();
            }
            catch (Exception e)
            {
                Debug.LogError($"Exception pausing recording: {e.Message}");
                return false;
            }
        }

        /// <summary>
        /// 恢复录制
        /// </summary>
        /// <returns>是否成功恢复</returns>
        public static bool ResumeRecording()
        {
            if (!_isInitialized)
            {
                Debug.LogError("SausageReplaySDK not initialized");
                return false;
            }

            try
            {
                return SausageReplaySDK_ResumeRecording();
            }
            catch (Exception e)
            {
                Debug.LogError($"Exception resuming recording: {e.Message}");
                return false;
            }
        }

        /// <summary>
        /// 调整录制质量
        /// </summary>
        /// <param name="quality">目标质量</param>
        /// <returns>是否成功调整</returns>
        public static bool AdjustRecordingQuality(VideoQuality quality)
        {
            if (!_isInitialized)
            {
                Debug.LogError("SausageReplaySDK not initialized");
                return false;
            }

            try
            {
                return SausageReplaySDK_AdjustRecordingQuality((int)quality);
            }
            catch (Exception e)
            {
                Debug.LogError($"Exception adjusting quality: {e.Message}");
                return false;
            }
        }

        /// <summary>
        /// 转换视频格式
        /// </summary>
        /// <param name="inputPath">输入文件路径</param>
        /// <param name="outputFormat">目标格式</param>
        /// <param name="callback">转换结果回调</param>
        public static void ConvertVideoFormat(string inputPath, OutputFormat outputFormat, Action<bool, string> callback)
        {
            if (!_isInitialized)
            {
                Debug.LogError("SausageReplaySDK not initialized");
                callback?.Invoke(false, "SDK not initialized");
                return;
            }

            try
            {
                SausageReplaySDK_ConvertVideoFormat(inputPath, (int)outputFormat, callback);
            }
            catch (Exception e)
            {
                Debug.LogError($"Exception converting format: {e.Message}");
                callback?.Invoke(false, e.Message);
            }
        }

        /// <summary>
        /// 获取录制状态
        /// </summary>
        /// <returns>当前状态</returns>
        public static RecordingStatus GetRecordingStatus()
        {
            if (!_isInitialized)
            {
                return RecordingStatus.IDLE;
            }

            try
            {
                return (RecordingStatus)SausageReplaySDK_GetRecordingStatus();
            }
            catch (Exception e)
            {
                Debug.LogError($"Exception getting status: {e.Message}");
                return RecordingStatus.IDLE;
            }
        }

        /// <summary>
        /// 获取详细状态
        /// </summary>
        /// <returns>详细状态信息</returns>
        public static DetailedStatus GetDetailedStatus()
        {
            if (!_isInitialized)
            {
                return null;
            }

            try
            {
                string statusJson = SausageReplaySDK_GetDetailedStatus();
                return JsonUtility.FromJson<DetailedStatus>(statusJson);
            }
            catch (Exception e)
            {
                Debug.LogError($"Exception getting detailed status: {e.Message}");
                return null;
            }
        }

        /// <summary>
        /// 获取内存使用情况
        /// </summary>
        /// <returns>内存使用信息</returns>
        public static MemoryUsage GetMemoryUsage()
        {
            if (!_isInitialized)
            {
                return null;
            }

            try
            {
                string memoryJson = SausageReplaySDK_GetMemoryUsage();
                return JsonUtility.FromJson<MemoryUsage>(memoryJson);
            }
            catch (Exception e)
            {
                Debug.LogError($"Exception getting memory usage: {e.Message}");
                return null;
            }
        }

        /// <summary>
        /// 错误恢复
        /// </summary>
        /// <returns>是否成功恢复</returns>
        public static bool RecoverFromError()
        {
            if (!_isInitialized)
            {
                Debug.LogError("SausageReplaySDK not initialized");
                return false;
            }

            try
            {
                return SausageReplaySDK_RecoverFromError();
            }
            catch (Exception e)
            {
                Debug.LogError($"Exception recovering from error: {e.Message}");
                return false;
            }
        }

        /// <summary>
        /// 重置状态
        /// </summary>
        public static void ResetStatus()
        {
            if (!_isInitialized)
            {
                Debug.LogError("SausageReplaySDK not initialized");
                return;
            }

            try
            {
                SausageReplaySDK_ResetStatus();
            }
            catch (Exception e)
            {
                Debug.LogError($"Exception resetting status: {e.Message}");
            }
        }

        /// <summary>
        /// 释放SDK资源
        /// </summary>
        public static void Release()
        {
            if (!_isInitialized)
            {
                return;
            }

            try
            {
                SausageReplaySDK_Release();
                _isInitialized = false;
                _recordingCallback = null;
                _performanceCallback = null;
                Debug.Log("SausageReplaySDK released successfully");
            }
            catch (Exception e)
            {
                Debug.LogError($"Exception releasing SDK: {e.Message}");
            }
        }

        #endregion

        #region 高级API

        /// <summary>
        /// 获取设备档位信息
        /// </summary>
        /// <returns>设备档位信息</returns>
        public static DeviceTierInfo GetDeviceTierInfo()
        {
            if (!_isInitialized)
            {
                return null;
            }

            try
            {
                string tierJson = SausageReplaySDK_GetDeviceTierInfo();
                return JsonUtility.FromJson<DeviceTierInfo>(tierJson);
            }
            catch (Exception e)
            {
                Debug.LogError($"Exception getting device tier info: {e.Message}");
                return null;
            }
        }

        /// <summary>
        /// 检查GIF转换是否支持
        /// </summary>
        /// <returns>是否支持</returns>
        public static bool IsGifConversionSupported()
        {
            if (!_isInitialized)
            {
                return false;
            }

            try
            {
                return SausageReplaySDK_IsGifConversionSupported();
            }
            catch (Exception e)
            {
                Debug.LogError($"Exception checking GIF support: {e.Message}");
                return false;
            }
        }

        /// <summary>
        /// 获取GIF转换参数
        /// </summary>
        /// <returns>GIF转换参数</returns>
        public static GifConversionParams GetGifConversionParams()
        {
            if (!_isInitialized)
            {
                return null;
            }

            try
            {
                string paramsJson = SausageReplaySDK_GetGifConversionParams();
                return JsonUtility.FromJson<GifConversionParams>(paramsJson);
            }
            catch (Exception e)
            {
                Debug.LogError($"Exception getting GIF params: {e.Message}");
                return null;
            }
        }

        /// <summary>
        /// 重新加载设备档位配置
        /// </summary>
        /// <returns>是否成功重新加载</returns>
        public static bool ReloadDeviceTierConfig()
        {
            if (!_isInitialized)
            {
                Debug.LogError("SausageReplaySDK not initialized");
                return false;
            }

            try
            {
                return SausageReplaySDK_ReloadDeviceTierConfig();
            }
            catch (Exception e)
            {
                Debug.LogError($"Exception reloading config: {e.Message}");
                return false;
            }
        }

        #endregion

        #region Android JNI 调用

#if UNITY_ANDROID && !UNITY_EDITOR
        private const string SDK_CLASS_NAME = "com.funny.replaysdk.SausageReplayAndroidSDK";
        private const string RECORDING_MANAGER_CLASS_NAME = "com.funny.replaysdk.RecordingManager";
        private const string PERMISSION_MANAGER_CLASS_NAME = "com.funny.replaysdk.PermissionManager";

        private static AndroidJavaClass _sdkClass;
        private static AndroidJavaClass _recordingManagerClass;
        private static AndroidJavaClass _permissionManagerClass;
        private static AndroidJavaObject _currentActivity;

        /// <summary>
        /// 获取SDK类实例
        /// </summary>
        private static AndroidJavaClass SdkClass
        {
            get
            {
                if (_sdkClass == null)
                {
                    try
                    {
                        Debug.Log($"[SausageReplaySDK] Initializing Android SDK class: {SDK_CLASS_NAME}");
                        _sdkClass = new AndroidJavaClass(SDK_CLASS_NAME);
                        Debug.Log("[SausageReplaySDK] Android SDK class initialized successfully");
                    }
                    catch (Exception e)
                    {
                        Debug.LogError($"[SausageReplaySDK] Failed to initialize Android SDK class: {e.Message}");
                        Debug.LogError($"[SausageReplaySDK] Exception type: {e.GetType().Name}");
                        throw;
                    }
                }
                return _sdkClass;
            }
        }

        /// <summary>
        /// 获取录制管理器类实例
        /// </summary>
        private static AndroidJavaClass RecordingManagerClass
        {
            get
            {
                if (_recordingManagerClass == null)
                {
                    _recordingManagerClass = new AndroidJavaClass(RECORDING_MANAGER_CLASS_NAME);
                }
                return _recordingManagerClass;
            }
        }

        /// <summary>
        /// 获取权限管理器类实例
        /// </summary>
        private static AndroidJavaClass PermissionManagerClass
        {
            get
            {
                if (_permissionManagerClass == null)
                {
                    _permissionManagerClass = new AndroidJavaClass(PERMISSION_MANAGER_CLASS_NAME);
                }
                return _permissionManagerClass;
            }
        }

        /// <summary>
        /// 获取当前Activity实例
        /// </summary>
        private static AndroidJavaObject CurrentActivity
        {
            get
            {
                if (_currentActivity == null)
                {
                    try
                    {
                        Debug.Log("[SausageReplaySDK] Getting Unity current activity...");
                        using (AndroidJavaClass unityPlayer = new AndroidJavaClass("com.unity3d.player.UnityPlayer"))
                        {
                            _currentActivity = unityPlayer.GetStatic<AndroidJavaObject>("currentActivity");
                            Debug.Log($"[SausageReplaySDK] Current activity obtained: {_currentActivity != null}");
                        }
                    }
                    catch (Exception e)
                    {
                        Debug.LogError($"[SausageReplaySDK] Failed to get current activity: {e.Message}");
                        throw;
                    }
                }
                return _currentActivity;
            }
        }

        // Android JNI 方法实现
        private static bool SausageReplaySDK_Initialize(int tier)
        {
            try
            {
                Debug.Log($"[SausageReplaySDK] Initializing SDK with tier: {tier}");
                
                // 注册 Unity 回调
                var recordingCallback = new UnityRecordingCallbackImpl();
                var convertCallback = new UnityConvertCallbackImpl();
                
                RecordingManagerClass.CallStatic("setUnityRecordingCallback", recordingCallback);
                RecordingManagerClass.CallStatic("setUnityConvertCallback", convertCallback);
                
                // 直接传递整型参数：SausageReplayAndroidSDK.initialize(Context, Int)
                bool result = SdkClass.CallStatic<bool>("initialize", CurrentActivity, tier);
                
                Debug.Log($"[SausageReplaySDK] Initialize result: {result}");
                return result;
            }
            catch (Exception e)
            {
                Debug.LogError($"[SausageReplaySDK] Failed to initialize SDK: {e.Message}");
                Debug.LogError($"[SausageReplaySDK] Exception type: {e.GetType().Name}");
                if (e.InnerException != null)
                {
                    Debug.LogError($"[SausageReplaySDK] Inner exception: {e.InnerException.Message}");
                }
                return false;
            }
        }

        private static bool SausageReplaySDK_IsPlatformSupported()
        {
            try
            {
                return SdkClass.CallStatic<bool>("isPlatformSupported");
            }
            catch (Exception e)
            {
                Debug.LogError($"Failed to check platform support: {e.Message}");
                return false;
            }
        }

        private static string SausageReplaySDK_GetVersion()
        {
            try
            {
                return SdkClass.CallStatic<string>("getVersion");
            }
            catch (Exception e)
            {
                Debug.LogError($"Failed to get version: {e.Message}");
                return "1.0.0";
            }
        }

        private static bool SausageReplaySDK_StartRecording()
        {
            try
            {
                // 直接调用 Android SDK 方法，不传递任何配置参数
                // Android 层会根据初始化时的设备档位自动生成配置
                return RecordingManagerClass.CallStatic<bool>("startRecording", CurrentActivity);
            }
            catch (Exception e)
            {
                Debug.LogError($"Failed to start recording: {e.Message}");
                return false;
            }
        }

        private static void SausageReplaySDK_StopRecording()
        {
            try
            {
                // 直接调用，无需传入 Runnable；结果由全局回调处理
                RecordingManagerClass.CallStatic("stopRecording");
            }
            catch (Exception e)
            {
                Debug.LogError($"Failed to stop recording: {e.Message}");
            }
        }

        private static bool SausageReplaySDK_PauseRecording()
        {
            try
            {
                return RecordingManagerClass.CallStatic<bool>("pauseRecording");
            }
            catch (Exception e)
            {
                Debug.LogError($"Failed to pause recording: {e.Message}");
                return false;
            }
        }

        private static bool SausageReplaySDK_ResumeRecording()
        {
            try
            {
                return RecordingManagerClass.CallStatic<bool>("resumeRecording");
            }
            catch (Exception e)
            {
                Debug.LogError($"Failed to resume recording: {e.Message}");
                return false;
            }
        }

        private static bool SausageReplaySDK_AdjustRecordingQuality(int quality)
        {
            try
            {
                return RecordingManagerClass.CallStatic<bool>("adjustRecordingQuality", quality);
            }
            catch (Exception e)
            {
                Debug.LogError($"Failed to adjust recording quality: {e.Message}");
                return false;
            }
        }

        private static void SausageReplaySDK_ConvertVideoFormat(string inputPath, int outputFormat, Action<bool, string> callback)
        {
            try
            {
                // 直接调用，无需传入 Runnable；结果由全局回调处理
                RecordingManagerClass.CallStatic("convertVideoFormat", inputPath, outputFormat);
            }
            catch (Exception e)
            {
                Debug.LogError($"Failed to convert video format: {e.Message}");
                callback?.Invoke(false, e.Message);
            }
        }

        private static int SausageReplaySDK_GetRecordingStatus()
        {
            try
            {
                return RecordingManagerClass.CallStatic<int>("getRecordingStatus");
            }
            catch (Exception e)
            {
                Debug.LogError($"Failed to get recording status: {e.Message}");
                return 0;
            }
        }

        private static string SausageReplaySDK_GetDetailedStatus()
        {
            try
            {
                return RecordingManagerClass.CallStatic<string>("getDetailedStatusJson");
            }
            catch (Exception e)
            {
                Debug.LogError($"Failed to get detailed status: {e.Message}");
                return "{}";
            }
        }

        private static string SausageReplaySDK_GetMemoryUsage()
        {
            try
            {
                return SdkClass.CallStatic<string>("getMemoryUsage");
            }
            catch (Exception e)
            {
                Debug.LogError($"Failed to get memory usage: {e.Message}");
                return "{}";
            }
        }

        private static bool SausageReplaySDK_RecoverFromError()
        {
            try
            {
                return RecordingManagerClass.CallStatic<bool>("recoverFromError");
            }
            catch (Exception e)
            {
                Debug.LogError($"Failed to recover from error: {e.Message}");
                return false;
            }
        }

        private static void SausageReplaySDK_ResetStatus()
        {
            try
            {
                RecordingManagerClass.CallStatic("resetStatus");
            }
            catch (Exception e)
            {
                Debug.LogError($"Failed to reset status: {e.Message}");
            }
        }

        private static void SausageReplaySDK_Release()
        {
            try
            {
                SdkClass.CallStatic("release");
                
                // 清理静态引用
                _sdkClass?.Dispose();
                _recordingManagerClass?.Dispose();
                _permissionManagerClass?.Dispose();
                _currentActivity?.Dispose();
                
                _sdkClass = null;
                _recordingManagerClass = null;
                _permissionManagerClass = null;
                _currentActivity = null;
            }
            catch (Exception e)
            {
                Debug.LogError($"Failed to release SDK: {e.Message}");
            }
        }

        private static string SausageReplaySDK_GetDeviceTierInfo()
        {
            try
            {
                return SdkClass.CallStatic<string>("getDeviceTierInfo");
            }
            catch (Exception e)
            {
                Debug.LogError($"Failed to get device tier info: {e.Message}");
                return "{}";
            }
        }

        private static bool SausageReplaySDK_IsGifConversionSupported()
        {
            try
            {
                return SdkClass.CallStatic<bool>("isGifConversionSupported");
            }
            catch (Exception e)
            {
                Debug.LogError($"Failed to check GIF conversion support: {e.Message}");
                return false;
            }
        }

        private static string SausageReplaySDK_GetGifConversionParams()
        {
            try
            {
                return SdkClass.CallStatic<string>("getGifConversionParams");
            }
            catch (Exception e)
            {
                Debug.LogError($"Failed to get GIF conversion params: {e.Message}");
                return "{}";
            }
        }

        private static bool SausageReplaySDK_ReloadDeviceTierConfig()
        {
            try
            {
                return SdkClass.CallStatic<bool>("reloadDeviceTierConfig");
            }
            catch (Exception e)
            {
                Debug.LogError($"Failed to reload device tier config: {e.Message}");
                return false;
            }
        }

        // 权限相关方法
        private static bool SausageReplaySDK_HasMicrophonePermission()
        {
            try
            {
                return PermissionManagerClass.CallStatic<bool>("hasMicrophonePermission", CurrentActivity);
            }
            catch (Exception e)
            {
                Debug.LogError($"Failed to check microphone permission: {e.Message}");
                return false;
            }
        }

        private static void SausageReplaySDK_RequestMicrophonePermission()
        {
            try
            {
                PermissionManagerClass.CallStatic("requestMicrophonePermission", CurrentActivity, new AndroidJavaRunnable(() =>
                {
                    // 权限请求完成的回调处理
                    UnityMainThreadDispatcher.Enqueue(() =>
                    {
                        OnMicrophonePermissionResult?.Invoke(true);
                    });
                }));
            }
            catch (Exception e)
            {
                Debug.LogError($"Failed to request microphone permission: {e.Message}");
                OnMicrophonePermissionResult?.Invoke(false);
            }
        }

        private static bool SausageReplaySDK_StartProgressMonitoring()
        {
            try
            {
                return RecordingManagerClass.CallStatic<bool>("startProgressMonitoring");
            }
            catch (Exception e)
            {
                Debug.LogError($"Failed to start progress monitoring: {e.Message}");
                return false;
            }
        }

        private static void SausageReplaySDK_StopProgressMonitoring()
        {
            try
            {
                RecordingManagerClass.CallStatic("stopProgressMonitoring");
            }
            catch (Exception e)
            {
                Debug.LogError($"Failed to stop progress monitoring: {e.Message}");
            }
        }

#else
        // Editor 模式下的模拟实现
        private static bool SausageReplaySDK_Initialize(int tier) => false;
        private static bool SausageReplaySDK_IsPlatformSupported() => false;
        private static string SausageReplaySDK_GetVersion() => "1.0.0";
        private static bool SausageReplaySDK_StartRecording() => false;
        private static void SausageReplaySDK_StopRecording() { }
        private static bool SausageReplaySDK_PauseRecording() => false;
        private static bool SausageReplaySDK_ResumeRecording() => false;
        private static bool SausageReplaySDK_AdjustRecordingQuality(int quality) => false;
        private static void SausageReplaySDK_ConvertVideoFormat(string inputPath, int outputFormat, Action<bool, string> callback) 
        {
            callback?.Invoke(false, "Not supported in editor");
        }
        private static int SausageReplaySDK_GetRecordingStatus() => 0;
        private static string SausageReplaySDK_GetDetailedStatus() => "{}";
        private static string SausageReplaySDK_GetMemoryUsage() => "{}";
        private static bool SausageReplaySDK_RecoverFromError() => false;
        private static void SausageReplaySDK_ResetStatus() { }
        private static void SausageReplaySDK_Release() { }
        private static string SausageReplaySDK_GetDeviceTierInfo() => "{}";
        private static bool SausageReplaySDK_IsGifConversionSupported() => false;
        private static string SausageReplaySDK_GetGifConversionParams() => "{}";
        private static bool SausageReplaySDK_ReloadDeviceTierConfig() => false;
        private static bool SausageReplaySDK_HasMicrophonePermission() => false;
        private static void SausageReplaySDK_RequestMicrophonePermission() { }
        private static bool SausageReplaySDK_StartProgressMonitoring() => false;
        private static void SausageReplaySDK_StopProgressMonitoring() { }
#endif

        #endregion

        #region 回调处理

        /// <summary>
        /// 处理录制开始回调
        /// </summary>
        [AOT.MonoPInvokeCallback(typeof(Action))]
        private static void OnRecordingStartedCallback()
        {
            UnityMainThreadDispatcher.Enqueue(() =>
            {
                _recordingCallback?.OnRecordingStarted();
                OnRecordingStarted?.Invoke();
            });
        }

        /// <summary>
        /// 处理录制进度回调
        /// </summary>
        [AOT.MonoPInvokeCallback(typeof(Action<long, long>))]
        private static void OnRecordingProgressCallback(long durationMs, long fileSizeBytes)
        {
            UnityMainThreadDispatcher.Enqueue(() =>
            {
                _recordingCallback?.OnRecordingProgress(durationMs, fileSizeBytes);
                OnRecordingProgress?.Invoke(durationMs, fileSizeBytes);
            });
        }

        /// <summary>
        /// 处理录制暂停回调
        /// </summary>
        [AOT.MonoPInvokeCallback(typeof(Action))]
        private static void OnRecordingPausedCallback()
        {
            UnityMainThreadDispatcher.Enqueue(() =>
            {
                _recordingCallback?.OnRecordingPaused();
                OnRecordingPaused?.Invoke();
            });
        }

        /// <summary>
        /// 处理录制恢复回调
        /// </summary>
        [AOT.MonoPInvokeCallback(typeof(Action))]
        private static void OnRecordingResumedCallback()
        {
            UnityMainThreadDispatcher.Enqueue(() =>
            {
                _recordingCallback?.OnRecordingResumed();
                OnRecordingResumed?.Invoke();
            });
        }

        /// <summary>
        /// 处理录制停止回调
        /// </summary>
        [AOT.MonoPInvokeCallback(typeof(Action<string>))]
        private static void OnRecordingStoppedCallback(string resultJson)
        {
            UnityMainThreadDispatcher.Enqueue(() =>
            {
                try
                {
                    RecordingResult result = JsonUtility.FromJson<RecordingResult>(resultJson);
                    _recordingCallback?.OnRecordingStopped(result);
                    OnRecordingStopped?.Invoke(result);
                }
                catch (Exception e)
                {
                    Debug.LogError($"Exception parsing recording result: {e.Message}");
                }
            });
        }

        /// <summary>
        /// 处理录制错误回调
        /// </summary>
        [AOT.MonoPInvokeCallback(typeof(Action<int, string>))]
        private static void OnRecordingErrorCallback(int errorCode, string errorMessage)
        {
            UnityMainThreadDispatcher.Enqueue(() =>
            {
                _recordingCallback?.OnRecordingError(errorCode, errorMessage);
                OnRecordingError?.Invoke(errorCode, errorMessage);
            });
        }

        /// <summary>
        /// 处理质量调整回调
        /// </summary>
        [AOT.MonoPInvokeCallback(typeof(Action<int>))]
        private static void OnRecordingQualityAdjustedCallback(int quality)
        {
            UnityMainThreadDispatcher.Enqueue(() =>
            {
                VideoQuality videoQuality = (VideoQuality)quality;
                _recordingCallback?.OnRecordingQualityAdjusted(videoQuality);
                OnRecordingQualityAdjusted?.Invoke(videoQuality);
            });
        }

        #endregion
    }

    #region Unity 回调实现类

    /// <summary>
    /// Unity 录制回调实现
    /// </summary>
    public class UnityRecordingCallbackImpl : AndroidJavaProxy
    {
        public UnityRecordingCallbackImpl() : base("com.funny.replaysdk.UnityRecordingCallback") { }

        public void onRecordingStarted()
        {
            UnityMainThreadDispatcher.Enqueue(() => {
                SausageReplaySDK.TriggerOnRecordingStarted();
            });
        }

        public void onRecordingProgress(long durationMs, long fileSizeBytes)
        {
            UnityMainThreadDispatcher.Enqueue(() => {
                SausageReplaySDK.TriggerOnRecordingProgress(durationMs, fileSizeBytes);
            });
        }

        public void onRecordingPaused()
        {
            UnityMainThreadDispatcher.Enqueue(() => {
                SausageReplaySDK.TriggerOnRecordingPaused();
            });
        }

        public void onRecordingResumed()
        {
            UnityMainThreadDispatcher.Enqueue(() => {
                SausageReplaySDK.TriggerOnRecordingResumed();
            });
        }

        public void onRecordingStopped(bool success, string filePath, long fileSize, float duration, int errorCode, string errorMessage)
        {
            UnityMainThreadDispatcher.Enqueue(() => {
                var result = new SausageReplaySDK.RecordingResult
                {
                    isSuccess = success,
                    filePath = filePath,
                    fileSize = fileSize,
                    duration = duration,
                    errorCode = errorCode,
                    errorMessage = errorMessage
                };
                SausageReplaySDK.TriggerOnRecordingStopped(result);
            });
        }

        public void onRecordingError(int errorCode, string errorMessage)
        {
            UnityMainThreadDispatcher.Enqueue(() => {
                SausageReplaySDK.TriggerOnRecordingError(errorCode, errorMessage);
            });
        }

        public void onRecordingQualityAdjusted(int quality)
        {
            UnityMainThreadDispatcher.Enqueue(() => {
                SausageReplaySDK.TriggerOnRecordingQualityAdjusted((SausageReplaySDK.VideoQuality)quality);
            });
        }
    }

    /// <summary>
    /// Unity 转换回调实现
    /// </summary>
    public class UnityConvertCallbackImpl : AndroidJavaProxy
    {
        public UnityConvertCallbackImpl() : base("com.funny.replaysdk.UnityConvertCallback") { }

        public void onConvertCompleted(bool success, string outputPath)
        {
            UnityMainThreadDispatcher.Enqueue(() => {
                SausageReplaySDK.TriggerOnConvertCompleted(success, outputPath);
            });
        }
    }

    #endregion
}
