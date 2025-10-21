#!/bin/bash

# SausageReplay iOS 快速启动脚本
# 一键构建SDK和Demo应用

set -e

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

echo_title() {
    echo -e "${PURPLE}================================${NC}"
    echo -e "${PURPLE}  SausageReplay iOS 快速启动${NC}"
    echo -e "${PURPLE}================================${NC}"
}

echo_step() {
    echo -e "${BLUE}[步骤]${NC} $1"
}

echo_success() {
    echo -e "${GREEN}[成功]${NC} $1"
}

echo_warn() {
    echo -e "${YELLOW}[警告]${NC} $1"
}

echo_error() {
    echo -e "${RED}[错误]${NC} $1"
}

# 检查环境
check_environment() {
    echo_step "检查开发环境..."
    
    # 检查Xcode
    if ! command -v xcodebuild &> /dev/null; then
        echo_error "Xcode未安装或未正确配置"
        exit 1
    fi
    
    # 检查当前目录
    if [ ! -f "SausageReplay.xcodeproj/project.pbxproj" ]; then
        echo_error "请在iOS项目根目录运行此脚本"
        exit 1
    fi
    
    echo_success "环境检查通过"
}

# 构建SDK
build_sdk() {
    echo_step "构建SDK框架..."
    
    if [ -f "Scripts/build_xcframework.sh" ]; then
        chmod +x Scripts/build_xcframework.sh
        ./Scripts/build_xcframework.sh
        echo_success "SDK构建完成"
    else
        echo_error "SDK构建脚本不存在"
        exit 1
    fi
}

# 构建Demo
build_demo() {
    echo_step "构建Demo应用..."
    
    if [ -d "Demo" ] && [ -f "Demo/Scripts/build_demo.sh" ]; then
        cd Demo
        chmod +x Scripts/build_demo.sh
        ./Scripts/build_demo.sh --simulator
        cd ..
        echo_success "Demo应用构建完成"
    else
        echo_warn "Demo项目不存在，跳过Demo构建"
    fi
}

# 显示结果
show_results() {
    echo_step "构建结果..."
    
    echo ""
    echo -e "${GREEN}🎉 构建完成！${NC}"
    echo ""
    echo -e "${BLUE}📁 构建产物：${NC}"
    
    if [ -d "output/SausageReplay.xcframework" ]; then
        echo -e "  ✅ SDK框架: output/SausageReplay.xcframework"
        du -sh output/SausageReplay.xcframework 2>/dev/null || echo "    (大小信息获取失败)"
    fi
    
    if [ -d "Demo/build/DerivedData/Build/Products/Debug-iphonesimulator/SausageReplayDemo.app" ]; then
        echo -e "  ✅ Demo应用: Demo/build/DerivedData/Build/Products/Debug-iphonesimulator/SausageReplayDemo.app"
        du -sh Demo/build/DerivedData/Build/Products/Debug-iphonesimulator/SausageReplayDemo.app 2>/dev/null || echo "    (大小信息获取失败)"
    fi
    
    echo ""
    echo -e "${BLUE}🚀 下一步操作：${NC}"
    echo -e "  1. 在Xcode中打开 Demo/SausageReplayDemo.xcodeproj"
    echo -e "  2. 选择iOS模拟器或真机"
    echo -e "  3. 点击运行按钮 (⌘+R) 启动Demo应用"
    echo ""
    echo -e "${BLUE}📖 更多信息：${NC}"
    echo -e "  - SDK文档: ios/README.md"
    echo -e "  - Demo说明: ios/Demo/README.md"
    echo -e "  - 开发总结: ios/DEVELOPMENT_SUMMARY.md"
    echo ""
}

# 主函数
main() {
    echo_title
    
    check_environment
    build_sdk
    build_demo
    show_results
    
    echo -e "${GREEN}✨ 快速启动完成！${NC}"
}

# 运行主函数
main "$@"
