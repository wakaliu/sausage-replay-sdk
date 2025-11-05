package com.funny.replaysdk.sample

import android.os.Bundle
import android.widget.Toast
import androidx.appcompat.app.AppCompatActivity
import android.widget.Button
import android.widget.TextView
import com.funny.replaysdk.VideoQualityPreset
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
    
    private lateinit var tvFps: TextView
    private lateinit var tvStatus: TextView
    
    // 按钮引用
    private lateinit var btnStart: Button
    private lateinit var btnStop: Button
    private lateinit var btnPresetBasic: Button
    private lateinit var btnPresetStandard: Button
    private lateinit var btnPresetSmooth: Button
    private lateinit var btnPresetHighFps: Button
    private lateinit var btnPresetUltra: Button
    
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
        tvFps = findViewById(R.id.tv_fps)
        tvStatus = findViewById(R.id.tv_status)
        
        // 初始化按钮引用
        btnStart = findViewById(R.id.btn_start)
        btnStop = findViewById(R.id.btn_stop)
        btnPresetBasic = findViewById(R.id.btn_preset_basic)
        btnPresetStandard = findViewById(R.id.btn_preset_standard)
        btnPresetSmooth = findViewById(R.id.btn_preset_smooth)
        btnPresetHighFps = findViewById(R.id.btn_preset_high_fps)
        btnPresetUltra = findViewById(R.id.btn_preset_ultra)
        
        // 初始化按钮状态
        updateButtonStates(com.funny.replaysdk.RecordingStatus.IDLE)
        
        SausageReplayAndroidSDK.initialize(this, VideoQualityPreset.HIGH_FPS)
        
        // 启动性能监控
        startPerformanceMonitoring()
        startFpsMonitoring()

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
                override fun onRecordingQualityAdjusted(quality: Int) { /* no-op: SDK 不再在录制中调整质量 */ }
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
        
        
        btnPresetBasic.setOnClickListener {
            val ok = SausageReplayAndroidSDK.initialize(this, VideoQualityPreset.BASIC)
            Toast.makeText(this, "切换到基础(720p30)——下次录制生效: $ok", Toast.LENGTH_SHORT).show()
        }
        btnPresetStandard.setOnClickListener {
            val ok = SausageReplayAndroidSDK.initialize(this, VideoQualityPreset.STANDARD)
            Toast.makeText(this, "切换到标准(1080p30)——下次录制生效: $ok", Toast.LENGTH_SHORT).show()
        }
        btnPresetSmooth.setOnClickListener {
            val ok = SausageReplayAndroidSDK.initialize(this, VideoQualityPreset.SMOOTH)
            Toast.makeText(this, "切换到流畅(720p60)——下次录制生效: $ok", Toast.LENGTH_SHORT).show()
        }
        btnPresetHighFps.setOnClickListener {
            val ok = SausageReplayAndroidSDK.initialize(this, VideoQualityPreset.HIGH_FPS)
            Toast.makeText(this, "切换到高帧(1080p60)——下次录制生效: $ok", Toast.LENGTH_SHORT).show()
        }
        btnPresetUltra.setOnClickListener {
            val ok = SausageReplayAndroidSDK.initialize(this, VideoQualityPreset.ULTRA)
            Toast.makeText(this, "切换到超清(1440p)——下次录制生效: $ok", Toast.LENGTH_SHORT).show()
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
    
    private fun updateRecordingStatus(status: Int) {
        val statusText = when (status) {
            com.funny.replaysdk.RecordingStatus.IDLE -> "状态: 空闲"
            com.funny.replaysdk.RecordingStatus.RECORDING -> "状态: 录制中"
            com.funny.replaysdk.RecordingStatus.STOPPING -> "状态: 停止中"
            else -> "状态: 未知"
        }
        tvStatus.text = statusText
    }
    
    private fun updateButtonStates(status: Int) {
        when (status) {
            com.funny.replaysdk.RecordingStatus.IDLE -> {
                // 空闲状态：可开始录制，也可切换清晰度档位（下次录制生效）
                btnStart.isEnabled = true
                btnStop.isEnabled = false
                btnPresetBasic.isEnabled = true
                btnPresetStandard.isEnabled = true
                btnPresetSmooth.isEnabled = true
                btnPresetHighFps.isEnabled = true
                btnPresetUltra.isEnabled = true
                
                // 设置按钮样式
                setButtonStyle(btnStart, true)
                setButtonStyle(btnStop, false)
                setButtonStyle(btnPresetBasic, true)
                setButtonStyle(btnPresetStandard, true)
                setButtonStyle(btnPresetSmooth, true)
                setButtonStyle(btnPresetHighFps, true)
                setButtonStyle(btnPresetUltra, true)
            }
            com.funny.replaysdk.RecordingStatus.RECORDING -> {
                // 录制中：仅可停止；清晰度切换按钮禁用（下次录制生效）
                btnStart.isEnabled = false
                btnStop.isEnabled = true
                btnPresetBasic.isEnabled = false
                btnPresetStandard.isEnabled = false
                btnPresetSmooth.isEnabled = false
                btnPresetHighFps.isEnabled = false
                btnPresetUltra.isEnabled = false
                
                // 设置按钮样式
                setButtonStyle(btnStart, false)
                setButtonStyle(btnStop, true)
                setButtonStyle(btnPresetBasic, false)
                setButtonStyle(btnPresetStandard, false)
                setButtonStyle(btnPresetSmooth, false)
                setButtonStyle(btnPresetHighFps, false)
                setButtonStyle(btnPresetUltra, false)
            }
            com.funny.replaysdk.RecordingStatus.STOPPING -> {
                // 停止中：所有按钮都禁用
                btnStart.isEnabled = false
                btnStop.isEnabled = false
                btnPresetBasic.isEnabled = false
                btnPresetStandard.isEnabled = false
                btnPresetSmooth.isEnabled = false
                btnPresetHighFps.isEnabled = false
                btnPresetUltra.isEnabled = false
                
                // 设置按钮样式
                setButtonStyle(btnStart, false)
                setButtonStoppingStyle(btnStop) // 停止按钮特殊样式
                setButtonStyle(btnPresetBasic, false)
                setButtonStyle(btnPresetStandard, false)
                setButtonStyle(btnPresetSmooth, false)
                setButtonStyle(btnPresetHighFps, false)
                setButtonStyle(btnPresetUltra, false)
            }
            else -> {
                // 未知状态，禁用所有按钮
                btnStart.isEnabled = false
                btnStop.isEnabled = false
                btnPresetBasic.isEnabled = false
                btnPresetStandard.isEnabled = false
                btnPresetSmooth.isEnabled = false
                btnPresetHighFps.isEnabled = false
                btnPresetUltra.isEnabled = false
                
                setButtonStyle(btnStart, false)
                setButtonStyle(btnStop, false)
                setButtonStyle(btnPresetBasic, false)
                setButtonStyle(btnPresetStandard, false)
                setButtonStyle(btnPresetSmooth, false)
                setButtonStyle(btnPresetHighFps, false)
                setButtonStyle(btnPresetUltra, false)
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


    override fun onActivityResult(requestCode: Int, resultCode: Int, data: android.content.Intent?) {
        // 使用 SDK 的代理授权 Activity（ScreenCapturePermissionActivity）与内部前台服务流程
        // 这里不再拦截或转发，避免重复处理导致崩溃
        super.onActivityResult(requestCode, resultCode, data)
    }
}


