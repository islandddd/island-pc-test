# ============================================================
# 关闭华为/荣耀手机助手"设备连接时自动启动"功能
# 双击运行即可
# ============================================================

# 自动提权
$currentUser = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
if (-not $currentUser.IsInRole([Security.Principal.WindowsBuiltInRole]"Administrator")) {
    Start-Process powershell -Verb RunAs -ArgumentList "-ExecutionPolicy Bypass -File `"$PSCommandPath`""
    exit
}

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  关闭手机助手设备连接自动启动" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$paths = @(
    @{Path="$env:LOCALAPPDATA\HiSuite\userdata\Setting.ini"; Name="华为手机助手 HiSuite"},
    @{Path="$env:LOCALAPPDATA\HonorSuite\userdata\Setting.ini"; Name="荣耀手机助手 HonorSuite"}
)

$found = $false
foreach ($item in $paths) {
    $p = $item.Path
    $name = $item.Name
    if (Test-Path $p) {
        $found = $true
        $content = Get-Content $p -Encoding UTF8
        if ($content -match 'autolaunch=1') {
            $content = $content -replace 'autolaunch=1', 'autolaunch=0'
            Set-Content $p -Value $content -Encoding UTF8
            Write-Host "  [OK] $name 已关闭自动启动" -ForegroundColor Green
        } elseif ($content -match 'autolaunch=0') {
            Write-Host "  [>>] $name 自动启动已经是关闭状态" -ForegroundColor Yellow
        } else {
            Write-Host "  [?] $name 未找到 autolaunch 配置，添加中..." -ForegroundColor Yellow
            $content += "`r`n[system]`r`nautolaunch=0"
            Set-Content $p -Value $content -Encoding UTF8
            Write-Host "  [OK] $name 已添加并关闭自动启动" -ForegroundColor Green
        }
    }
}

if (-not $found) {
    Write-Host "  [!!] 未检测到华为/荣耀手机助手已安装" -ForegroundColor Red
    Write-Host "       请先安装软件后再运行此脚本" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  操作完成" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Read-Host "按 Enter 键退出..."
