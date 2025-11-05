using System;
using System.Runtime.InteropServices;
using UnityEngine;

namespace SausageReplay
{
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
        /// 录制状态
        /// </summary>
        public enum RecordingStatus
        {
            IDLE = 0,     // 空闲
            RECORDING = 1, // 录制中
            STOPPING = 2  // 停止中
        }

        #endregion

        #region 数据结构

        /// <summary>
        /// 录制结果
        /// </summary>
        [Serializable]
        public class RecordingResult
        {
            public bool isSuccess;
            public string filePath;        // 相对路径（Android）或文件名（iOS）
            public long fileSize;
            public float duration;
            public string fileMd5;         // 文件MD5哈希（用于完整性验证）
#if UNITY_IOS && !UNITY_EDITOR
            public string assetLocalId;    // iOS相册资源ID（PHAsset.localIdentifier）
#endif
            public int errorCode;
            public string errorMessage;
        }

        /// <summary>
        /// 详细状态信息
        /// </summary>
        [Serializable]
        public class DetailedStatus
        {
            public RecordingStatus status;
            public bool isRecording;
            public long duration;
            public long fileSize;
            public int errorCode;
            public string errorMessage;
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
            void OnRecordingStopped(RecordingResult result);
            void OnRecordingError(int errorCode, string errorMessage);
        }

        #endregion

        #region 事件定义

        public static event Action OnRecordingStarted;
        public static event Action<long, long> OnRecordingProgress;
        public static event Action<RecordingResult> OnRecordingStopped;
        public static event Action<int, string> OnRecordingError;

        #endregion

        #region 事件触发（供回调类使用）

        internal static void TriggerOnRecordingStarted() { OnRecordingStarted?.Invoke(); }
        internal static void TriggerOnRecordingProgress(long durationMs, long fileSizeBytes) { OnRecordingProgress?.Invoke(durationMs, fileSizeBytes); }
        internal static void TriggerOnRecordingStopped(RecordingResult result) { OnRecordingStopped?.Invoke(result); }
        internal static void TriggerOnRecordingError(int errorCode, string errorMessage) { OnRecordingError?.Invoke(errorCode, errorMessage); }

        #endregion

        #region 私有字段

        private static IRecordingCallback _recordingCallback;
        private static bool _isInitialized = false;

        #endregion

        #region 公共API

        public static bool Initialize(VideoQualityPreset preset = VideoQualityPreset.Standard, bool enableDebugLog = true)
        {
            if (_isInitialized) { Debug.LogWarning("SausageReplaySDK already initialized"); return true; }
            if (Application.platform != RuntimePlatform.Android && Application.platform != RuntimePlatform.IPhonePlayer) { Debug.LogError("SausageReplaySDK only supports Android and iOS platforms"); return false; }
            try
            {
                bool result = SausageReplaySDK_Initialize((int)preset, enableDebugLog);
                if (result)
                {
                    _isInitialized = true;
#if UNITY_IOS && !UNITY_EDITOR
                    SausageReplaySDK_SetRecordingStartedCallback(OnRecordingStartedCallback);
                    SausageReplaySDK_SetRecordingProgressCallback(OnRecordingProgressCallback);
                    SausageReplaySDK_SetRecordingStoppedCallback(OnRecordingStoppedCallback);
                    SausageReplaySDK_SetRecordingErrorCallback(OnRecordingErrorCallback);
#endif
                    Debug.Log($"SausageReplaySDK initialized successfully with preset: {preset}, enableDebugLog: {enableDebugLog}");
                }
                else { Debug.LogError("Failed to initialize SausageReplaySDK"); }
                return result;
            }
            catch (Exception e) { Debug.LogError($"Exception during SausageReplaySDK initialization: {e.Message}"); return false; }
        }

        public static bool IsPlatformSupported()
        {
            if (!_isInitialized) { Debug.LogWarning("SausageReplaySDK not initialized"); return false; }
            try { return SausageReplaySDK_IsPlatformSupported(); }
            catch (Exception e) { Debug.LogError($"Exception checking platform support: {e.Message}"); return false; }
        }

