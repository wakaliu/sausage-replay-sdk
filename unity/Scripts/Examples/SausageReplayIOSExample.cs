using System;
using UnityEngine;
using SausageReplay;

namespace SausageReplay.Examples
{
    /// <summary>
    /// iOS平台Sausage Replay SDK使用示例
    /// 展示如何在iOS平台上使用屏幕录制功能
    /// </summary>
    public class SausageReplayIOSExample : MonoBehaviour
    {
        [Header("录制配置")]
        [SerializeField] private SausageReplaySDK.VideoQualityPreset qualityPreset = SausageReplaySDK.VideoQualityPreset.Standard;
        [SerializeField] private bool includeAudio = true;
        [SerializeField] private int maxDurationSeconds = 60;
        
        [Header("UI控制")]
        [SerializeField] private UnityEngine.UI.Button initButton;
        [SerializeField] private UnityEngine.UI.Button startButton;
        [SerializeField] private UnityEngine.UI.Button stopButton;
        [SerializeField] private UnityEngine.UI.Button pauseButton;
        [SerializeField] private UnityEngine.UI.Button resumeButton;
        [SerializeField] private UnityEngine.UI.Button permissionButton;
        [SerializeField] private UnityEngine.UI.Text statusText;
        [SerializeField] private UnityEngine.UI.Text logText;
        
        private bool isInitialized = false;
        private bool isRecording = false;
        private bool isPaused = false;
        
        private void Start()
        {
            SetupUI();
            RegisterCallbacks();
            UpdateUI();
        }
        
        private void OnDestroy()
        {
            UnregisterCallbacks();
        }
        
        #region UI设置
        
        private void SetupUI()
        {
            if (initButton != null)
                initButton.onClick.AddListener(OnInitButtonClicked);
                
            if (startButton != null)
                startButton.onClick.AddListener(OnStartButtonClicked);
                
            if (stopButton != null)
                stopButton.onClick.AddListener(OnStopButtonClicked);
                
            if (pauseButton != null)
                pauseButton.onClick.AddListener(OnPauseButtonClicked);
                
            if (resumeButton != null)
                resumeButton.onClick.AddListener(OnResumeButtonClicked);
                
            if (permissionButton != null)
                permissionButton.onClick.AddListener(OnPermissionButtonClicked);
        }
        
        private void UpdateUI()
        {
            if (initButton != null)
                initButton.interactable = !isInitialized;
                
            if (startButton != null)
                startButton.interactable = isInitialized && !isRecording;
                
            if (stopButton != null)
                stopButton.interactable = isRecording;
                
            if (pauseButton != null)
                pauseButton.interactable = isRecording && !isPaused;
                
            if (resumeButton != null)
                resumeButton.interactable = isRecording && isPaused;
                
            if (permissionButton != null)
                permissionButton.interactable = isInitialized;
                
            UpdateStatusText();
        }
        
        private void UpdateStatusText()
        {
            if (statusText == null) return;
            
            string status = "未初始化";
            if (isInitialized)
            {
                if (isRecording)
                {
                    status = isPaused ? "录制中 (已暂停)" : "录制中";
                }
                else
                {
                    status = "就绪";
                }
            }
            
            statusText.text = $"状态: {status}";
        }
        
        #endregion
        
        #region 事件回调
        
        private void RegisterCallbacks()
        {
            SausageReplaySDK.OnRecordingStarted += OnRecordingStarted;
            SausageReplaySDK.OnRecordingProgress += OnRecordingProgress;
            SausageReplaySDK.OnRecordingPaused += OnRecordingPaused;
            SausageReplaySDK.OnRecordingResumed += OnRecordingResumed;
            SausageReplaySDK.OnRecordingStopped += OnRecordingStopped;
            SausageReplaySDK.OnRecordingError += OnRecordingError;
            SausageReplaySDK.OnRecordingQualityAdjusted += OnRecordingQualityAdjusted;
            SausageReplaySDK.OnConvertCompleted += OnConvertCompleted;
        }
        
