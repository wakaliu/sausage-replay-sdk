@echo off
setlocal enabledelayedexpansion

echo ========================================
echo   Sausage Replay SDK - Advanced Export
echo ========================================
echo.

REM 检查是否在正确的目录
if not exist "replay-sdk\build.gradle.kts" (
    echo Error: Please run this script from the android directory
    echo Current directory: %CD%
    pause
    exit /b 1
)

:menu
echo Please select an option:
echo.
echo 1. Export AAR to Unity (default)
echo 2. Show AAR information
echo 3. Clean exported AAR
echo 4. Build only (no export)
echo 5. Export with custom name
echo 6. Exit
echo.
set /p choice="Enter your choice (1-6): "

if "%choice%"=="1" goto export_default
if "%choice%"=="2" goto show_info
if "%choice%"=="3" goto clean_aar
if "%choice%"=="4" goto build_only
if "%choice%"=="5" goto export_custom
if "%choice%"=="6" goto exit
echo Invalid choice. Please try again.
echo.
goto menu

:export_default
echo.
echo Exporting AAR to Unity...
call gradlew :replay-sdk:exportAar
goto check_result

:show_info
echo.
echo Showing AAR information...
call gradlew :replay-sdk:aarInfo
echo.
pause
goto menu

:clean_aar
echo.
echo Cleaning exported AAR...
call gradlew :replay-sdk:cleanExportedAar
echo.
pause
goto menu

:build_only
echo.
echo Building AAR only...
call gradlew :replay-sdk:assembleRelease
goto check_result

:export_custom
echo.
set /p custom_name="Enter custom AAR name (without .aar extension): "
if "%custom_name%"=="" (
    echo Invalid name. Using default.
    goto export_default
)
echo.
echo Exporting AAR with custom name: %custom_name%.aar
call gradlew :replay-sdk:assembleRelease
if %ERRORLEVEL% EQU 0 (
    if not exist "..\unity\Plugins\Android" mkdir "..\unity\Plugins\Android"
    copy "replay-sdk\build\outputs\aar\replay-sdk-release.aar" "..\unity\Plugins\Android\%custom_name%.aar"
    if %ERRORLEVEL% EQU 0 (
        echo ✅ AAR exported successfully as %custom_name%.aar
    ) else (
        echo ❌ Failed to copy AAR file
    )
) else (
    echo ❌ Failed to build AAR
)
echo.
pause
goto menu

:check_result
if %ERRORLEVEL% EQU 0 (
    echo.
    echo ========================================
    echo   Operation completed successfully!
    echo ========================================
) else (
    echo.
    echo ========================================
    echo   Operation failed!
    echo ========================================
    echo Please check the error messages above.
)
echo.
pause
goto menu

:exit
echo.
echo Goodbye!
exit /b 0