        public static string GetVersion()
        {
            try { return SausageReplaySDK_GetVersion(); }
            catch (Exception e) { Debug.LogError($"Exception getting version: {e.Message}"); return "Unknown"; }
        }

        public static bool StartRecording(IRecordingCallback callback = null)
        {
            if (!_isInitialized) { Debug.LogError("SausageReplaySDK not initialized"); return false; }
            var status = GetRecordingStatus();
            if (status == RecordingStatus.RECORDING || status == RecordingStatus.STOPPING) { Debug.LogWarning("Recording already in progress, ignore duplicate start"); return false; }
            try { _recordingCallback = callback; return SausageReplaySDK_StartRecording(); }
            catch (Exception e) { Debug.LogError($"Exception starting recording: {e.Message}"); return false; }
        }

        private static AndroidJavaObject CreateRecordingConfig(int maxDurationSeconds = 1800, long maxFileSizeBytes = 300L * 1024 * 1024, bool includeAudio = false, int targetBitrate = 0, int targetFps = 30, int performanceTier = 0)
        {
#if UNITY_ANDROID && !UNITY_EDITOR
            try
            {
                return new AndroidJavaObject("com.funny.replaysdk.RecordingConfig", maxDurationSeconds, maxFileSizeBytes, includeAudio, targetBitrate, targetFps, performanceTier);
            }
            catch (System.Exception e) { Debug.LogError($"SausageReplaySDK Failed to create RecordingConfig: {e.Message}"); return null; }
#else
            return null;
#endif
        }

        public static bool StartRecordingWithCustomConfig()
        {
#if UNITY_ANDROID && !UNITY_EDITOR
            var presetClass = new AndroidJavaClass("com.funny.replaysdk.VideoQualityPreset");
            int preset = presetClass.GetStatic<int>("STANDARD");
            var config = CreateRecordingConfig(60, 500L * 1024 * 1024, true, 10000000, 60, preset);
            if (config != null)
            {
                bool success = RecordingManagerClass.CallStatic<bool>("startRecording", CurrentActivity, config, null);
                Debug.Log($"SausageReplaySDK Start recording: {success}");
                return success;
            }
#endif
            return false;
        }

        public static void StopRecording()
        {
            if (!_isInitialized) { Debug.LogError("SausageReplaySDK not initialized"); return; }
            var status = GetRecordingStatus();
            if (status == RecordingStatus.IDLE) { Debug.LogWarning($"Cannot stop recording when idle"); return; }
            try { SausageReplaySDK_StopRecording(); }
            catch (Exception e) { Debug.LogError($"Exception stopping recording: {e.Message}"); }
        }

        public static RecordingStatus GetRecordingStatus()
        {
            if (!_isInitialized) { return RecordingStatus.IDLE; }
            try { return (RecordingStatus)SausageReplaySDK_GetRecordingStatus(); }
            catch (Exception e) { Debug.LogError($"Exception getting status: {e.Message}"); return RecordingStatus.IDLE; }
        }

        public static DetailedStatus GetDetailedStatus()
        {
            if (!_isInitialized) { return null; }
            try { string statusJson = SausageReplaySDK_GetDetailedStatus(); return JsonUtility.FromJson<DetailedStatus>(statusJson); }
            catch (Exception e) { Debug.LogError($"Exception getting detailed status: {e.Message}"); return null; }
        }

        public static void Release()
        {
            if (!_isInitialized) { return; }
            try { SausageReplaySDK_Release(); _isInitialized = false; _recordingCallback = null; Debug.Log("SausageReplaySDK released successfully"); }
            catch (Exception e) { Debug.LogError($"Exception releasing SDK: {e.Message}"); }
        }

        #endregion

