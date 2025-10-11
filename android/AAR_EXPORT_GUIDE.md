# AAR 导出指南

## 概述

本指南介绍如何使用新增的Gradle Task来一键导出AAR包到Unity项目。

## 新增的Gradle Task

### 1. exportAar
**功能**: 一键导出AAR包到Unity插件目录
**命令**: `./gradlew :replay-sdk:exportAar`

**执行流程**:
1. 自动构建Release版本的AAR包
2. 检查AAR文件是否存在
3. 创建Unity插件目录（如果不存在）
4. 复制AAR文件到 `unity/Plugins/Android/SausageReplaySDK.aar`
5. 显示导出结果和文件信息

### 2. cleanExportedAar
**功能**: 清理导出的AAR包
**命令**: `./gradlew :replay-sdk:cleanExportedAar`

**执行流程**:
1. 删除Unity插件目录中的AAR文件
2. 显示清理结果

### 3. aarInfo
**功能**: 显示AAR包信息
**命令**: `./gradlew :replay-sdk:aarInfo`

**显示信息**:
- 构建的AAR文件路径和大小
- Unity中的AAR文件路径和大小
- 文件修改时间
- 可用的Task列表

## 便捷脚本

### Windows用户

#### 1. export-aar.bat
**功能**: 简单的AAR导出脚本
**使用方法**: 双击运行或在命令行中执行
```cmd
export-aar.bat
```

#### 2. export-aar-advanced.bat
**功能**: 高级AAR导出脚本，提供菜单选项
**使用方法**: 双击运行或在命令行中执行
```cmd
export-aar-advanced.bat
```

**菜单选项**:
1. Export AAR to Unity (default) - 默认导出
2. Show AAR information - 显示AAR信息
3. Clean exported AAR - 清理导出的AAR
4. Build only (no export) - 仅构建，不导出
5. Export with custom name - 自定义名称导出
6. Exit - 退出

### Linux/Mac用户

#### export-aar.sh
**功能**: Linux/Mac下的AAR导出脚本
**使用方法**: 
```bash
chmod +x export-aar.sh
./export-aar.sh
```

## 使用示例

### 基本使用

1. **导出AAR到Unity**:
```bash
# 在android目录下执行
./gradlew :replay-sdk:exportAar
```

2. **查看AAR信息**:
```bash
./gradlew :replay-sdk:aarInfo
```

3. **清理导出的AAR**:
```bash
./gradlew :replay-sdk:cleanExportedAar
```

### 高级使用

1. **仅构建AAR**:
```bash
./gradlew :replay-sdk:assembleRelease
```

2. **查看所有可用Task**:
```bash
./gradlew :replay-sdk:tasks --group=sausage-replay
```

## 输出示例

### 成功导出
```
> Task :replay-sdk:exportAar
✅ AAR package exported successfully!
📁 Location: E:\githubprj\sausage-replay-sdk\unity\Plugins\Android\SausageReplaySDK.aar
📦 File size: 1024KB
🔗 Ready for Unity integration
```

### AAR信息显示
```
📦 AAR Package Information:
==================================================
🏗️  Built AAR:
   📁 Path: E:\githubprj\sausage-replay-sdk\android\replay-sdk\build\outputs\aar\replay-sdk-release.aar
   📏 Size: 1024KB
   📅 Modified: 2025-01-11 15:30:45

🎮 Unity AAR:
   📁 Path: E:\githubprj\sausage-replay-sdk\unity\Plugins\Android\SausageReplaySDK.aar
   📏 Size: 1024KB
   📅 Modified: 2025-01-11 15:30:45

🔧 Available Tasks:
   ./gradlew exportAar          - Export AAR to Unity
   ./gradlew cleanExportedAar   - Clean exported AAR
   ./gradlew aarInfo            - Show AAR information
```

## 目录结构

导出后的目录结构：
```
sausage-replay-sdk/
├── android/
│   ├── replay-sdk/
│   │   └── build/
│   │       └── outputs/
│   │           └── aar/
│   │               └── replay-sdk-release.aar  # 构建的AAR
│   ├── export-aar.bat
│   ├── export-aar.sh
│   └── export-aar-advanced.bat
└── unity/
    └── Plugins/
        └── Android/
            └── SausageReplaySDK.aar  # 导出的AAR
```

## 故障排除

### 常见问题

1. **AAR文件不存在**
   - 错误: `AAR file not found`
   - 解决: 先运行 `./gradlew :replay-sdk:assembleRelease`

2. **Unity目录不存在**
   - 错误: 无法创建Unity插件目录
   - 解决: 确保项目根目录下有unity文件夹

3. **权限问题**
   - 错误: 无法复制文件
   - 解决: 检查文件权限，确保有写入权限

### 调试技巧

1. **查看详细日志**:
```bash
./gradlew :replay-sdk:exportAar --info
```

2. **检查文件是否存在**:
```bash
./gradlew :replay-sdk:aarInfo
```

3. **清理后重新导出**:
```bash
./gradlew :replay-sdk:cleanExportedAar
./gradlew :replay-sdk:exportAar
```

## 集成到CI/CD

### GitHub Actions示例
```yaml
- name: Export AAR to Unity
  run: |
    cd android
    ./gradlew :replay-sdk:exportAar
    
- name: Check AAR export
  run: |
    if [ -f "unity/Plugins/Android/SausageReplaySDK.aar" ]; then
      echo "✅ AAR exported successfully"
    else
      echo "❌ AAR export failed"
      exit 1
    fi
```

### Jenkins Pipeline示例
```groovy
stage('Export AAR') {
    steps {
        sh 'cd android && ./gradlew :replay-sdk:exportAar'
    }
    post {
        success {
            echo 'AAR exported successfully'
        }
        failure {
            echo 'AAR export failed'
        }
    }
}
```

## 最佳实践

1. **版本控制**: 建议将导出的AAR文件添加到.gitignore，避免版本冲突
2. **自动化**: 在CI/CD流程中集成AAR导出
3. **验证**: 导出后验证AAR文件大小和完整性
4. **清理**: 定期清理旧的AAR文件

## 注意事项

1. 确保在android目录下执行命令
2. 导出前会自动构建Release版本
3. 如果Unity目录不存在，会自动创建
4. 导出的AAR文件名固定为 `SausageReplaySDK.aar`
5. 支持Windows、Linux、Mac平台
