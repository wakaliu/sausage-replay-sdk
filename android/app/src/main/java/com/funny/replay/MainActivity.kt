package com.funny.replaysdk.sample

import android.os.Bundle
import android.widget.Toast
import androidx.appcompat.app.AppCompatActivity
import android.widget.Button
import android.widget.TextView
import com.funny.replaysdk.DevicePerformanceTier
import com.funny.replaysdk.PermissionManager
import com.funny.replaysdk.SausageReplayAndroidSDK
import com.funny.replaysdk.RecordingConfig
import com.funny.replaysdk.RecordingManager
import com.funny.replaysdk.RecordingStatus
import android.os.Environment
import android.net.Uri
import android.content.Intent
import androidx.core.content.FileProvider
import java.io.File
import android.os.Handler
import android.os.Looper
import android.app.ActivityManager
import android.os.Debug
import java.text.DecimalFormat
import android.view.Choreographer
import android.media.MediaPlayer
import android.media.AudioAttributes
import android.media.AudioManager
import android.media.ToneGenerator

class MainActivity : AppCompatActivity() {
    
    private lateinit var tvMemory: TextView
    private lateinit var tvFps: TextView
    private lateinit var tvStatus: TextView
    
    // 按钮引用
    private lateinit var btnStart: Button
    private lateinit var btnStop: Button
    private lateinit var btnPause: Button
    private lateinit var btnResume: Button
    private lateinit var btnQualityHigh: Button
    private lateinit var btnQualityMedium: Button
    private lateinit var btnQualityLow: Button
    
    // Toast管理
    private var progressToast: Toast? = null
    
    // 音频播放
    private var mediaPlayer: MediaPlayer? = null
    private var toneGenerator: ToneGenerator? = null
    private var isAudioPlaying = false
    