        #region iOS Native 调用 / Android JNI

#if UNITY_IOS && !UNITY_EDITOR
        [DllImport("__Internal")] private static extern bool SausageReplaySDK_Initialize(int preset, bool enableDebugLog);
        [DllImport("__Internal")] private static extern bool SausageReplaySDK_IsPlatformSupported();
        [DllImport("__Internal")] private static extern string SausageReplaySDK_GetVersion();
        [DllImport("__Internal")] private static extern void SausageReplaySDK_Release();
        [DllImport("__Internal")] private static extern bool SausageReplaySDK_StartRecording();
        [DllImport("__Internal")] private static extern void SausageReplaySDK_StopRecording();
        [DllImport("__Internal")] private static extern int SausageReplaySDK_GetRecordingStatus();
        [DllImport("__Internal")] private static extern string SausageReplaySDK_GetDetailedStatus();
        [DllImport("__Internal")] private static extern void SausageReplaySDK_SetRecordingStartedCallback(Action callback);
        [DllImport("__Internal")] private static extern void SausageReplaySDK_SetRecordingProgressCallback(Action<long, long> callback);
        [DllImport("__Internal")] private static extern void SausageReplaySDK_SetRecordingStoppedCallback(Action<string> callback);
        [DllImport("__Internal")] private static extern void SausageReplaySDK_SetRecordingErrorCallback(Action<int, string> callback);
#elif UNITY_ANDROID && !UNITY_EDITOR
        private const string SDK_CLASS_NAME = "com.funny.replaysdk.SausageReplayAndroidSDK";
        private const string RECORDING_MANAGER_CLASS_NAME = "com.funny.replaysdk.RecordingManager";
        private const string PERMISSION_MANAGER_CLASS_NAME = "com.funny.replaysdk.PermissionManager";
        private static AndroidJavaClass _sdkClass; private static AndroidJavaClass _recordingManagerClass; private static AndroidJavaClass _permissionManagerClass; private static AndroidJavaObject _currentActivity;
        private static AndroidJavaClass SdkClass { get { if (_sdkClass == null) { _sdkClass = new AndroidJavaClass(SDK_CLASS_NAME); } return _sdkClass; } }
        private static AndroidJavaClass RecordingManagerClass { get { if (_recordingManagerClass == null) { _recordingManagerClass = new AndroidJavaClass(RECORDING_MANAGER_CLASS_NAME); } return _recordingManagerClass; } }
        private static AndroidJavaObject CurrentActivity { get { if (_currentActivity == null) { using (AndroidJavaClass unityPlayer = new AndroidJavaClass("com.unity3d.player.UnityPlayer")) { _currentActivity = unityPlayer.GetStatic<AndroidJavaObject>("currentActivity"); } } return _currentActivity; } }
        private static bool SausageReplaySDK_Initialize(int preset, bool enableDebugLog) { try { var recordingCallback = new UnityRecordingCallbackImpl(); RecordingManagerClass.CallStatic("setUnityRecordingCallback", recordingCallback); return SdkClass.CallStatic<bool>("initialize", CurrentActivity, preset, enableDebugLog); } catch (Exception e) { Debug.LogError($"[SausageReplaySDK] Failed to initialize Android SDK: {e.Message}"); return false; } }
        private static bool SausageReplaySDK_IsPlatformSupported() { try { return SdkClass.CallStatic<bool>("isPlatformSupported"); } catch (Exception e) { Debug.LogError($"Failed to check platform support: {e.Message}"); return false; } }
        private static string SausageReplaySDK_GetVersion() { try { return SdkClass.CallStatic<string>("getVersion"); } catch (Exception e) { Debug.LogError($"Failed to get version: {e.Message}"); return "1.0.0"; } }
        private static bool SausageReplaySDK_StartRecording() { try { return RecordingManagerClass.CallStatic<bool>("startRecording", CurrentActivity); } catch (Exception e) { Debug.LogError($"Failed to start recording: {e.Message}"); return false; } }
        private static void SausageReplaySDK_StopRecording() { try { RecordingManagerClass.CallStatic("stopRecording"); } catch (Exception e) { Debug.LogError($"Failed to stop recording: {e.Message}"); } }
        private static int SausageReplaySDK_GetRecordingStatus() { try { return RecordingManagerClass.CallStatic<int>("getRecordingStatus"); } catch (Exception e) { Debug.LogError($"Failed to get recording status: {e.Message}"); return 0; } }
        private static string SausageReplaySDK_GetDetailedStatus() { try { return RecordingManagerClass.CallStatic<string>("getDetailedStatusJson"); } catch (Exception e) { Debug.LogError($"Failed to get detailed status: {e.Message}"); return "{}"; } }
        private static void SausageReplaySDK_Release() { try { SdkClass.CallStatic("release"); _sdkClass?.Dispose(); _recordingManagerClass?.Dispose(); _permissionManagerClass?.Dispose(); _currentActivity?.Dispose(); _sdkClass = null; _recordingManagerClass = null; _permissionManagerClass = null; _currentActivity = null; } catch (Exception e) { Debug.LogError($"Failed to release SDK: {e.Message}"); } }
#else
        private static bool SausageReplaySDK_Initialize(int preset, bool enableDebugLog) => false;
        private static bool SausageReplaySDK_IsPlatformSupported() => false;
        private static string SausageReplaySDK_GetVersion() => "1.0.0";
        private static bool SausageReplaySDK_StartRecording() => false;
        private static void SausageReplaySDK_StopRecording() { }
        private static int SausageReplaySDK_GetRecordingStatus() => 0;
        private static string SausageReplaySDK_GetDetailedStatus() => "{}";
        private static void SausageReplaySDK_Release() { }
#endif

