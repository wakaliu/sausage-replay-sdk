using System;
using UnityEngine;

namespace SausageReplay
{
    /// <summary>
    /// Sausage Replay SDK 权限管理器
    /// 处理Android权限请求
    /// </summary>
    public static class SausageReplayPermissionManager
    {
        #region 权限相关常量

        private const string RECORD_AUDIO_PERMISSION = "android.permission.RECORD_AUDIO";
        private const string WRITE_EXTERNAL_STORAGE_PERMISSION = "android.permission.WRITE_EXTERNAL_STORAGE";
        private const string READ_EXTERNAL_STORAGE_PERMISSION = "android.permission.READ_EXTERNAL_STORAGE";

        #endregion

        #region 权限检查

        /// <summary>
        /// 检查麦克风权限
        /// </summary>
        /// <returns>是否已授予</returns>
        public static bool HasMicrophonePermission()
        {
            if (Application.platform != RuntimePlatform.Android)
            {
                return true; // 非Android平台默认返回true
            }

            try
            {
                return SausageReplayPermissionManager_HasMicrophonePermission();
            }
            catch (Exception e)
            {
                Debug.LogError($"Exception checking microphone permission: {e.Message}");
                return false;
            }
        }

        /// <summary>
        /// 检查存储权限
        /// </summary>
        /// <returns>是否已授予</returns>
        public static bool HasStoragePermission()
        {
            if (Application.platform != RuntimePlatform.Android)
            {
                return true; // 非Android平台默认返回true
            }

            try
            {
                return SausageReplayPermissionManager_HasStoragePermission();
            }
            catch (Exception e)
            {
                Debug.LogError($"Exception checking storage permission: {e.Message}");
                return false;
            }
        }

        /// <summary>
        /// 检查所有必需权限
        /// </summary>
        /// <returns>是否已授予所有权限</returns>
        public static bool HasAllRequiredPermissions()
        {
            return HasMicrophonePermission() && HasStoragePermission();
        }

        #endregion

        #region 权限请求

        /// <summary>
        /// 请求麦克风权限
        /// </summary>
        /// <param name="callback">权限请求结果回调</param>
        public static void RequestMicrophonePermission(Action<bool, int, string> callback)
        {
            if (Application.platform != RuntimePlatform.Android)
            {
                callback?.Invoke(true, 0, null);
                return;
            }

            try
            {
                SausageReplayPermissionManager_RequestMicrophonePermission(callback);
            }
            catch (Exception e)
            {
                Debug.LogError($"Exception requesting microphone permission: {e.Message}");
                callback?.Invoke(false, 1001, e.Message);
            }
        }

        /// <summary>
        /// 请求存储权限
        /// </summary>
        /// <param name="callback">权限请求结果回调</param>
        public static void RequestStoragePermission(Action<bool, int, string> callback)
        {
            if (Application.platform != RuntimePlatform.Android)
            {
                callback?.Invoke(true, 0, null);
                return;
            }

            try
            {
                SausageReplayPermissionManager_RequestStoragePermission(callback);
            }
            catch (Exception e)
            {
                Debug.LogError($"Exception requesting storage permission: {e.Message}");
                callback?.Invoke(false, 1002, e.Message);
            }
        }

        /// <summary>
        /// 请求所有必需权限
        /// </summary>
        /// <param name="callback">权限请求结果回调</param>
        public static void RequestAllRequiredPermissions(Action<bool, int, string> callback)
        {
            if (Application.platform != RuntimePlatform.Android)
            {
                callback?.Invoke(true, 0, null);
                return;
            }

            try
            {
                SausageReplayPermissionManager_RequestAllRequiredPermissions(callback);
            }
            catch (Exception e)
            {
                Debug.LogError($"Exception requesting all permissions: {e.Message}");
                callback?.Invoke(false, 1000, e.Message);
            }
        }

        /// <summary>
        /// 请求屏幕录制权限
        /// </summary>
        /// <param name="callback">权限请求结果回调</param>
        public static void RequestScreenCapturePermission(Action<bool, int, string> callback)
        {
            if (Application.platform != RuntimePlatform.Android)
            {
                callback?.Invoke(true, 0, null);
                return;
            }

            try
            {
                SausageReplayPermissionManager_RequestScreenCapturePermission(callback);
            }
            catch (Exception e)
            {
                Debug.LogError($"Exception requesting screen capture permission: {e.Message}");
                callback?.Invoke(false, 1003, e.Message);
            }
        }

        #endregion

        #region 权限状态查询

