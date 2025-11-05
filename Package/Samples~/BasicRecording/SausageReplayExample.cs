using System;
using UnityEngine;

namespace SausageReplay.Examples
{
    public class SausageReplayExample : MonoBehaviour, SausageReplay.IRecordingCallback
    {
        [Header("录制配置")] public SausageReplay.VideoQualityPreset videoPreset = SausageReplay.VideoQualityPreset.Standard;
        public bool enableDebugLog = true;
        private bool _isInitialized = false; private string _lastRecordedFilePath = null;
        private void Start() { RequestPermissionsAndInit(); }
        private void Update() { if (Input.GetKeyDown(KeyCode.R)) SafeStartRecording(); if (Input.GetKeyDown(KeyCode.S)) SafeStopRecording(); }
        private void RequestPermissionsAndInit()
        {
            Debug.Log("[SausageReplay] 请求权限...");
            SausageReplay.SausageReplayPermissionManager.RequestAllRequiredPermissions((granted, errorCode, errorMessage) =>
            {
                if (!granted) { Debug.LogError($"[SausageReplay] 权限请求失败: {errorCode} - {errorMessage}"); return; }
                Debug.Log("[SausageReplay] 权限已授予，初始化SDK...");
                bool success = SausageReplay.SausageReplaySDK.Initialize(videoPreset, enableDebugLog);
                if (!success) { Debug.LogError("[SausageReplay] SDK初始化失败"); return; }
                _isInitialized = true; Debug.Log("[SausageReplay] SDK初始化成功");
            });
        }
        public void SafeStartRecording()
        {
            if (!_isInitialized) { Debug.LogWarning("[SausageReplay] SDK未初始化，无法开始录制"); return; }
            Debug.Log("[SausageReplay] 开始录制...");
            bool ok = SausageReplay.SausageReplaySDK.StartRecording(this);
            if (!ok) Debug.LogError("[SausageReplay] 录制启动失败");
        }
        public void SafeStopRecording()
        {
            if (!_isInitialized) { Debug.LogWarning("[SausageReplay] SDK未初始化"); return; }
            Debug.Log("[SausageReplay] 停止录制...");
            SausageReplay.SausageReplaySDK.StopRecording();
        }
        public void OnRecordingStarted() { Debug.Log("[SausageReplay] 录制已开始"); }
        public void OnRecordingProgress(long durationMs, long fileSizeBytes)
        {
            var sec = durationMs / 1000f; var mb = fileSizeBytes / (1024f * 1024f);
            Debug.Log($"[SausageReplay] 进度: {sec:F1}s, 大小: {mb:F2}MB");
        }
        public void OnRecordingStopped(SausageReplay.RecordingResult result)
        {
            Debug.Log($"[SausageReplay] 录制已停止: {JsonUtility.ToJson(result)}");
            if (result.isSuccess)
            {
                _lastRecordedFilePath = result.filePath;
                Debug.Log($"[SausageReplay] 文件: {_lastRecordedFilePath}");
                if (!string.IsNullOrEmpty(result.fileMd5)) Debug.Log($"[SausageReplay] 文件MD5: {result.fileMd5}");
#if UNITY_IOS && !UNITY_EDITOR
                if (!string.IsNullOrEmpty(result.assetLocalId)) Debug.Log($"[SausageReplay] 相册资源ID: {result.assetLocalId}");
#endif
            }
            else { Debug.LogError($"[SausageReplay] 录制失败 (错误码: {result.errorCode}): {result.errorMessage}"); }
        }
        public void OnRecordingError(int errorCode, string errorMessage) { Debug.LogError($"[SausageReplay] 录制错误: {errorCode} - {errorMessage}"); }
    }
}


