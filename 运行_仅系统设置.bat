@echo off
chcp 65001 >nul
cd /d "%~dp0"
echo ========================================
echo   系统设置脚本启动中...
echo ========================================
echo.
powershell -ExecutionPolicy Bypass -NoProfile -File "%~dp0system_setup.ps1"
pause
