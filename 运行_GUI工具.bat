@echo off
chcp 65001 >nul
cd /d "%~dp0"
echo.
echo ========================================
echo   启动 GUI 调试工具...
echo   请勿关闭此窗口
echo ========================================
echo.
powershell -ExecutionPolicy Bypass -NoProfile -File "%~dp0main_gui.ps1"
