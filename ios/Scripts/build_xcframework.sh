#!/bin/bash

# SausageReplay iOS SDK 构建脚本
# 用于构建 XCFramework 供 Unity 集成

set -e

# 配置
PROJECT_NAME="SausageReplay"
SCHEME_NAME="SausageReplay"
BUILD_DIR="build"
OUTPUT_DIR="output"
XCFRAMEWORK_NAME="SausageReplay.xcframework"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

echo_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

echo_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 检查 Xcode 版本
check_xcode() {
    echo_info "检查 Xcode 版本..."
    xcodebuild -version
    if [ $? -ne 0 ]; then
        echo_error "Xcode 未安装或未正确配置"
        exit 1
    fi
}

# 清理构建目录
clean_build() {
    echo_info "清理构建目录..."
    rm -rf "$BUILD_DIR"
    rm -rf "$OUTPUT_DIR"
    mkdir -p "$BUILD_DIR"
    mkdir -p "$OUTPUT_DIR"
}

# 构建 iOS 设备版本
build_ios_device() {
    echo_info "构建 iOS 设备版本..."
    xcodebuild archive \
        -project "${PROJECT_NAME}.xcodeproj" \
        -scheme "$SCHEME_NAME" \
        -destination "generic/platform=iOS" \
        -archivePath "$BUILD_DIR/${PROJECT_NAME}-iOS.xcarchive" \
        SKIP_INSTALL=NO \
        BUILD_LIBRARY_FOR_DISTRIBUTION=YES \
        ONLY_ACTIVE_ARCH=NO
}

# 构建 iOS 模拟器版本
build_ios_simulator() {
    echo_info "构建 iOS 模拟器版本..."
    xcodebuild archive \
        -project "${PROJECT_NAME}.xcodeproj" \
        -scheme "$SCHEME_NAME" \
        -destination "generic/platform=iOS Simulator" \
        -archivePath "$BUILD_DIR/${PROJECT_NAME}-iOS-Simulator.xcarchive" \
        SKIP_INSTALL=NO \
        BUILD_LIBRARY_FOR_DISTRIBUTION=YES \
        ONLY_ACTIVE_ARCH=NO
}

# 创建 XCFramework
create_xcframework() {
    echo_info "创建 XCFramework..."
    xcodebuild -create-xcframework \
        -framework "$BUILD_DIR/${PROJECT_NAME}-iOS.xcarchive/Products/Library/Frameworks/${PROJECT_NAME}.framework" \
        -framework "$BUILD_DIR/${PROJECT_NAME}-iOS-Simulator.xcarchive/Products/Library/Frameworks/${PROJECT_NAME}.framework" \
        -output "$OUTPUT_DIR/$XCFRAMEWORK_NAME"
}

# 验证 XCFramework
verify_xcframework() {
    echo_info "验证 XCFramework..."
    if [ -d "$OUTPUT_DIR/$XCFRAMEWORK_NAME" ]; then
        echo_info "XCFramework 创建成功: $OUTPUT_DIR/$XCFRAMEWORK_NAME"
        
        # 显示架构信息
        echo_info "支持的架构:"
        lipo -info "$OUTPUT_DIR/$XCFRAMEWORK_NAME/ios-arm64/${PROJECT_NAME}.framework/${PROJECT_NAME}" 2>/dev/null || echo "iOS 设备架构信息获取失败"
        lipo -info "$OUTPUT_DIR/$XCFRAMEWORK_NAME/ios-arm64_x86_64-simulator/${PROJECT_NAME}.framework/${PROJECT_NAME}" 2>/dev/null || echo "iOS 模拟器架构信息获取失败"
        
        # 显示文件大小
        du -sh "$OUTPUT_DIR/$XCFRAMEWORK_NAME"
    else
        echo_error "XCFramework 创建失败"
        exit 1
    fi
}

# 复制到 Unity 目录
copy_to_unity() {
    echo_info "复制到 Unity 目录..."
    UNITY_PLUGINS_DIR="../../Package/Runtime/Plugins/iOS"
    
    if [ -d "$UNITY_PLUGINS_DIR" ]; then
        rm -rf "$UNITY_PLUGINS_DIR/$XCFRAMEWORK_NAME"
        cp -R "$OUTPUT_DIR/$XCFRAMEWORK_NAME" "$UNITY_PLUGINS_DIR/"
        echo_info "已复制到 Unity 插件目录: $UNITY_PLUGINS_DIR"
    else
        echo_warn "Unity 插件目录不存在: $UNITY_PLUGINS_DIR"
    fi
}

# 生成版本信息
generate_version_info() {
    echo_info "生成版本信息..."
    VERSION=$(grep "MARKETING_VERSION" SausageReplay.xcodeproj/project.pbxproj | head -1 | sed 's/.*MARKETING_VERSION = //; s/;.*//')
    BUILD_NUMBER=$(grep "CURRENT_PROJECT_VERSION" SausageReplay.xcodeproj/project.pbxproj | head -1 | sed 's/.*CURRENT_PROJECT_VERSION = //; s/;.*//')
    
    cat > "$OUTPUT_DIR/version.txt" << EOF
SausageReplay iOS SDK
Version: $VERSION
Build: $BUILD_NUMBER
Build Date: $(date)
Xcode Version: $(xcodebuild -version | head -1)
EOF
    
    echo_info "版本信息已保存到: $OUTPUT_DIR/version.txt"
}

# 主函数
main() {
    echo_info "开始构建 SausageReplay iOS SDK..."
    
    # 检查当前目录
    if [ ! -f "${PROJECT_NAME}.xcodeproj/project.pbxproj" ]; then
        echo_error "请在包含 ${PROJECT_NAME}.xcodeproj 的目录中运行此脚本"
        exit 1
    fi
    
    check_xcode
    clean_build
    build_ios_device
    build_ios_simulator
    create_xcframework
    verify_xcframework
    copy_to_unity
    generate_version_info
    
    echo_info "构建完成！"
    echo_info "XCFramework 位置: $OUTPUT_DIR/$XCFRAMEWORK_NAME"
}

# 运行主函数
main "$@"