        private void UnregisterCallbacks()
        {
            SausageReplaySDK.OnRecordingStarted -= OnRecordingStarted;
            SausageReplaySDK.OnRecordingProgress -= OnRecordingProgress;
            SausageReplaySDK.OnRecordingPaused -= OnRecordingPaused;
            SausageReplaySDK.OnRecordingResumed -= OnRecordingResumed;
            SausageReplaySDK.OnRecordingStopped -= OnRecordingStopped;
            SausageReplaySDK.OnRecordingError -= OnRecordingError;
            SausageReplaySDK.OnRecordingQualityAdjusted -= OnRecordingQualityAdjusted;
            SausageReplaySDK.OnConvertCompleted -= OnConvertCompleted;
        }
        
        private void OnRecordingStarted()
        {
            AddLog("✅ 录制开始");
            isRecording = true;
            isPaused = false;
            UpdateUI();
        }
        
        private void OnRecordingProgress(long durationMs, long fileSizeBytes)
        {
            // 每秒更新一次进度
            static long lastUpdateTime = 0;
            long currentTime = durationMs / 1000;
            if (currentTime > lastUpdateTime)
            {
                lastUpdateTime = currentTime;
                AddLog($"📊 录制进度: {currentTime}秒, 估算文件大小: {fileSizeBytes / 1024.0 / 1024.0:F2} MB");
            }
        }
        
        private void OnRecordingPaused()
        {
            AddLog("⏸️ 录制暂停");
            isPaused = true;
            UpdateUI();
        }
        
        private void OnRecordingResumed()
        {
            AddLog("▶️ 录制恢复");
            isPaused = false;
            UpdateUI();
        }
        
        private void OnRecordingStopped(RecordingResult result)
        {
            if (result.IsSuccess)
            {
                AddLog($"✅ 录制完成");
                AddLog($"📁 文件路径: {result.FilePath}");
                AddLog($"📊 文件大小: {result.FileSize / 1024.0 / 1024.0:F2} MB");
                AddLog($"⏱️ 录制时长: {result.Duration:F1} 秒");
                AddLog("💡 在iOS上，录制的视频会通过系统预览界面保存到相册");
            }
            else
            {
                AddLog($"❌ 录制失败: {result.ErrorMessage}");
            }
            
            isRecording = false;
            isPaused = false;
            UpdateUI();
        }
        
        private void OnRecordingError(int errorCode, string errorMessage)
        {
            AddLog($"❌ 录制错误: {errorCode} - {errorMessage}");
            
            // 根据错误码处理
            switch (errorCode)
            {
                case 2000:
                    AddLog("💡 录制已在进行中，请等待完成");
                    break;
                case 2001:
                    AddLog("💡 请先开始录制");
                    break;
                case 2003:
                    AddLog("💡 设备不支持屏幕录制");
                    break;
                case 2004:
                    AddLog("💡 录制失败，请检查权限和配置");
                    break;
                default:
                    AddLog("💡 未知错误，请查看详细日志");
                    break;
            }
        }
        
        private void OnRecordingQualityAdjusted(SausageReplaySDK.VideoQuality quality)
        {
            AddLog($"🎯 质量已调整: {quality}");
        }
        
        private void OnConvertCompleted(bool success, string outputPath)
        {
            if (success)
            {
                AddLog($"✅ 格式转换完成: {outputPath}");
            }
            else
            {
                AddLog("❌ 格式转换失败");
            }
        }
        
        #endregion
        
        #region 按钮事件
        
        private void OnInitButtonClicked()
        {
            AddLog($"🚀 初始化SDK，使用清晰度档位: {qualityPreset}");
            
            bool success = SausageReplaySDK.Initialize(qualityPreset);
            if (success)
            {
                isInitialized = true;
                AddLog("✅ SDK初始化成功");
                
                // 获取设备信息
                var deviceInfo = SausageReplaySDK.GetDeviceTierInfo();
                AddLog($"📱 设备档位: {deviceInfo.TierName}");
                AddLog($"📐 最大分辨率: {deviceInfo.MaxWidth}x{deviceInfo.MaxHeight}");
                AddLog($"🎬 目标帧率: {deviceInfo.TargetFps}");
                AddLog($"📊 视频比特率: {deviceInfo.VideoBitrate}");
                AddLog($"🎞️ GIF支持: {(deviceInfo.GifSupported ? "是" : "否")}");
                
                // 检查权限
                bool hasPermission = SausageReplaySDK.HasMicrophonePermission();
                AddLog($"🎤 麦克风权限: {(hasPermission ? "已授权" : "未授权")}");
            }
            else
            {
                AddLog("❌ SDK初始化失败");
            }
            
            UpdateUI();
        }
        