        /// <summary>
        /// 获取权限状态描述
        /// </summary>
        /// <returns>权限状态描述</returns>
        public static string GetPermissionStatusDescription()
        {
            bool micPermission = HasMicrophonePermission();
            bool storagePermission = HasStoragePermission();

            string status = "权限状态:\n";
            status += $"麦克风权限: {(micPermission ? "已授予" : "未授予")}\n";
            status += $"存储权限: {(storagePermission ? "已授予" : "未授予")}";

            return status;
        }

        /// <summary>
        /// 检查是否需要显示权限说明
        /// </summary>
        /// <returns>是否需要显示说明</returns>
        public static bool ShouldShowPermissionRationale()
        {
            if (Application.platform != RuntimePlatform.Android)
            {
                return false;
            }

            try
            {
                return SausageReplayPermissionManager_ShouldShowPermissionRationale();
            }
            catch (Exception e)
            {
                Debug.LogError($"Exception checking permission rationale: {e.Message}");
                return false;
            }
        }

        #endregion

        #region 设置跳转

        /// <summary>
        /// 跳转到应用设置页面
        /// </summary>
        public static void OpenAppSettings()
        {
            if (Application.platform != RuntimePlatform.Android)
            {
                Debug.LogWarning("OpenAppSettings only supported on Android");
                return;
            }

            try
            {
                SausageReplayPermissionManager_OpenAppSettings();
            }
            catch (Exception e)
            {
                Debug.LogError($"Exception opening app settings: {e.Message}");
            }
        }

        #endregion

        #region JNI 调用

#if UNITY_ANDROID && !UNITY_EDITOR
        private static AndroidJavaObject _currentActivity;

        private static AndroidJavaObject CurrentActivity
        {
            get
            {
                if (_currentActivity == null)
                {
                    using (AndroidJavaClass unityPlayer = new AndroidJavaClass("com.unity3d.player.UnityPlayer"))
                    {
                        _currentActivity = unityPlayer.GetStatic<AndroidJavaObject>("currentActivity");
                    }
                }
                return _currentActivity;
            }
        }

        private static bool SausageReplayPermissionManager_HasMicrophonePermission()
        {
            try
            {
                return UnityEngine.Android.Permission.HasUserAuthorizedPermission(RECORD_AUDIO_PERMISSION);
            }
            catch (Exception e)
            {
                Debug.LogError($"HasMicrophonePermission error: {e.Message}");
                return false;
            }
        }

        private static bool SausageReplayPermissionManager_HasStoragePermission()
        {
            try
            {
                bool hasRead = UnityEngine.Android.Permission.HasUserAuthorizedPermission(READ_EXTERNAL_STORAGE_PERMISSION);
                bool hasWrite = UnityEngine.Android.Permission.HasUserAuthorizedPermission(WRITE_EXTERNAL_STORAGE_PERMISSION);
                return hasRead && hasWrite;
            }
            catch (Exception e)
            {
                Debug.LogError($"HasStoragePermission error: {e.Message}");
                return false;
            }
        }

        private static void SausageReplayPermissionManager_RequestMicrophonePermission(Action<bool, int, string> callback)
        {
            try
            {
                if (UnityEngine.Android.Permission.HasUserAuthorizedPermission(RECORD_AUDIO_PERMISSION))
                {
                    callback?.Invoke(true, 0, null);
                    return;
                }

                UnityEngine.Android.Permission.RequestUserPermission(RECORD_AUDIO_PERMISSION);
                PermissionRequestRunner.RunUntil(() => UnityEngine.Android.Permission.HasUserAuthorizedPermission(RECORD_AUDIO_PERMISSION),
                    success => { callback?.Invoke(success, success ? 0 : 1001, success ? null : "PermissionDenied"); });
            }
            catch (Exception e)
            {
                Debug.LogError($"RequestMicrophonePermission error: {e.Message}");
                callback?.Invoke(false, 1001, e.Message);
            }
        }

        private static void SausageReplayPermissionManager_RequestStoragePermission(Action<bool, int, string> callback)
        {
            try
            {
                if (SausageReplayPermissionManager_HasStoragePermission())
                {
                    callback?.Invoke(true, 0, null);
                    return;
                }

                UnityEngine.Android.Permission.RequestUserPermission(READ_EXTERNAL_STORAGE_PERMISSION);
                UnityEngine.Android.Permission.RequestUserPermission(WRITE_EXTERNAL_STORAGE_PERMISSION);
                PermissionRequestRunner.RunUntil(() => SausageReplayPermissionManager_HasStoragePermission(),
                    success => { callback?.Invoke(success, success ? 0 : 1002, success ? null : "PermissionDenied"); });
            }
            catch (Exception e)
            {
                Debug.LogError($"RequestStoragePermission error: {e.Message}");
                callback?.Invoke(false, 1002, e.Message);
            }
        }

