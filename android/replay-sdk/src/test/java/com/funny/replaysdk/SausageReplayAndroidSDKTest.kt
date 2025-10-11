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
    
    @Test
    fun testVideoQualityEnum() {
        val qualities = VideoQuality.values()
        assertEquals("Should have 3 quality levels", 3, qualities.size)
        assertTrue("Should contain LOW quality", qualities.contains(VideoQuality.LOW))
        assertTrue("Should contain MEDIUM quality", qualities.contains(VideoQuality.MEDIUM))
        assertTrue("Should contain HIGH quality", qualities.contains(VideoQuality.HIGH))
    }
    
    @Test
    fun testOutputFormatEnum() {
        val formats = OutputFormat.values()
        assertEquals("Should have 4 output formats", 4, formats.size)
        assertTrue("Should contain MP4 format", formats.contains(OutputFormat.MP4))
        assertTrue("Should contain GIF format", formats.contains(OutputFormat.GIF))
        assertTrue("Should contain WEBM format", formats.contains(OutputFormat.WEBM))
        assertTrue("Should contain AVI format", formats.contains(OutputFormat.AVI))
    }
    
    @Test
    fun testRecordingStatusEnum() {
        val statuses = RecordingStatus.values()
        assertEquals("Should have 4 statuses", 4, statuses.size)
        assertTrue("Should contain IDLE status", statuses.contains(RecordingStatus.IDLE))
        assertTrue("Should contain RECORDING status", statuses.contains(RecordingStatus.RECORDING))
        assertTrue("Should contain PAUSED status", statuses.contains(RecordingStatus.PAUSED))
        assertTrue("Should contain STOPPING status", statuses.contains(RecordingStatus.STOPPING))
    }
    
    @Test
    fun testRecordingConfigDefaults() {
        val config = RecordingConfig()
        assertEquals("Default quality should be MEDIUM", VideoQuality.MEDIUM, config.quality)
        assertEquals("Default max duration should be 60 seconds", 60, config.maxDurationSeconds)
        assertEquals("Default max file size should be 50MB", 50L * 1024 * 1024, config.maxFileSizeBytes)
        assertTrue("Default should include audio", config.includeAudio)
        assertEquals("Default output format should be MP4", OutputFormat.MP4, config.outputFormat)
        assertEquals("Default target FPS should be 30", 30, config.targetFps)
        assertEquals("Default performance tier should be MID_RANGE", 
            DevicePerformanceTier.MID_RANGE, config.performanceTier)
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
    
    @Test
    fun testDetailedStatusDataClass() {
        val memoryUsage = MemoryUsage(1000L, 500L, 500L, 2000L, 25)
        val config = RecordingConfig()
        
        val detailedStatus = DetailedStatus(
            status = RecordingStatus.IDLE,
            memoryUsage = memoryUsage,
            config = config,
            hasProjection = false,
            hasRecorder = false,
            hasDisplay = false,
            outputFile = null,
            outputFileSize = 0L
        )
        
        assertEquals("Status should match", RecordingStatus.IDLE, detailedStatus.status)
        assertEquals("Memory usage should match", memoryUsage, detailedStatus.memoryUsage)
        assertEquals("Config should match", config, detailedStatus.config)
        assertFalse("Should not have projection", detailedStatus.hasProjection)
        assertFalse("Should not have recorder", detailedStatus.hasRecorder)
        assertFalse("Should not have display", detailedStatus.hasDisplay)
        assertNull("Output file should be null", detailedStatus.outputFile)
        assertEquals("Output file size should be 0", 0L, detailedStatus.outputFileSize)
    }
}
