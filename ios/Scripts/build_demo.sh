#!/bin/bash

# SausageReplay iOS Demo 构建脚本
# 用于构建和运行Demo应用

set -e

# 配置
DEMO_PROJECT_NAME="SausageReplayDemo"
SDK_PROJECT_NAME="SausageReplay"
BUILD_DIR="build"
OUTPUT_DIR="output"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
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

echo_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
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

# 检查依赖
check_dependencies() {
    echo_info "检查依赖..."
    
    # 检查SDK项目是否存在
    if [ ! -f "../SausageReplay.xcodeproj/project.pbxproj" ]; then
        echo_error "SDK项目不存在，请先构建SDK"
        exit 1
    fi
    
    # 检查Demo项目是否存在
    if [ ! -f "SausageReplayDemo.xcodeproj/project.pbxproj" ]; then
        echo_error "Demo项目不存在"
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

# 构建SDK框架
build_sdk() {
    echo_step "1. 构建SDK框架..."
    
    # 构建iOS设备版本
    echo_info "构建iOS设备版本..."
    xcodebuild archive \
        -project "../SausageReplay.xcodeproj" \
        -scheme "$SDK_PROJECT_NAME" \
        -destination "generic/platform=iOS" \
        -archivePath "$BUILD_DIR/${SDK_PROJECT_NAME}-iOS.xcarchive" \
        SKIP_INSTALL=NO \
        BUILD_LIBRARY_FOR_DISTRIBUTION=YES \
        ONLY_ACTIVE_ARCH=NO
    
    # 构建iOS模拟器版本
    echo_info "构建iOS模拟器版本..."
    xcodebuild archive \
        -project "../SausageReplay.xcodeproj" \
        -scheme "$SDK_PROJECT_NAME" \
        -destination "generic/platform=iOS Simulator" \
        -archivePath "$BUILD_DIR/${SDK_PROJECT_NAME}-iOS-Simulator.xcarchive" \
        SKIP_INSTALL=NO \
        BUILD_LIBRARY_FOR_DISTRIBUTION=YES \
        ONLY_ACTIVE_ARCH=NO
    
    # 创建XCFramework
    echo_info "创建XCFramework..."
    xcodebuild -create-xcframework \
        -framework "$BUILD_DIR/${SDK_PROJECT_NAME}-iOS.xcarchive/Products/Library/Frameworks/${SDK_PROJECT_NAME}.framework" \
        -framework "$BUILD_DIR/${SDK_PROJECT_NAME}-iOS-Simulator.xcarchive/Products/Library/Frameworks/${SDK_PROJECT_NAME}.framework" \
        -output "$BUILD_DIR/${SDK_PROJECT_NAME}.xcframework"
    
    echo_info "SDK构建完成"
}

# 构建Demo应用
build_demo() {
    echo_step "2. 构建Demo应用..."
    
    # 构建Debug版本
    echo_info "构建Debug版本..."
    xcodebuild build \
        -project "SausageReplayDemo.xcodeproj" \
        -scheme "$DEMO_PROJECT_NAME" \
        -destination "generic/platform=iOS" \
        -configuration Debug \
        -derivedDataPath "$BUILD_DIR/DerivedData" \
        ONLY_ACTIVE_ARCH=NO
    
    # 构建Release版本
    echo_info "构建Release版本..."
    xcodebuild build \
        -project "SausageReplayDemo.xcodeproj" \
        -scheme "$DEMO_PROJECT_NAME" \
        -destination "generic/platform=iOS" \
        -configuration Release \
        -derivedDataPath "$BUILD_DIR/DerivedData" \
        ONLY_ACTIVE_ARCH=NO
    
    echo_info "Demo应用构建完成"
}

# 构建模拟器版本
build_simulator() {
    echo_step "3. 构建模拟器版本..."
    
    echo_info "构建iOS模拟器版本..."
    xcodebuild build \
        -project "SausageReplayDemo.xcodeproj" \
        -scheme "$DEMO_PROJECT_NAME" \
        -destination "generic/platform=iOS Simulator" \
        -configuration Debug \
        -derivedDataPath "$BUILD_DIR/DerivedData" \
        ONLY_ACTIVE_ARCH=NO
    
    echo_info "模拟器版本构建完成"
}

# 运行测试
run_tests() {
    echo_step "4. 运行测试..."
    
    # 检查是否有测试目标
    if xcodebuild -list -project "SausageReplayDemo.xcodeproj" | grep -q "Test"; then
        echo_info "运行单元测试..."
        xcodebuild test \
            -project "SausageReplayDemo.xcodeproj" \
            -scheme "$DEMO_PROJECT_NAME" \
            -destination "platform=iOS Simulator,name=iPhone 15" \
            -derivedDataPath "$BUILD_DIR/DerivedData"
    else
        echo_warn "没有找到测试目标，跳过测试"
    fi
}

# 生成IPA文件
generate_ipa() {
    echo_step "5. 生成IPA文件..."
    
    # 创建临时目录
    TEMP_DIR="$BUILD_DIR/temp"
    mkdir -p "$TEMP_DIR"
    
    # 复制应用文件
    APP_PATH="$BUILD_DIR/DerivedData/Build/Products/Debug-iphoneos/${DEMO_PROJECT_NAME}.app"
    if [ -d "$APP_PATH" ]; then
        cp -R "$APP_PATH" "$TEMP_DIR/"
        
        # 创建Payload目录
        mkdir -p "$TEMP_DIR/Payload"
        mv "$TEMP_DIR/${DEMO_PROJECT_NAME}.app" "$TEMP_DIR/Payload/"
        
        # 创建IPA文件
        cd "$TEMP_DIR"
        zip -r "../../${OUTPUT_DIR}/${DEMO_PROJECT_NAME}.ipa" Payload/
        cd - > /dev/null
        
        echo_info "IPA文件已生成: $OUTPUT_DIR/${DEMO_PROJECT_NAME}.ipa"
    else
        echo_warn "应用文件不存在，跳过IPA生成"
    fi
}

# 显示构建结果
show_results() {
    echo_step "6. 构建结果..."
    
    echo_info "构建完成！"
    echo_info "构建产物位置:"
    
    if [ -d "$BUILD_DIR/${SDK_PROJECT_NAME}.xcframework" ]; then
        echo_info "  - SDK框架: $BUILD_DIR/${SDK_PROJECT_NAME}.xcframework"
        du -sh "$BUILD_DIR/${SDK_PROJECT_NAME}.xcframework"
    fi
    
    if [ -d "$BUILD_DIR/DerivedData/Build/Products/Debug-iphoneos/${DEMO_PROJECT_NAME}.app" ]; then
        echo_info "  - Demo应用: $BUILD_DIR/DerivedData/Build/Products/Debug-iphoneos/${DEMO_PROJECT_NAME}.app"
        du -sh "$BUILD_DIR/DerivedData/Build/Products/Debug-iphoneos/${DEMO_PROJECT_NAME}.app"
    fi
    
    if [ -f "$OUTPUT_DIR/${DEMO_PROJECT_NAME}.ipa" ]; then
        echo_info "  - IPA文件: $OUTPUT_DIR/${DEMO_PROJECT_NAME}.ipa"
        du -sh "$OUTPUT_DIR/${DEMO_PROJECT_NAME}.ipa"
    fi
}

# 清理临时文件
cleanup() {
    echo_info "清理临时文件..."
    rm -rf "$BUILD_DIR/temp"
}

# 显示帮助信息
show_help() {
    echo "SausageReplay iOS Demo 构建脚本"
    echo ""
    echo "用法: $0 [选项]"
    echo ""
    echo "选项:"
    echo "  -h, --help     显示帮助信息"
    echo "  -s, --sdk      只构建SDK"
    echo "  -d, --demo     只构建Demo应用"
    echo "  -i, --ipa      生成IPA文件"
    echo "  -t, --test     运行测试"
    echo "  -c, --clean    清理构建目录"
    echo "  --simulator    构建模拟器版本"
    echo ""
    echo "示例:"
    echo "  $0              # 完整构建"
    echo "  $0 -s           # 只构建SDK"
    echo "  $0 -d -i        # 构建Demo并生成IPA"
    echo "  $0 --simulator  # 构建模拟器版本"
}

# 主函数
main() {
    local build_sdk_only=false
    local build_demo_only=false
    local generate_ipa_flag=false
    local run_tests_flag=false
    local clean_only=false
    local simulator_only=false
    
    # 解析命令行参数
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            -s|--sdk)
                build_sdk_only=true
                shift
                ;;
            -d|--demo)
                build_demo_only=true
                shift
                ;;
            -i|--ipa)
                generate_ipa_flag=true
                shift
                ;;
            -t|--test)
                run_tests_flag=true
                shift
                ;;
            -c|--clean)
                clean_only=true
                shift
                ;;
            --simulator)
                simulator_only=true
                shift
                ;;
            *)
                echo_error "未知选项: $1"
                show_help
                exit 1
                ;;
        esac
    done
    
    # 检查当前目录
    if [ ! -f "SausageReplayDemo.xcodeproj/project.pbxproj" ]; then
        echo_error "请在Demo项目目录中运行此脚本"
        exit 1
    fi
    
    check_xcode
    
    if [ "$clean_only" = true ]; then
        clean_build
        echo_info "清理完成"
        exit 0
    fi
    
    check_dependencies
    clean_build
    
    if [ "$build_sdk_only" = true ]; then
        build_sdk
    elif [ "$build_demo_only" = true ]; then
        build_demo
        if [ "$generate_ipa_flag" = true ]; then
            generate_ipa
        fi
    elif [ "$simulator_only" = true ]; then
        build_simulator
    else
        # 完整构建
        build_sdk
        build_demo
        
        if [ "$run_tests_flag" = true ]; then
            run_tests
        fi
        
        if [ "$generate_ipa_flag" = true ]; then
            generate_ipa
        fi
    fi
    
    show_results
    cleanup
    
    echo_info "构建完成！"
}

# 运行主函数
main "$@"
