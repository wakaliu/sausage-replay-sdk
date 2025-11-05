@echo off
echo ========================================
echo   Sausage Replay SDK - AAR Export Tool
echo ========================================
echo.

REM 检查是否在正确的目录
if not exist "replay-sdk\build.gradle.kts" (
    echo Error: Please run this script from the android directory
    echo Current directory: %CD%
    pause
    exit /b 1
)

echo Building and exporting AAR package...
echo.

REM 执行导出任务
call gradlew :replay-sdk:exportAar

if %ERRORLEVEL% EQU 0 (
    echo.
    echo ========================================
    echo   Export completed successfully!
    echo ========================================
    echo.
    echo The AAR package has been exported to:
    echo   unity\Plugins\Android\SausageReplaySDK.aar
    echo.
    echo You can now use it in your Unity project.
    echo.
) else (
    echo.
    echo ========================================
    echo   Export failed!
    echo ========================================
    echo.
    echo Please check the error messages above.
    echo.
)

pause
