@echo off
chcp 65001 >nul
cd /d "%~dp0"
echo ========================================
echo   系统还原脚本启动中...
echo   将恢复 Windows 默认设置
echo ========================================
echo.
powershell -ExecutionPolicy Bypass -NoProfile -File "%~dp0system_restore.ps1"
pause
