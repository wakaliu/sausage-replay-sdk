import java.text.SimpleDateFormat
import java.util.Date

plugins {
    alias(libs.plugins.android.library)
    alias(libs.plugins.kotlin.android)
}

android {
    namespace = "com.funny.replaysdk"
    compileSdk = 36

    defaultConfig {
        minSdk = 22
        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
        consumerProguardFiles("consumer-rules.pro")
    }
    
    testOptions {
        targetSdk = 33
    }
    
    lint {
        targetSdk = 33
    }

    buildTypes {
        release {
            isMinifyEnabled = false
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
        debug {
            isMinifyEnabled = false
        }
    }

    publishing {
        singleVariant("release")
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }
    kotlinOptions {
        jvmTarget = "11"
    }
}

dependencies {
    implementation(kotlin("stdlib"))
    implementation(libs.androidx.core.ktx)
}

// 自定义Task：一键导出AAR包
tasks.register<Copy>("exportAar") {
    group = "sausage-replay"
    description = "Export AAR package to Unity plugins directory"
    
    dependsOn("assembleRelease")
    
    val aarFile = file("${layout.buildDirectory.get()}/outputs/aar/replay-sdk-release.aar")
    val unityPluginsDir = file("../../unity/Plugins/Android")
    
    // 检查AAR文件是否存在
    doFirst {
        if (!aarFile.exists()) {
            throw GradleException("AAR file not found: ${aarFile.absolutePath}")
        }
        
        // 创建Unity插件目录（如果不存在）
        if (!unityPluginsDir.exists()) {
            unityPluginsDir.mkdirs()
            println("Created Unity plugins directory: ${unityPluginsDir.absolutePath}")
        }
    }
    
    // 复制AAR文件到Unity插件目录
    from(aarFile)
    into(unityPluginsDir)
    rename { "SausageReplaySDK.aar" }
    
    doLast {
        val targetFile = file("$unityPluginsDir/SausageReplaySDK.aar")
        if (targetFile.exists()) {
            println("✅ AAR package exported successfully!")
            println("📁 Location: ${targetFile.absolutePath}")
            println("📦 File size: ${targetFile.length() / 1024}KB")
            println("🔗 Ready for Unity integration")
        } else {
            throw GradleException("Failed to export AAR package")
        }
    }
}

// 自定义Task：清理导出的AAR包
tasks.register<Delete>("cleanExportedAar") {
    group = "sausage-replay"
    description = "Clean exported AAR package from Unity plugins directory"
    
    val unityPluginsDir = file("../../unity/Plugins/Android")
    val aarFile = file("$unityPluginsDir/SausageReplaySDK.aar")
    
    delete(aarFile)
    
    doLast {
        if (!aarFile.exists()) {
            println("✅ Exported AAR package cleaned successfully!")
        } else {
            println("⚠️ Failed to clean exported AAR package")
        }
    }
}

// 自定义Task：显示AAR包信息
tasks.register("aarInfo") {
    group = "sausage-replay"
    description = "Show AAR package information"
    
    doLast {
        val aarFile = file("${layout.buildDirectory.get()}/outputs/aar/replay-sdk-release.aar")
        val unityAarFile = file("../../unity/Plugins/Android/SausageReplaySDK.aar")
        
        println("📦 AAR Package Information:")
        println("=".repeat(50))
        
        if (aarFile.exists()) {
            println("🏗️  Built AAR:")
            println("   📁 Path: ${aarFile.absolutePath}")
            println("   📏 Size: ${aarFile.length() / 1024}KB")
            println("   📅 Modified: ${SimpleDateFormat("yyyy-MM-dd HH:mm:ss").format(Date(aarFile.lastModified()))}")
        } else {
            println("❌ Built AAR not found. Run 'assembleRelease' first.")
        }
        
        println()
        
        if (unityAarFile.exists()) {
            println("🎮 Unity AAR:")
            println("   📁 Path: ${unityAarFile.absolutePath}")
            println("   📏 Size: ${unityAarFile.length() / 1024}KB")
            println("   📅 Modified: ${SimpleDateFormat("yyyy-MM-dd HH:mm:ss").format(Date(unityAarFile.lastModified()))}")
        } else {
            println("❌ Unity AAR not found. Run 'exportAar' first.")
        }
        
        println()
        println("🔧 Available Tasks:")
        println("   ./gradlew exportAar          - Export AAR to Unity")
        println("   ./gradlew cleanExportedAar   - Clean exported AAR")
        println("   ./gradlew aarInfo            - Show AAR information")
    }
}