        #endregion

        #region 回调处理

        [AOT.MonoPInvokeCallback(typeof(Action))]
        private static void OnRecordingStartedCallback()
        {
            UnityMainThreadDispatcher.Enqueue(() => { _recordingCallback?.OnRecordingStarted(); OnRecordingStarted?.Invoke(); });
        }

        [AOT.MonoPInvokeCallback(typeof(Action<long, long>))]
        private static void OnRecordingProgressCallback(long durationMs, long fileSizeBytes)
        {
            UnityMainThreadDispatcher.Enqueue(() => { _recordingCallback?.OnRecordingProgress(durationMs, fileSizeBytes); OnRecordingProgress?.Invoke(durationMs, fileSizeBytes); });
        }

        [AOT.MonoPInvokeCallback(typeof(Action<string>))]
        private static void OnRecordingStoppedCallback(string resultJson)
        {
            UnityMainThreadDispatcher.Enqueue(() =>
            {
                try { RecordingResult result = JsonUtility.FromJson<RecordingResult>(resultJson); _recordingCallback?.OnRecordingStopped(result); OnRecordingStopped?.Invoke(result); }
                catch (Exception e) { Debug.LogError($"Exception parsing recording result: {e.Message}"); }
            });
        }

        [AOT.MonoPInvokeCallback(typeof(Action<int, string>))]
        private static void OnRecordingErrorCallback(int errorCode, string errorMessage)
        {
            UnityMainThreadDispatcher.Enqueue(() => { _recordingCallback?.OnRecordingError(errorCode, errorMessage); OnRecordingError?.Invoke(errorCode, errorMessage); });
        }

        #endregion
    }

    public class UnityRecordingCallbackImpl : AndroidJavaProxy
    {
        public UnityRecordingCallbackImpl() : base("com.funny.replaysdk.UnityRecordingCallback") { }
        public void onRecordingStarted() { UnityMainThreadDispatcher.Enqueue(() => { SausageReplaySDK.TriggerOnRecordingStarted(); }); }
        public void onRecordingProgress(long durationMs, long fileSizeBytes) { UnityMainThreadDispatcher.Enqueue(() => { SausageReplaySDK.TriggerOnRecordingProgress(durationMs, fileSizeBytes); }); }
        public void onRecordingStopped(bool success, string filePath, long fileSize, float duration, string fileMd5, int errorCode, string errorMessage)
        {
            UnityMainThreadDispatcher.Enqueue(() => {
                var result = new SausageReplaySDK.RecordingResult { isSuccess = success, filePath = filePath, fileSize = fileSize, duration = duration, fileMd5 = fileMd5, errorCode = errorCode, errorMessage = errorMessage };
                SausageReplaySDK.TriggerOnRecordingStopped(result);
            });
        }
        public void onRecordingError(int errorCode, string errorMessage) { UnityMainThreadDispatcher.Enqueue(() => { SausageReplaySDK.TriggerOnRecordingError(errorCode, errorMessage); }); }
    }
}


