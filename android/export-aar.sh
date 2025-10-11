#!/bin/bash

echo "========================================"
echo "  Sausage Replay SDK - AAR Export Tool"
echo "========================================"
echo

# 检查是否在正确的目录
if [ ! -f "replay-sdk/build.gradle.kts" ]; then
    echo "Error: Please run this script from the android directory"
    echo "Current directory: $(pwd)"
    exit 1
fi

echo "Building and exporting AAR package..."
echo

# 执行导出任务
./gradlew :replay-sdk:exportAar

if [ $? -eq 0 ]; then
    echo
    echo "========================================"
    echo "  Export completed successfully!"
    echo "========================================"
    echo
    echo "The AAR package has been exported to:"
    echo "  unity/Plugins/Android/SausageReplaySDK.aar"
    echo
    echo "You can now use it in your Unity project."
    echo
else
    echo
    echo "========================================"
    echo "  Export failed!"
    echo "========================================"
    echo
    echo "Please check the error messages above."
    echo
    exit 1
fi
