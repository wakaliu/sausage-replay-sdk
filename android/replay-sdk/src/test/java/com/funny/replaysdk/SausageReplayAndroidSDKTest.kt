package com.funny.replaysdk

import org.junit.Test
import org.junit.Assert.*

class SausageReplayAndroidSDKTest {
    
    @Test
    fun testVersion() {
        val version = SausageReplayAndroidSDK.getVersion()
        assertNotNull("Version should not be null", version)
        assertTrue("Version should not be empty", version.isNotEmpty())
    }
    
    @Test
    fun testPlatformSupport() {
        val isSupported = SausageReplayAndroidSDK.isPlatformSupported()
        assertTrue("Platform should be supported", isSupported)
    }
    
    @Test
    fun testMemoryUsage() {
        val memoryUsage = SausageReplayAndroidSDK.getMemoryUsage()
        assertNotNull("Memory usage should not be null", memoryUsage)
        assertTrue("Total memory should be positive", memoryUsage.totalMemory > 0)
        assertTrue("Max memory should be positive", memoryUsage.maxMemory > 0)
        assertTrue("Used memory should be non-negative", memoryUsage.usedMemory >= 0)
        assertTrue("Free memory should be non-negative", memoryUsage.freeMemory >= 0)
        assertTrue("Usage percentage should be between 0-100", 
            memoryUsage.usagePercentage in 0..100)
    }
    
    // VideoQuality 已移除，改用 VideoQualityPreset 控制清晰度
    
    // 输出格式相关测试已移除（当前不在 SDK 内定义）
    
    // RecordingStatus 不是枚举，跳过枚举测试
    
    @Test
    fun testRecordingConfigDefaults() {
        val config = RecordingConfig()
        assertTrue("Default max duration should be positive", config.maxDurationSeconds > 0)
        assertTrue("Default max file size should be positive", config.maxFileSizeBytes > 0)
        assertTrue("Default should include audio", config.includeAudio)
        assertEquals("Default target FPS should be 30", 30, config.targetFps)
        assertEquals("Default performance tier should be STANDARD", 
            VideoQualityPreset.STANDARD, config.performanceTier)
    }
    
    @Test
    fun testMemoryUsageDataClass() {
        val memoryUsage = MemoryUsage(
            totalMemory = 1000L,
            usedMemory = 500L,
            freeMemory = 500L,
            maxMemory = 2000L,
            usagePercentage = 25
        )
        
        assertEquals("Total memory should match", 1000L, memoryUsage.totalMemory)
        assertEquals("Used memory should match", 500L, memoryUsage.usedMemory)
        assertEquals("Free memory should match", 500L, memoryUsage.freeMemory)
        assertEquals("Max memory should match", 2000L, memoryUsage.maxMemory)
        assertEquals("Usage percentage should match", 25, memoryUsage.usagePercentage)
    }
    
    // DetailedStatus 结构已变更，跳过旧结构测试
}