        private void OnStartButtonClicked()
        {
            if (!isInitialized)
            {
                AddLog("❌ 请先初始化SDK");
                return;
            }
            
            AddLog($"🎬 开始录制 - 清晰度档位: {qualityPreset}, 时长: {maxDurationSeconds}秒, 音频: {(includeAudio ? "是" : "否")}");
            
            var config = new RecordingConfig
            {
                QualityPreset = qualityPreset,
                IncludeAudio = includeAudio,
                MaxDurationSeconds = maxDurationSeconds,
                OutputFormat = SausageReplaySDK.OutputFormat.MP4
            };
            
            bool success = SausageReplaySDK.StartRecording(config);
            if (success)
            {
                AddLog("✅ 录制开始请求已发送");
            }
            else
            {
                AddLog("❌ 录制开始失败");
            }
        }
        
        private void OnStopButtonClicked()
        {
            if (!isRecording)
            {
                AddLog("❌ 当前没有录制进行中");
                return;
            }
            
            AddLog("🛑 停止录制");
            SausageReplaySDK.StopRecording();
        }
        
        private void OnPauseButtonClicked()
        {
            if (!isRecording || isPaused)
            {
                AddLog("❌ 无法暂停录制");
                return;
            }
            
            AddLog("⏸️ 暂停录制");
            bool success = SausageReplaySDK.PauseRecording();
            if (!success)
            {
                AddLog("❌ 暂停录制失败");
            }
        }
        
        private void OnResumeButtonClicked()
        {
            if (!isRecording || !isPaused)
            {
                AddLog("❌ 无法恢复录制");
                return;
            }
            
            AddLog("▶️ 恢复录制");
            bool success = SausageReplaySDK.ResumeRecording();
            if (!success)
            {
                AddLog("❌ 恢复录制失败");
            }
        }
        
        private void OnPermissionButtonClicked()
        {
            if (!isInitialized)
            {
                AddLog("❌ 请先初始化SDK");
                return;
            }
            
            AddLog("🔐 请求麦克风权限");
            SausageReplaySDK.RequestMicrophonePermission((granted) =>
            {
                if (granted)
                {
                    AddLog("✅ 麦克风权限已授权");
                }
                else
                {
                    AddLog("❌ 麦克风权限被拒绝");
                    AddLog("💡 请在系统设置中手动开启麦克风权限");
                }
            });
        }
        
        #endregion
        
        #region 工具方法
        
        private void AddLog(string message)
        {
            if (logText == null) return;
            
            string timestamp = DateTime.Now.ToString("HH:mm:ss");
            string logMessage = $"[{timestamp}] {message}\n";
            
            logText.text += logMessage;
            
            // 限制日志长度
            if (logText.text.Length > 10000)
            {
                logText.text = logText.text.Substring(5000);
            }
            
            // 滚动到底部
            var rectTransform = logText.GetComponent<RectTransform>();
            if (rectTransform != null)
            {
                rectTransform.anchoredPosition = new Vector2(0, 0);
            }
            
            Debug.Log($"[SausageReplayIOSExample] {message}");
        }
        
        #endregion
        
        #region 公共方法
        
        /// <summary>
        /// 设置视频清晰度档位
        /// </summary>
        public void SetQualityPreset(SausageReplaySDK.VideoQualityPreset preset)
        {
            if (isRecording)
            {
                AddLog("❌ 录制进行中，无法更改清晰度档位");
                return;
            }
            
            qualityPreset = preset;
            AddLog($"🎯 清晰度档位已设置为: {preset}");
            
            // 如果已初始化，重新初始化SDK
            if (isInitialized)
            {
                AddLog("🔄 重新初始化SDK以应用新的清晰度档位");
                isInitialized = false;
                UpdateUI();
                OnInitButtonClicked();
            }
        }
        
        /// <summary>
        /// 获取当前录制状态
        /// </summary>
        public bool IsRecording => isRecording;
        
        /// <summary>
        /// 获取当前暂停状态
        /// </summary>
        public bool IsPaused => isPaused;
        
        /// <summary>
        /// 获取当前初始化状态
        /// </summary>
        public bool IsInitialized => isInitialized;
        
        #endregion
    }
}