    private val performanceHandler = Handler(Looper.getMainLooper())
    private var frameCount = 0L
    private var lastFrameTime = System.currentTimeMillis()
    private val decimalFormat = DecimalFormat("#.#")
    private var choreographer: Choreographer? = null
    private val frameCallback = object : Choreographer.FrameCallback {
        override fun doFrame(frameTimeNanos: Long) {
            frameCount++
            choreographer?.postFrameCallback(this)
        }
    }
    
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_main)
        
        // 初始化性能监控UI
        tvMemory = findViewById(R.id.tv_memory)
        tvFps = findViewById(R.id.tv_fps)
        tvStatus = findViewById(R.id.tv_status)
        
        // 初始化按钮引用
        btnStart = findViewById(R.id.btn_start)
        btnStop = findViewById(R.id.btn_stop)
        btnPause = findViewById(R.id.btn_pause)
        btnResume = findViewById(R.id.btn_resume)
        btnQualityHigh = findViewById(R.id.btn_quality_high)
        btnQualityMedium = findViewById(R.id.btn_quality_medium)
        btnQualityLow = findViewById(R.id.btn_quality_low)
        
        // 初始化按钮状态
        updateButtonStates(com.funny.replaysdk.RecordingStatus.IDLE)
        
        SausageReplayAndroidSDK.initialize(this, DevicePerformanceTier.MID_RANGE)
        
        // 启动性能监控
        startPerformanceMonitoring()
        startFpsMonitoring()
        // 最小权限申请示例
        PermissionManager.requestMicrophonePermission(this) { granted, code, msg ->
            Toast.makeText(this, "Mic perm: $granted code=$code", Toast.LENGTH_SHORT).show()
        }

        btnStart.setOnClickListener {
            val callback = object : com.funny.replaysdk.RecordingCallback {
                override fun onRecordingStarted() {
                    runOnUiThread {
                        Toast.makeText(this@MainActivity, "录制已开始", Toast.LENGTH_SHORT).show()
                        updateRecordingStatus(com.funny.replaysdk.RecordingStatus.RECORDING)
                        updateButtonStates(com.funny.replaysdk.RecordingStatus.RECORDING)
                    }
                }
                override fun onRecordingProgress(durationMs: Long, fileSizeBytes: Long) {
                    runOnUiThread {
                        val durationSec = durationMs / 1000
                        val fileSizeMB = fileSizeBytes / (1024 * 1024)
                        // 只在录制中状态时显示进度Toast，避免停止后继续弹窗
                        val currentStatus = RecordingManager.getRecordingStatus()
                        android.util.Log.d("MainActivity", "onRecordingProgress: status=$currentStatus, duration=${durationSec}s, size=${fileSizeMB}MB")
                        if (currentStatus == com.funny.replaysdk.RecordingStatus.RECORDING) {
                            // 只在文件大小变化时更新Toast，避免频繁刷新
                            val currentSizeMB = fileSizeBytes / (1024 * 1024)
                            if (progressToast == null || currentSizeMB > 0) {
                                // 取消之前的Toast
                                progressToast?.cancel()
                                // 创建新的Toast，使用LONG显示时间
                                progressToast = Toast.makeText(this@MainActivity, "录制进度: ${durationSec}s, ${currentSizeMB}MB", Toast.LENGTH_LONG)
                                progressToast?.show()
                                android.util.Log.d("MainActivity", "Progress toast shown: ${durationSec}s, ${currentSizeMB}MB")
                            }
                        } else {
                            // 如果不在录制状态，取消Toast
                            android.util.Log.d("MainActivity", "Not recording, canceling progress toast")
                            progressToast?.cancel()
                            progressToast = null
                        }
                    }
                }
                override fun onRecordingPaused() {
                    runOnUiThread {
                        // 取消进度Toast
                        progressToast?.cancel()
                        progressToast = null
                        Toast.makeText(this@MainActivity, "录制已暂停", Toast.LENGTH_SHORT).show()
                        updateRecordingStatus(com.funny.replaysdk.RecordingStatus.PAUSED)
                        updateButtonStates(com.funny.replaysdk.RecordingStatus.PAUSED)
                    }
                }
                override fun onRecordingResumed() {
                    runOnUiThread {
                        Toast.makeText(this@MainActivity, "录制已恢复", Toast.LENGTH_SHORT).show()
                        updateRecordingStatus(com.funny.replaysdk.RecordingStatus.RECORDING)
                        updateButtonStates(com.funny.replaysdk.RecordingStatus.RECORDING)
                    }
                }
                override fun onRecordingQualityAdjusted(quality: com.funny.replaysdk.VideoQuality) {
                    runOnUiThread {
                        Toast.makeText(this@MainActivity, "录制质量已调整为: $quality", Toast.LENGTH_SHORT).show()
                    }
                }
                override fun onRecordingStopped(result: com.funny.replaysdk.RecordingResult) {
                    runOnUiThread {
                        // 取消进度Toast
                        progressToast?.cancel()
                        progressToast = null
                        android.util.Log.d("MainActivity", "onRecordingStopped called: success=${result.isSuccess}, path=${result.filePath}")
                        Toast.makeText(this@MainActivity, "录制完成: ${result.filePath}", Toast.LENGTH_LONG).show()
                        lastVideoPath = result.filePath // 保存最后录制的视频路径
                        updateRecordingStatus(com.funny.replaysdk.RecordingStatus.IDLE)
                        updateButtonStates(com.funny.replaysdk.RecordingStatus.IDLE)
                        android.util.Log.d("MainActivity", "UI status updated to IDLE")
                    }
                }
                override fun onRecordingError(errorCode: Int, errorMessage: String?) {
                    runOnUiThread {
                        // 取消进度Toast
                        progressToast?.cancel()
                        progressToast = null
                        Toast.makeText(this@MainActivity, "录制错误: $errorCode - $errorMessage", Toast.LENGTH_LONG).show()
                        updateRecordingStatus(com.funny.replaysdk.RecordingStatus.IDLE)
                        updateButtonStates(com.funny.replaysdk.RecordingStatus.IDLE)
                    }
                }
            }
            val ok = RecordingManager.startRecording(this, RecordingConfig(), callback)
            Toast.makeText(this, "startRecording=$ok", Toast.LENGTH_SHORT).show()
        }
        btnStop.setOnClickListener {
            android.util.Log.d("MainActivity", "Stop button clicked, current status: ${RecordingManager.getRecordingStatus()}")
            // 立即取消进度Toast
            progressToast?.cancel()
            progressToast = null
            // 立即更新按钮状态为停止中
            updateButtonStates(com.funny.replaysdk.RecordingStatus.STOPPING)
            
            RecordingManager.stopRecording { result ->
                runOnUiThread {
                    android.util.Log.d("MainActivity", "Stop recording result: success=${result.isSuccess}, code=${result.errorCode}, message=${result.errorMessage}")
                    Toast.makeText(this@MainActivity, "停止录制: ${if (result.isSuccess) "成功" else "失败"} (${result.errorCode})", Toast.LENGTH_SHORT).show()
                    
                    // 根据结果更新按钮状态
                    if (result.isSuccess) {
                        updateButtonStates(com.funny.replaysdk.RecordingStatus.IDLE)
                    } else {
                        // 停止失败，恢复到之前的状态
                        val currentStatus = RecordingManager.getRecordingStatus()
                        updateButtonStates(currentStatus)
                    }
                    
                    // 恢复停止按钮文字
                    btnStop.text = "停止录制"
                }
            }
        }

        findViewById<Button>(R.id.btn_open).setOnClickListener {
            // 打开外部专属 Movies/replay 目录
            val base = getExternalFilesDir(Environment.DIRECTORY_MOVIES) ?: filesDir
            val dir = File(base, "replay")
            if (!dir.exists()) dir.mkdirs()
            val intent = Intent(Intent.ACTION_VIEW).apply {
                setDataAndType(Uri.fromFile(dir), "resource/folder")
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            try {
                startActivity(intent)
            } catch (e: Exception) {
                // 部分系统不支持直接打开文件夹，退而求其次打开系统文件管理器
                val picker = Intent(Intent.ACTION_VIEW).apply {
                    setDataAndType(Uri.parse(dir.absolutePath), "*/*")
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
                try { startActivity(picker) } catch (_: Exception) {
                    Toast.makeText(this, "请在文件管理器中查看: ${dir.absolutePath}", Toast.LENGTH_LONG).show()
                }
            }
        }
        
        btnPause.setOnClickListener {
            val success = RecordingManager.pauseRecording()
            Toast.makeText(this, "暂停录制: $success", Toast.LENGTH_SHORT).show()
            if (success) {
                updateButtonStates(com.funny.replaysdk.RecordingStatus.PAUSED)
            }
        }
        
        btnResume.setOnClickListener {
            val success = RecordingManager.resumeRecording()
            Toast.makeText(this, "恢复录制: $success", Toast.LENGTH_SHORT).show()
            if (success) {
                updateButtonStates(com.funny.replaysdk.RecordingStatus.RECORDING)
            }
        }
        
        btnQualityHigh.setOnClickListener {
            val success = RecordingManager.adjustRecordingQuality(com.funny.replaysdk.VideoQuality.HIGH)
            Toast.makeText(this, "调整高质量: $success", Toast.LENGTH_SHORT).show()
        }
        
        btnQualityMedium.setOnClickListener {
            val success = RecordingManager.adjustRecordingQuality(com.funny.replaysdk.VideoQuality.MEDIUM)
            Toast.makeText(this, "调整中质量: $success", Toast.LENGTH_SHORT).show()
        }
        
        btnQualityLow.setOnClickListener {
            val success = RecordingManager.adjustRecordingQuality(com.funny.replaysdk.VideoQuality.LOW)
            Toast.makeText(this, "调整低质量: $success", Toast.LENGTH_SHORT).show()
        }
        
        findViewById<Button>(R.id.btn_reset).setOnClickListener {
            // 取消进度Toast
            progressToast?.cancel()
            progressToast = null
            RecordingManager.resetStatus()
            updateButtonStates(com.funny.replaysdk.RecordingStatus.IDLE)
            Toast.makeText(this, "状态已重置", Toast.LENGTH_SHORT).show()
        }
        
        // 打开保存目录按钮
        findViewById<Button>(R.id.btn_open).setOnClickListener {
            try {
                val dir = File(getExternalFilesDir(android.os.Environment.DIRECTORY_MOVIES), "replay")
                if (!dir.exists()) {
                    dir.mkdirs()
                }
                
                // 使用FileProvider来安全地访问文件
                val uri = if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.N) {
                    androidx.core.content.FileProvider.getUriForFile(
                        this,
                        "$packageName.fileprovider",
                        dir
                    )
                } else {
                    android.net.Uri.fromFile(dir)
                }
                
                val intent = android.content.Intent(android.content.Intent.ACTION_VIEW)
                intent.setDataAndType(uri, "resource/folder")
                intent.addFlags(android.content.Intent.FLAG_GRANT_READ_URI_PERMISSION)
                
                if (intent.resolveActivity(packageManager) != null) {
                    startActivity(intent)
                } else {
                    // 如果无法打开文件管理器，显示路径信息
                    val message = "录制目录: ${dir.absolutePath}\n\n请手动在文件管理器中打开此路径"
                    android.app.AlertDialog.Builder(this)
                        .setTitle("录制目录")
                        .setMessage(message)
                        .setPositiveButton("复制路径") { _, _ ->
                            val clipboard = getSystemService(android.content.Context.CLIPBOARD_SERVICE) as android.content.ClipboardManager
                            val clip = android.content.ClipData.newPlainText("录制目录", dir.absolutePath)
                            clipboard.setPrimaryClip(clip)
                            Toast.makeText(this, "路径已复制到剪贴板", Toast.LENGTH_SHORT).show()
                        }
                        .setNegativeButton("确定", null)
                        .show()
                }
            } catch (e: Exception) {
                android.util.Log.e("MainActivity", "Failed to open directory", e)
                Toast.makeText(this, "打开目录失败: ${e.message}", Toast.LENGTH_SHORT).show()
            }
        }
        
        // 详细状态显示按钮
        findViewById<Button>(R.id.btn_status).setOnClickListener {
            val detailedStatus = RecordingManager.getDetailedStatus()
            val statusText = """
                状态: ${detailedStatus.status}
                内存: ${detailedStatus.memoryUsage.usagePercentage}%
                投影: ${detailedStatus.hasProjection}
                录制器: ${detailedStatus.hasRecorder}
                显示: ${detailedStatus.hasDisplay}
                文件: ${detailedStatus.outputFile ?: "无"}
                文件大小: ${detailedStatus.outputFileSize / 1024}KB
            """.trimIndent()
            
            android.app.AlertDialog.Builder(this)
                .setTitle("详细状态")
                .setMessage(statusText)
                .setPositiveButton("确定", null)
                .show()
        }
        
        findViewById<Button>(R.id.btn_recover).setOnClickListener {
            // 取消进度Toast
            progressToast?.cancel()
            progressToast = null
            val success = RecordingManager.recoverFromError()
            Toast.makeText(this, "错误恢复: $success", Toast.LENGTH_SHORT).show()
        }
        
        // 格式转换按钮
        findViewById<Button>(R.id.btn_convert_gif).setOnClickListener {
            // GIF转换功能开发中，显示提示
            android.app.AlertDialog.Builder(this)
                .setTitle("功能开发中")
                .setMessage("GIF转换功能正在开发中，敬请期待！\n\n当前版本暂不支持GIF格式转换，请使用其他格式或等待后续更新。")
                .setPositiveButton("确定", null)
                .setNeutralButton("查看MP4文件") { _, _ ->
                    // 提供查看原始MP4文件的选项
                    if (lastVideoPath != null) {
                        val file = File(lastVideoPath!!)
                        if (file.exists()) {
                            val intent = android.content.Intent(android.content.Intent.ACTION_VIEW)
                            intent.setDataAndType(android.net.Uri.fromFile(file), "video/mp4")
                            intent.addFlags(android.content.Intent.FLAG_ACTIVITY_NEW_TASK)
                            try {
                                startActivity(intent)
                            } catch (e: Exception) {
                                Toast.makeText(this, "无法打开视频文件: ${e.message}", Toast.LENGTH_SHORT).show()
                            }
                        } else {
                            Toast.makeText(this, "视频文件不存在", Toast.LENGTH_SHORT).show()
                        }
                    } else {
                        Toast.makeText(this, "请先录制一个视频", Toast.LENGTH_SHORT).show()
                    }
                }
                .show()
        }
        
        findViewById<Button>(R.id.btn_convert_webm).setOnClickListener {
            convertLastVideo(com.funny.replaysdk.OutputFormat.WEBM)
        }
        
        findViewById<Button>(R.id.btn_convert_avi).setOnClickListener {
            convertLastVideo(com.funny.replaysdk.OutputFormat.AVI)
        }
        
        // 音频播放按钮
        findViewById<Button>(R.id.btn_play_audio).setOnClickListener {
            playTestAudio()
        }
        
        findViewById<Button>(R.id.btn_stop_audio).setOnClickListener {
            stopTestAudio()
        }
    }
    
    private fun startPerformanceMonitoring() {
        val performanceRunnable = object : Runnable {
            override fun run() {
                updateMemoryInfo()
                updateFpsInfo()
                updateRecordingStatus(RecordingManager.getRecordingStatus())
                performanceHandler.postDelayed(this, 1000) // 每秒更新一次
            }
        }
        performanceHandler.post(performanceRunnable)
    }
    
    private fun startFpsMonitoring() {
        choreographer = Choreographer.getInstance()
        choreographer?.postFrameCallback(frameCallback)
    }
    
    private fun updateMemoryInfo() {
        val memoryUsage = com.funny.replaysdk.SausageReplayAndroidSDK.getMemoryUsage()
        val usedMemoryMB = memoryUsage.usedMemory / (1024 * 1024)
        val totalMemoryMB = memoryUsage.totalMemory / (1024 * 1024)
        val maxMemoryMB = memoryUsage.maxMemory / (1024 * 1024)
        val usagePercent = memoryUsage.usagePercentage
        
        tvMemory.text = "内存: ${usedMemoryMB}MB/${totalMemoryMB}MB (${usagePercent}%)\n最大: ${maxMemoryMB}MB"
        
        // 调试日志
        val freeMemoryMB = memoryUsage.freeMemory / (1024 * 1024)
        android.util.Log.d("MemoryMonitor", "Memory: used=${usedMemoryMB}MB, total=${totalMemoryMB}MB, free=${freeMemoryMB}MB, max=${maxMemoryMB}MB")
    }
    
    private fun updateFpsInfo() {
        // 基于Choreographer的FPS计算
        val currentTime = System.currentTimeMillis()
        val deltaTime = currentTime - lastFrameTime
        
        if (deltaTime >= 1000) { // 每秒计算一次FPS
            val fps = if (deltaTime > 0) (frameCount * 1000.0 / deltaTime).toInt() else 0
            tvFps.text = "FPS: $fps"
            frameCount = 0
            lastFrameTime = currentTime
        }
    }
    
    private fun updateRecordingStatus(status: com.funny.replaysdk.RecordingStatus) {
        val statusText = when (status) {
            com.funny.replaysdk.RecordingStatus.IDLE -> "状态: 空闲"
            com.funny.replaysdk.RecordingStatus.RECORDING -> "状态: 录制中"
            com.funny.replaysdk.RecordingStatus.PAUSED -> "状态: 暂停"
            com.funny.replaysdk.RecordingStatus.STOPPING -> "状态: 停止中"
        }
        tvStatus.text = statusText
    }
    
    private fun updateButtonStates(status: com.funny.replaysdk.RecordingStatus) {
        when (status) {
            com.funny.replaysdk.RecordingStatus.IDLE -> {
                // 空闲状态：只能开始录制
                btnStart.isEnabled = true
                btnStop.isEnabled = false
                btnPause.isEnabled = false
                btnResume.isEnabled = false
                btnQualityHigh.isEnabled = false
                btnQualityMedium.isEnabled = false
                btnQualityLow.isEnabled = false
                
                // 设置按钮样式
                setButtonStyle(btnStart, true)
                setButtonStyle(btnStop, false)
                setButtonStyle(btnPause, false)
                setButtonStyle(btnResume, false)
                setButtonStyle(btnQualityHigh, false)
                setButtonStyle(btnQualityMedium, false)
                setButtonStyle(btnQualityLow, false)
            }
            com.funny.replaysdk.RecordingStatus.RECORDING -> {
                // 录制中：可以停止、暂停、调整质量
                btnStart.isEnabled = false
                btnStop.isEnabled = true
                btnPause.isEnabled = true
                btnResume.isEnabled = false
                btnQualityHigh.isEnabled = true
                btnQualityMedium.isEnabled = true
                btnQualityLow.isEnabled = true
                
                // 设置按钮样式
                setButtonStyle(btnStart, false)
                setButtonStyle(btnStop, true)
                setButtonStyle(btnPause, true)
                setButtonStyle(btnResume, false)
                setButtonStyle(btnQualityHigh, true)
                setButtonStyle(btnQualityMedium, true)
                setButtonStyle(btnQualityLow, true)
            }
            com.funny.replaysdk.RecordingStatus.PAUSED -> {
                // 暂停状态：可以停止、恢复
                btnStart.isEnabled = false
                btnStop.isEnabled = true
                btnPause.isEnabled = false
                btnResume.isEnabled = true
                btnQualityHigh.isEnabled = false
                btnQualityMedium.isEnabled = false
                btnQualityLow.isEnabled = false
                
                // 设置按钮样式
                setButtonStyle(btnStart, false)
                setButtonStyle(btnStop, true)
                setButtonStyle(btnPause, false)
                setButtonStyle(btnResume, true)
                setButtonStyle(btnQualityHigh, false)
                setButtonStyle(btnQualityMedium, false)
                setButtonStyle(btnQualityLow, false)
            }
            com.funny.replaysdk.RecordingStatus.STOPPING -> {
                // 停止中：所有按钮都禁用
                btnStart.isEnabled = false
                btnStop.isEnabled = false
                btnPause.isEnabled = false
                btnResume.isEnabled = false
                btnQualityHigh.isEnabled = false
                btnQualityMedium.isEnabled = false
                btnQualityLow.isEnabled = false
                
                // 设置按钮样式
                setButtonStyle(btnStart, false)
                setButtonStoppingStyle(btnStop) // 停止按钮特殊样式
                setButtonStyle(btnPause, false)
                setButtonStyle(btnResume, false)
                setButtonStyle(btnQualityHigh, false)
                setButtonStyle(btnQualityMedium, false)
                setButtonStyle(btnQualityLow, false)
            }
        }
    }
    
    private fun setButtonStyle(button: Button, enabled: Boolean) {
        button.isEnabled = enabled
        if (enabled) {
            button.alpha = 1.0f
            button.setBackgroundResource(R.drawable.button_enabled)
            button.setTextColor(0xFFFFFFFF.toInt()) // 白色文字
        } else {
            button.alpha = 0.6f
            button.setBackgroundResource(R.drawable.button_disabled)
            button.setTextColor(0xFF666666.toInt()) // 深灰色文字
        }
    }
    
    private fun setButtonStoppingStyle(button: Button) {
        button.isEnabled = false
        button.alpha = 0.8f
        button.setBackgroundResource(R.drawable.button_stopping)
        button.setTextColor(0xFFFFFFFF.toInt()) // 白色文字
        button.text = "停止中..."
    }
    
    private var lastVideoPath: String? = null
    
    private fun convertLastVideo(format: com.funny.replaysdk.OutputFormat) {
        if (lastVideoPath == null) {
            Toast.makeText(this, "请先录制一个视频", Toast.LENGTH_SHORT).show()
            return
        }
        
        Toast.makeText(this, "开始转换格式: $format", Toast.LENGTH_SHORT).show()
        
        RecordingManager.convertVideoFormat(lastVideoPath!!, format) { success, outputPath ->
            runOnUiThread {
                if (success) {
                    Toast.makeText(this@MainActivity, "转换成功: $outputPath", Toast.LENGTH_LONG).show()
                } else {
                    Toast.makeText(this@MainActivity, "转换失败", Toast.LENGTH_SHORT).show()
                }
            }
        }
    }
    
    private fun playTestAudio() {
        try {
            if (isAudioPlaying) {
                Toast.makeText(this, "音频已在播放中", Toast.LENGTH_SHORT).show()
                return
            }
            
            // 使用ToneGenerator生成测试音频，更简单可靠
            toneGenerator = ToneGenerator(AudioManager.STREAM_MUSIC, 80).apply {
                // 播放一个持续的音调，用于测试录屏音频
                startTone(ToneGenerator.TONE_CDMA_ALERT_CALL_GUARD, 2000) // 播放2秒
                android.util.Log.d("MainActivity", "Test tone started")
                Toast.makeText(this@MainActivity, "开始播放测试音频（2秒）", Toast.LENGTH_SHORT).show()
            }
            
            isAudioPlaying = true
            
            // 2秒后自动停止
            Handler(Looper.getMainLooper()).postDelayed({
                stopTestAudio()
            }, 2000)
            
        } catch (e: Exception) {
            android.util.Log.e("MainActivity", "Failed to play test audio", e)
            Toast.makeText(this, "音频播放失败: ${e.message}", Toast.LENGTH_SHORT).show()
        }
    }
    
    private fun stopTestAudio() {
        try {
            // 停止MediaPlayer
            mediaPlayer?.let { player ->
                if (player.isPlaying) {
                    player.stop()
                    android.util.Log.d("MainActivity", "MediaPlayer stopped")
                }
                player.release()
                mediaPlayer = null
            }
            
            // 停止ToneGenerator
            toneGenerator?.let { generator ->
                generator.release()
                toneGenerator = null
                android.util.Log.d("MainActivity", "ToneGenerator stopped")
            }
            
            isAudioPlaying = false
            Toast.makeText(this, "音频已停止", Toast.LENGTH_SHORT).show()
        } catch (e: Exception) {
            android.util.Log.e("MainActivity", "Failed to stop audio", e)
        }
    }
    
    override fun onDestroy() {
        super.onDestroy()
        performanceHandler.removeCallbacksAndMessages(null)
        choreographer?.removeFrameCallback(frameCallback)
        // 清理音频资源
        stopTestAudio()
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        // 转发给库
        com.funny.replaysdk.PermissionManager.onRequestPermissionsResult(requestCode, permissions, grantResults)
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: android.content.Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        // Android 14+ 需要在前台服务中启动录屏
        if (requestCode == 10002 && resultCode == RESULT_OK && data != null) {
            RecordingFgService.start(this, resultCode, data)
        } else {
            // 兼容逻辑（低版本可以直接走库）
            com.funny.replaysdk.RecordingManager.onActivityResult(requestCode, resultCode, data)
        }
    }
}


