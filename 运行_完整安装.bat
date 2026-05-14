@echo off
chcp 65001 >nul
cd /d "%~dp0"
echo ========================================
echo   完整脚本启动中（系统设置 + 软件安装）
echo ========================================
echo.
powershell -ExecutionPolicy Bypass -NoProfile -File "%~dp0full_setup.ps1"
pause
