using System;
using UnityEngine;

namespace SausageReplay.Examples
{
	/// <summary>
	/// 零UI的快速接入示例
	/// - 自动请求必要权限
	/// - 初始化SDK
	/// - 构建并启动录制（可按键控制）
	/// - 打印所有回调日志
	/// 挂到任意场景对象即可运行
	/// </summary>
	public class SausageReplayExample : MonoBehaviour, SausageReplay.IRecordingCallback
	{
		[Header("录制配置")]
		public SausageReplay.DevicePerformanceTier deviceTier = SausageReplay.DevicePerformanceTier.MID_RANGE;
		public SausageReplay.VideoQuality initialQuality = SausageReplay.VideoQuality.MEDIUM;
		public int maxDurationSeconds = 60;
		public bool includeAudio = true;

		private SausageReplay.RecordingConfig _recordingConfig;
		private bool _isInitialized = false;
		private string _lastRecordedFilePath = null;

		private void Start()
		{
			RequestPermissionsAndInit();
		}

		private void Update()
		{
			// 键盘控制（Editor/Android都可用于快速验证）
			// R：开始录制；S：停止录制；P：暂停；C：恢复；Q：切换质量（高/中/低循环）
			if (Input.GetKeyDown(KeyCode.R)) SafeStartRecording();
			if (Input.GetKeyDown(KeyCode.S)) SafeStopRecording();
			if (Input.GetKeyDown(KeyCode.P)) SafePauseRecording();
			if (Input.GetKeyDown(KeyCode.C)) SafeResumeRecording();
			if (Input.GetKeyDown(KeyCode.Q)) CycleQuality();
		}

		private void RequestPermissionsAndInit()
		{
			Debug.Log("[SausageReplay] 请求权限...");
			SausageReplay.SausageReplayPermissionManager.RequestAllRequiredPermissions((granted, errorCode, errorMessage) =>
			{
				if (!granted)
				{
					Debug.LogError($"[SausageReplay] 权限请求失败: {errorCode} - {errorMessage}");
					return;
				}

				Debug.Log("[SausageReplay] 权限已授予，初始化SDK...");
				bool success = SausageReplay.SausageReplaySDK.Initialize(deviceTier);
				if (!success)
				{
					Debug.LogError("[SausageReplay] SDK初始化失败");
					return;
				}

				_isInitialized = true;
				CreateRecordingConfig();
				Debug.Log("[SausageReplay] SDK初始化成功");
				// 初始化完毕后可自动开始录制（按需打开）
				// SafeStartRecording();
			});
		}

		private void CreateRecordingConfig()
		{
			_recordingConfig = new SausageReplay.RecordingConfig
			{
				quality = initialQuality,
				maxDurationSeconds = maxDurationSeconds,
				includeAudio = includeAudio,
				outputFormat = SausageReplay.OutputFormat.MP4,
				performanceTier = deviceTier
			};
		}

		// ========== 快速控制API ==========
		public void SafeStartRecording()
		{
			if (!_isInitialized)
			{
				Debug.LogWarning("[SausageReplay] SDK未初始化，无法开始录制");
				return;
			}
			Debug.Log("[SausageReplay] 开始录制...");
			bool ok = SausageReplay.SausageReplaySDK.StartRecording(_recordingConfig, this);
			if (!ok) Debug.LogError("[SausageReplay] 录制启动失败");
		}

		public void SafeStopRecording()
		{
			if (!_isInitialized) { Debug.LogWarning("[SausageReplay] SDK未初始化"); return; }
			Debug.Log("[SausageReplay] 停止录制...");
			SausageReplay.SausageReplaySDK.StopRecording();
		}

		public void SafePauseRecording()
		{
			if (!_isInitialized) { Debug.LogWarning("[SausageReplay] SDK未初始化"); return; }
			Debug.Log("[SausageReplay] 暂停录制...");
			if (!SausageReplay.SausageReplaySDK.PauseRecording())
				Debug.LogError("[SausageReplay] 暂停失败");
		}

		public void SafeResumeRecording()
		{
			if (!_isInitialized) { Debug.LogWarning("[SausageReplay] SDK未初始化"); return; }
			Debug.Log("[SausageReplay] 恢复录制...");
			if (!SausageReplay.SausageReplaySDK.ResumeRecording())
				Debug.LogError("[SausageReplay] 恢复失败");
		}

		private void CycleQuality()
		{
			if (!_isInitialized) { Debug.LogWarning("[SausageReplay] SDK未初始化"); return; }
			var next = initialQuality == SausageReplay.VideoQuality.LOW
				? SausageReplay.VideoQuality.MEDIUM
				: (initialQuality == SausageReplay.VideoQuality.MEDIUM
					? SausageReplay.VideoQuality.HIGH
					: SausageReplay.VideoQuality.LOW);

			initialQuality = next;
			Debug.Log($"[SausageReplay] 切换目标质量: {next}");
			if (!SausageReplay.SausageReplaySDK.AdjustRecordingQuality(next))
				Debug.LogError("[SausageReplay] 质量调整失败");
		}

		// ========== 录制回调 ==========
		public void OnRecordingStarted()
		{
			Debug.Log("[SausageReplay] 录制已开始");
		}

		public void OnRecordingProgress(long durationMs, long fileSizeBytes)
		{
			var sec = durationMs / 1000f;
			var mb = fileSizeBytes / (1024f * 1024f);
			Debug.Log($"[SausageReplay] 进度: {sec:F1}s, 大小: {mb:F2}MB");
		}

		public void OnRecordingPaused()
		{
			Debug.Log("[SausageReplay] 录制已暂停");
		}

		public void OnRecordingResumed()
		{
			Debug.Log("[SausageReplay] 录制已恢复");
		}

		public void OnRecordingStopped(SausageReplay.RecordingResult result)
		{
			Debug.Log($"[SausageReplay] 录制已停止: {JsonUtility.ToJson(result)}");
			if (result.isSuccess)
			{
				_lastRecordedFilePath = result.filePath;
				Debug.Log($"[SausageReplay] 文件: {_lastRecordedFilePath}");
			}
		}

		public void OnRecordingError(int errorCode, string errorMessage)
		{
			Debug.LogError($"[SausageReplay] 录制错误: {errorCode} - {errorMessage}");
		}

		public void OnRecordingQualityAdjusted(SausageReplay.VideoQuality quality)
		{
			Debug.Log($"[SausageReplay] 录制质量已调整到: {quality}");
		}

		private void OnDestroy()
		{
			if (_isInitialized)
			{
				SausageReplay.SausageReplaySDK.Release();
			}
		}
	}
}