        private static void SausageReplayPermissionManager_RequestAllRequiredPermissions(Action<bool, int, string> callback)
        {
            try
            {
                SausageReplayPermissionManager_RequestMicrophonePermission((micOk, micCode, micMsg) =>
                {
                    if (!micOk)
                    {
                        callback?.Invoke(false, micCode, micMsg);
                        return;
                    }
                    SausageReplayPermissionManager_RequestStoragePermission((stOk, stCode, stMsg) =>
                    {
                        callback?.Invoke(stOk, stCode, stMsg);
                    });
                });
            }
            catch (Exception e)
            {
                Debug.LogError($"RequestAllRequiredPermissions error: {e.Message}");
                callback?.Invoke(false, 1000, e.Message);
            }
        }

        private static void SausageReplayPermissionManager_RequestScreenCapturePermission(Action<bool, int, string> callback)
        {
            // 屏幕录制权限通过系统对话框授权，Unity侧无法直接触发，只返回占位结果
            callback?.Invoke(true, 0, null);
        }

        private static bool SausageReplayPermissionManager_ShouldShowPermissionRationale()
        {
            try
            {
                using (AndroidJavaClass activityCompat = new AndroidJavaClass("androidx.core.app.ActivityCompat"))
                {
                    bool mic = activityCompat.CallStatic<bool>("shouldShowRequestPermissionRationale", CurrentActivity, RECORD_AUDIO_PERMISSION);
                    bool read = activityCompat.CallStatic<bool>("shouldShowRequestPermissionRationale", CurrentActivity, READ_EXTERNAL_STORAGE_PERMISSION);
                    bool write = activityCompat.CallStatic<bool>("shouldShowRequestPermissionRationale", CurrentActivity, WRITE_EXTERNAL_STORAGE_PERMISSION);
                    return mic || read || write;
                }
            }
            catch (Exception e)
            {
                Debug.LogError($"ShouldShowPermissionRationale error: {e.Message}");
                return false;
            }
        }

        private static void SausageReplayPermissionManager_OpenAppSettings()
        {
            try
            {
                using (AndroidJavaClass uriClass = new AndroidJavaClass("android.net.Uri"))
                using (AndroidJavaObject intent = new AndroidJavaObject("android.content.Intent", "android.settings.APPLICATION_DETAILS_SETTINGS"))
                {
                    string pkg = CurrentActivity.Call<string>("getPackageName");
                    using (AndroidJavaObject uri = uriClass.CallStatic<AndroidJavaObject>("parse", "package:" + pkg))
                    {
                        intent.Call<AndroidJavaObject>("setData", uri);
                        intent.Call<AndroidJavaObject>("addFlags", 0x10000000); // FLAG_ACTIVITY_NEW_TASK
                        CurrentActivity.Call("startActivity", intent);
                    }
                }
            }
            catch (Exception e)
            {
                Debug.LogError($"OpenAppSettings error: {e.Message}");
            }
        }
#else
        // Editor 模式下的模拟实现
        private static bool SausageReplayPermissionManager_HasMicrophonePermission() => true;
        private static bool SausageReplayPermissionManager_HasStoragePermission() => true;
        private static void SausageReplayPermissionManager_RequestMicrophonePermission(Action<bool, int, string> callback) 
        {
            callback?.Invoke(true, 0, null);
        }
        private static void SausageReplayPermissionManager_RequestStoragePermission(Action<bool, int, string> callback) 
        {
            callback?.Invoke(true, 0, null);
        }
        private static void SausageReplayPermissionManager_RequestAllRequiredPermissions(Action<bool, int, string> callback) 
        {
            callback?.Invoke(true, 0, null);
        }
        private static void SausageReplayPermissionManager_RequestScreenCapturePermission(Action<bool, int, string> callback) 
        {
            callback?.Invoke(true, 0, null);
        }
        private static bool SausageReplayPermissionManager_ShouldShowPermissionRationale() => false;
        private static void SausageReplayPermissionManager_OpenAppSettings() { }
#endif

        #endregion

        #region 回调处理

        /// <summary>
        /// 处理权限请求结果回调
        /// </summary>
        [AOT.MonoPInvokeCallback(typeof(Action<bool, int, string>))]
        private static void OnPermissionResultCallback(bool granted, int errorCode, string errorMessage)
        {
            UnityMainThreadDispatcher.Enqueue(() =>
            {
                // 这里可以添加全局权限结果处理逻辑
                Debug.Log($"Permission result: granted={granted}, errorCode={errorCode}, message={errorMessage}");
            });
        }

        #endregion
    }
}
