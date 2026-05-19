# ============================================================
# 系统设置还原脚本 - 恢复 Windows 默认设置
# 将 system_setup.ps1 所做的更改全部还原
# 运行：双击 "运行_还原设置.bat" 启动
# ============================================================

param([switch]$NoPause, [string]$LogPath)

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $scriptDir

$now = Get-Date -Format 'yyyyMMdd_HHmmss'
$logDir = Join-Path $scriptDir "logs"
New-Item -ItemType Directory -Path $logDir -Force | Out-Null
if ($LogPath) {
    $logFile = $LogPath
} else {
    $logFile = Join-Path $logDir "restore_${now}.log"
}
$global:logLines = @()
$global:logStats = [ordered]@{ OK = 0; WARN = 0; ERROR = 0; INFO = 0; STEP = 0 }
$global:stepList = @()

function Write-Log {
    param([string]$Msg, [string]$Color = "White")
    $level = switch ($Color) {
        "Green"  { "OK" }
        "Yellow" { "WARN" }
        "Red"    { "ERROR" }
        "Cyan"   { "INFO" }
        "Gray"   { "DETAIL" }
        default  { "INFO" }
    }
    if ($global:logStats.Contains($level)) { $global:logStats[$level]++ } else { $global:logStats.INFO++ }
    $line = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') [$level] $Msg"
    $global:logLines += $line
    try { [System.IO.File]::AppendAllText($logFile, $line + "`r`n", [System.Text.Encoding]::UTF8) } catch {}
    switch ($Color) {
        "Green"  { Write-Host "  [OK] $Msg" -ForegroundColor Green }
        "Yellow" { Write-Host "  [>>] $Msg" -ForegroundColor Yellow }
        "Red"    { Write-Host "  [!!] $Msg" -ForegroundColor Red }
        "Cyan"   { Write-Host "  [ii] $Msg" -ForegroundColor Cyan }
        "Gray"   { Write-Host "       $Msg" -ForegroundColor Gray }
        default  { Write-Host "       $Msg" }
    }
}

function Write-Step {
    param([string]$Msg)
    Write-Host ""
    Write-Host "=== $Msg ===" -ForegroundColor Magenta
    $global:logStats.STEP++
    $global:stepList += $Msg
    $line = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') [STEP] $Msg"
    $global:logLines += ""
    $global:logLines += $line
    try { [System.IO.File]::AppendAllText($logFile, "`r`n" + $line + "`r`n", [System.Text.Encoding]::UTF8) } catch {}
}

function Save-LogFile {
    Write-AiLogSummary
    Write-Host ""
    Write-Host "日志文件: $logFile" -ForegroundColor Gray
}

function Write-LogHeader {
    param([string]$ScriptName, [string]$Mode)
    $isAdmin = Test-Admin
    $os = $null
    $cs = $null
    try { $os = Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue } catch {}
    try { $cs = Get-CimInstance Win32_ComputerSystem -ErrorAction SilentlyContinue } catch {}
    $header = @(
        "===== AI_LOG_START =====",
        "ScriptName: $ScriptName",
        "Mode: $Mode",
        "StartTime: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')",
        "ScriptDir: $scriptDir",
        "LogFile: $logFile",
        "RunAsAdmin: $isAdmin",
        "ComputerName: $env:COMPUTERNAME",
        "UserName: $env:USERNAME",
        "PowerShellVersion: $($PSVersionTable.PSVersion)",
        "OS: $($os.Caption) $($os.Version) Build $($os.BuildNumber) $($os.OSArchitecture)",
        "Device: $($cs.Manufacturer) $($cs.Model)",
        "Parameters: NoPause=$NoPause; LogPath=$LogPath",
        "AI_READ_HINT: 请重点查看 [ERROR] 和 [WARN] 行、卸载选择记录、最后的 AI_ANALYSIS_BLOCK、以及问题报告 zip。",
        "===== AI_LOG_BODY ====="
    )
    $global:logLines += $header
    try { [System.IO.File]::AppendAllText($logFile, ($header -join "`r`n") + "`r`n", [System.Text.Encoding]::UTF8) } catch {}
}

function Write-AiLogSummary {
    if ($script:aiSummaryWritten) { return }
    $script:aiSummaryWritten = $true
    $errors = @($global:logLines | Where-Object { $_ -match '\[ERROR\]' } | Select-Object -Last 30)
    $warnings = @($global:logLines | Where-Object { $_ -match '\[WARN\]' } | Select-Object -Last 30)
    $errorBlock = if ($errors.Count -gt 0) { $errors } else { @("无") }
    $warningBlock = if ($warnings.Count -gt 0) { $warnings } else { @("无") }
    $uninstallSummary = if (Get-Variable -Name toUninstall -ErrorAction SilentlyContinue) {
        "UninstallSummary: Selected=$($toUninstall.Count)"
    } else {
        "UninstallSummary: 未进入软件卸载选择或用户跳过"
    }
    $summary = @(
        "",
        "===== AI_ANALYSIS_BLOCK =====",
        "EndTime: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')",
        "ResultSummary: STEP=$($global:logStats.STEP); OK=$($global:logStats.OK); WARN=$($global:logStats.WARN); ERROR=$($global:logStats.ERROR); INFO=$($global:logStats.INFO)",
        $uninstallSummary,
        "Steps: $($global:stepList -join ' | ')",
        "ErrorLinesLast30:",
        $errorBlock,
        "WarningLinesLast30:",
        $warningBlock,
        "NextActionForUser: 如果问题没有解决，请在 GUI 点击'导出问题报告'，把 logs 里的 问题报告_*.zip 发给 AI。",
        "===== AI_LOG_END ====="
    )
    $global:logLines += $summary
    try { [System.IO.File]::AppendAllText($logFile, ($summary -join "`r`n") + "`r`n", [System.Text.Encoding]::UTF8) } catch {}
}

function Test-Admin {
    $currentUser = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
    return $currentUser.IsInRole([Security.Principal.WindowsBuiltInRole]"Administrator")
}

function Remove-RegValue {
    param([string]$Path, [string]$Name)
    try {
        $regPath = $Path -replace '^HKLM:', 'HKLM' -replace '^HKCU:', 'HKCU' -replace '^HKCR:', 'HKCR' -replace '^HKU:', 'HKU'
        & reg delete "$regPath" /v "$Name" /f 2>&1 | Out-Null
    } catch { }
}

function Remove-RegKey {
    param([string]$Path)
    try {
        $regPath = $Path -replace '^HKLM:', 'HKLM' -replace '^HKCU:', 'HKCU' -replace '^HKCR:', 'HKCR' -replace '^HKU:', 'HKU'
        & reg delete "$regPath" /f 2>&1 | Out-Null
    } catch { }
}

function Set-RegValue {
    param([string]$Path, [string]$Name, $Value, [string]$Type = "DWORD")
    try {
        $regPath = $Path -replace '^HKLM:', 'HKLM' -replace '^HKCU:', 'HKCU' -replace '^HKCR:', 'HKCR' -replace '^HKU:', 'HKU'
        $regType = if ($Type -eq "DWORD") { "REG_DWORD" } else { "REG_SZ" }
        & reg add "$regPath" /v "$Name" /t $regType /d "$Value" /f 2>&1 | Out-Null
        if ($LASTEXITCODE -ne 0) {
            Write-Log "注册表写入失败 $regPath\$Name (exit $LASTEXITCODE)" "Red"
        }
    } catch {
        Write-Log "注册表写入失败 $Path\$Name : $_" "Red"
    }
}

#region Auto-elevate
if (-not (Test-Admin)) {
    Write-Host "需要管理员权限，正在重新启动..." -ForegroundColor Yellow
    Start-Sleep -Seconds 1
    Start-Process powershell -Verb RunAs -ArgumentList "-ExecutionPolicy Bypass -File `"$PSCommandPath`""
    exit
}

$host.UI.RawUI.WindowTitle = "系统还原脚本"
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  系统设置还原脚本 v2.1" -ForegroundColor Cyan
Write-Host "  恢复 Windows 默认设置" -ForegroundColor Cyan
Write-Host "  时间: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

Write-LogHeader "system_restore.ps1" "还原设置"

# ============================================================
# 1. 还原壁纸为 Windows 默认
# ============================================================
Write-Step "1. 还原壁纸为 Windows 默认"

$defaultWallpaper = ""
$possibleDefaults = @(
    "C:\Windows\Web\Wallpaper\Windows\img0.jpg",
    "C:\Windows\Web\4K\Wallpaper\Windows\img0_3840x2160.jpg",
    "C:\Windows\Web\Wallpaper\Theme1\img1.jpg"
)
foreach ($path in $possibleDefaults) {
    if (Test-Path $path) {
        $defaultWallpaper = $path
        break
    }
}

if ($defaultWallpaper) {
    try {
        Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public class WallpaperHelper {
    [DllImport("user32.dll", CharSet = CharSet.Auto)]
    public static extern int SystemParametersInfo(uint uiAction, uint uiParam, string pvParam, uint fWinIni);
    public static void SetWallpaper(string path) {
        SystemParametersInfo(0x0014, 0, path, 0x0001 | 0x0002);
    }
}
'@ -ErrorAction Stop
        [WallpaperHelper]::SetWallpaper($defaultWallpaper)
        # 删除之前复制到系统目录的自定义壁纸
        Remove-Item -Path "$env:ProgramData\CustomAssets\wallpaper.*" -Force -ErrorAction SilentlyContinue
        Write-Log "壁纸已还原为 Windows 默认" "Green"
    } catch {
        Set-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name WallPaper -Value $defaultWallpaper -Force
        rundll32.exe user32.dll, UpdatePerUserSystemParameters, 1, $true 2>$null
        Remove-Item -Path "$env:ProgramData\CustomAssets\wallpaper.*" -Force -ErrorAction SilentlyContinue
        Write-Log "壁纸已还原为 Windows 默认（备用方案）" "Green"
    }
} else {
    Write-Log "未找到默认壁纸文件，请手动设置" "Yellow"
}

# ============================================================
# 2. 还原锁屏为 Windows 默认
# ============================================================
Write-Step "2. 还原锁屏为 Windows 默认"

Write-Log "正在清除自定义锁屏设置..." "Cyan"
# 移除锁屏策略
Remove-RegValue -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Personalization" -Name "LockScreenImage"
Remove-RegValue -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Personalization" -Name "NoChangingLockScreen"

# 移除 PersonalizationCSP 系统级锁屏（这是导致"由组织管理"的主要原因）
Remove-RegValue -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\PersonalizationCSP" -Name "LockScreenImagePath"
Remove-RegValue -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\PersonalizationCSP" -Name "LockScreenImageUrl"
Remove-RegValue -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\PersonalizationCSP" -Name "LockScreenImageStatus"
# 删除可能空置的 Policy 键，消除"由组织管理"
Remove-RegKey -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Personalization"
Remove-RegKey -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\PersonalizationCSP"

# 移除 CloudContent 策略
Remove-RegValue -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent" -Name "DisableWindowsConsumerFeatures"
Remove-RegKey -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent"

# 移除 HKCU 锁屏路径
Remove-RegValue -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Lock Screen" -Name "LockScreenImagePath"

# 恢复 ContentDeliveryManager 锁屏相关设置
Remove-RegValue -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" -Name "RotatingLockScreenEnabled"
Remove-RegValue -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" -Name "RotatingLockScreenOverlayEnabled"
Remove-RegValue -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" -Name "SubscribedContent-338387Enabled"
Remove-RegValue -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" -Name "ContentDeliveryAllowed"
Remove-RegValue -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" -Name "SystemPaneSuggestionsEnabled"

# 删除复制的锁屏文件
Remove-Item -Path "$env:ProgramData\CustomAssets\lockscreen.*" -Force -ErrorAction SilentlyContinue

# 清除锁屏缓存
Remove-Item -Path "$env:ProgramData\Microsoft\Windows\SystemData\S-1-5-18\ReadOnly\LockScreen_Z\*" -Recurse -Force -ErrorAction SilentlyContinue

Write-Log "锁屏已还原为 Windows 默认" "Green"

# ============================================================
# 3. 重新启用 Windows 更新
# ============================================================
Write-Step "3. 重新启用 Windows 更新"

# 3.1 恢复服务启动类型
$serviceDefaults = @{
    "wuauserv" = "Manual"
    "UsoSvc"   = "Manual"
    "BITS"     = "Manual"
}

foreach ($svcName in $serviceDefaults.Keys) {
    try {
        Set-Service -Name $svcName -StartupType $serviceDefaults[$svcName] -ErrorAction SilentlyContinue
        Start-Service -Name $svcName -ErrorAction SilentlyContinue
        Write-Log "服务 $svcName 已恢复为 $($serviceDefaults[$svcName])" "Green"
    } catch {
        Write-Log "恢复服务 $svcName 失败: $_" "Yellow"
    }
}

# 3.2 WaaSMedicSvc 需要特殊处理
try {
    & reg add "HKLM\SYSTEM\CurrentControlSet\Services\WaaSMedicSvc" /v "Start" /t REG_DWORD /d "3" /f 2>$null
    Set-Service -Name "WaaSMedicSvc" -StartupType Manual -ErrorAction SilentlyContinue
    Start-Service -Name "WaaSMedicSvc" -ErrorAction SilentlyContinue
    Write-Log "服务 WaaSMedicSvc 已恢复为 Manual" "Green"
} catch {
    Write-Log "恢复 WaaSMedicSvc 失败，可能需要手动处理" "Yellow"
}

# 3.3 移除禁用更新的注册表策略
Remove-RegValue -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" -Name "NoAutoUpdate"
Remove-RegValue -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" -Name "AUOptions"
Remove-RegValue -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" -Name "NoAutoRebootWithLoggedOnUsers"
Remove-RegKey -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU"

# 3.4 重新启用 Windows Update 计划任务
$updateTasks = @(
    "\Microsoft\Windows\WindowsUpdate\Scheduled Start",
    "\Microsoft\Windows\UpdateOrchestrator\Schedule Scan",
    "\Microsoft\Windows\UpdateOrchestrator\USO_UxBroker",
    "\Microsoft\Windows\UpdateOrchestrator\Reboot"
)
foreach ($task in $updateTasks) {
    try {
        Enable-ScheduledTask -TaskName (Split-Path $task -Leaf) -TaskPath (Split-Path $task) -ErrorAction SilentlyContinue
        Write-Log "已启用计划任务: $task" "Gray"
    } catch { }
}

Write-Log "Windows 更新已重新启用" "Green"

# ============================================================
# 4. 还原电源管理设置
# ============================================================
Write-Step "4. 还原电源管理为 Windows 默认"

try {
    # 显示器超时 - 恢复默认（AC: 10分钟, DC: 5分钟）
    powercfg /change monitor-timeout-ac 10 2>$null
    powercfg /change monitor-timeout-dc 5 2>$null
    Write-Log "显示器超时已恢复（AC:10分钟, DC:5分钟）" "Gray"

    # 睡眠超时 - 恢复默认（AC: 30分钟, DC: 15分钟）
    powercfg /change standby-timeout-ac 30 2>$null
    powercfg /change standby-timeout-dc 15 2>$null
    Write-Log "睡眠超时已恢复（AC:30分钟, DC:15分钟）" "Gray"

    # 休眠超时 - 恢复默认（从不）
    powercfg /change hibernate-timeout-ac 0 2>$null
    powercfg /change hibernate-timeout-dc 0 2>$null

    # 重新启用休眠
    powercfg /hibernate on 2>$null
    Write-Log "休眠模式已重新启用" "Gray"

    # 合盖操作恢复默认（睡眠）
    powercfg /setacvalueindex SCHEME_CURRENT SUB_BUTTONS LIDACTION 1 2>$null
    powercfg /setdcvalueindex SCHEME_CURRENT SUB_BUTTONS LIDACTION 1 2>$null
    Write-Log "合盖操作已恢复为睡眠" "Gray"

    # 还原电源按钮默认（电源按钮→关机，睡眠按钮→睡眠）
    powercfg /setacvalueindex SCHEME_CURRENT SUB_BUTTONS PBUTTONACTION 3 2>$null
    powercfg /setacvalueindex SCHEME_CURRENT SUB_BUTTONS SBUTTONACTION 1 2>$null
    Write-Log "电源按钮/睡眠按钮已恢复默认" "Gray"

    # 重新启用快速启动
    & reg add "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Power" /v HiberbootEnabled /t REG_DWORD /d 1 /f 2>&1 | Out-Null
    Write-Log "快速启动已重新启用" "Gray"

    # 恢复关机设置菜单选项（删除禁用键即恢复默认显示）
    & reg delete "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\FlyoutMenuSettings" /v ShowSleepOption /f 2>&1 | Out-Null
    & reg delete "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\FlyoutMenuSettings" /v ShowHibernateOption /f 2>&1 | Out-Null
    & reg delete "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\FlyoutMenuSettings" /v ShowLockOption /f 2>&1 | Out-Null
    Write-Log "关机设置菜单选项已恢复默认" "Gray"

    # 应用电源方案
    powercfg /setactive SCHEME_CURRENT 2>$null

    Write-Log "电源管理已恢复为 Windows 默认" "Green"
} catch {
    Write-Log "电源管理恢复部分失败: $_" "Yellow"
}

# ============================================================
# 5. 火绒安全 — 不作处理
# ============================================================
Write-Step "5. 火绒安全（不予卸载）"

$hrInstalled = Get-Service -Name "HipsDaemon" -ErrorAction SilentlyContinue
if ($hrInstalled) {
    Write-Log "火绒安全仍在运行，未做卸载操作（如需卸载请手动处理）" "Yellow"
} else {
    Write-Log "火绒安全未安装" "Gray"
}

# ============================================================
# 6. 重新启用 Windows 安全防护
# ============================================================
Write-Step "6. 重新启用 Windows 安全防护"

# 6.1 重新启用篡改防护
try {
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows Defender\Features" -Name "TamperProtection" -Value 5 -Type DWORD -Force -ErrorAction SilentlyContinue
    Write-Log "篡改防护已尝试恢复" "Gray"
} catch {}

# 6.2 启用防火墙
try {
    Set-NetFirewallProfile -Profile Domain,Public,Private -Enabled True -ErrorAction SilentlyContinue
    Write-Log "Windows 防火墙已启用（所有配置文件）" "Green"
} catch {
    Write-Log "启用防火墙时出错: $_" "Yellow"
}

# 6.3 启用 Defender 全面保护功能
try {
    Set-MpPreference -DisableRealtimeMonitoring $false -ErrorAction SilentlyContinue
    Set-MpPreference -DisableBehaviorMonitoring $false -ErrorAction SilentlyContinue
    Set-MpPreference -DisableBlockAtFirstSeen $false -ErrorAction SilentlyContinue
    Set-MpPreference -DisableIOAVProtection $false -ErrorAction SilentlyContinue
    Set-MpPreference -DisableIntrusionPreventionSystem $false -ErrorAction SilentlyContinue
    Set-MpPreference -DisableScriptScanning $false -ErrorAction SilentlyContinue
    Set-MpPreference -DisablePrivacyMode $false -ErrorAction SilentlyContinue
    Write-Log "Defender 实时监控/行为监控/脚本扫描/入侵防护 已启用" "Green"
} catch {
    Write-Log "启用 Defender 部分功能失败" "Yellow"
}

# 6.4 开启 SmartScreen（资源管理器 + Edge + 应用商店）
Set-RegValue -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System" -Name "EnableSmartScreen" -Value 1 -Type "DWORD"
Set-RegValue -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer" -Name "SmartScreenEnabled" -Value "RequireAdmin" -Type "String"
Set-RegValue -Path "HKLM:\SOFTWARE\Policies\Microsoft\MicrosoftEdge\PhishingFilter" -Name "EnabledV9" -Value 1 -Type "DWORD"
Remove-RegValue -Path "HKLM:\SOFTWARE\Policies\Microsoft\Edge" -Name "SmartScreenEnabled"
Remove-RegValue -Path "HKLM:\SOFTWARE\Policies\Microsoft\Edge" -Name "SmartScreenPuaEnabled"
Remove-RegValue -Path "HKLM:\SOFTWARE\Policies\Microsoft\Edge" -Name "PreventSmartScreenPromptOverride"
Remove-RegValue -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\AppHost" -Name "EnableWebContentEvaluation"
Remove-RegKey -Path "HKLM:\SOFTWARE\Policies\Microsoft\Edge"
Write-Log "SmartScreen 已全面重新启用 (资源管理器 + Edge + 应用商店)" "Green"

# 6.4b 恢复增强型钓鱼防护
Remove-RegValue -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\SmartScreen" -Name "ConfigureEnhancedPhishingProtection"
Remove-RegValue -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\SmartScreen" -Name "EnableEnhancedPhishingProtection"
Remove-RegValue -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\SmartScreen" -Name "ConfigureAppInstallControlEnabled"
Remove-RegValue -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\SmartScreen" -Name "ConfigureAppInstallControl"
Remove-RegKey -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\SmartScreen"
Remove-RegValue -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\WTDS\Settings" -Name "NotifyUnsafeApp"
Remove-RegValue -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\WTDS\Settings" -Name "NotifyPasswordReuse"
Remove-RegValue -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\WTDS\Settings" -Name "NotifyUnsafePasswordStorage"
Write-Log "增强型钓鱼防护 / 应用控制 已恢复默认" "Green"

# 6.4 开启"检查应用和文件" - 基于声誉的保护
Remove-RegValue -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies\Attachments" -Name "SaveZoneInformation"
Remove-RegValue -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Attachments" -Name "SaveZoneInformation"
Set-RegValue -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Attachments" -Name "SaveZoneInformation" -Value 2 -Type "DWORD"
Write-Log "文件信誉检查已重新启用" "Green"

# 6.5 开启"可能不需要的应用"拦截
Set-RegValue -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender" -Name "PUAProtection" -Value 1 -Type "DWORD"
Set-RegValue -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\MpEngine" -Name "MpEnablePus" -Value 1 -Type "DWORD"
Write-Log "PUA 拦截已重新启用" "Green"

# 6.6 重新启用 UAC 用户账户控制
try {
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -Name "EnableLUA" -Value 1 -Type DWORD -Force -ErrorAction SilentlyContinue
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -Name "ConsentPromptBehaviorAdmin" -Value 5 -Type DWORD -Force -ErrorAction SilentlyContinue
    Write-Log "UAC 用户账户控制已重新启用" "Green"
} catch {
    Write-Log "UAC 启用失败" "Yellow"
}

# 6.7 恢复 Defender 提交样本设置
Set-RegValue -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\Spynet" -Name "SpynetReporting" -Value 1 -Type "DWORD"
Set-RegValue -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\Spynet" -Name "SubmitSamplesConsent" -Value 0 -Type "DWORD"

# 6.8 移除禁用 Defender 的策略
Remove-RegValue -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender" -Name "DisableAntiSpyware"
Remove-RegValue -Path "HKLM:\SOFTWARE\Microsoft\Windows Defender" -Name "DisableAntiSpyware"

# 6.9 移除 WOW6432Node 篡改防护修改
Remove-RegValue -Path "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows Defender\Features" -Name "TamperProtection"

# 6.10 移除内存完整性 (HVCI/DeviceGuard) 策略
Remove-RegValue -Path "HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\HypervisorEnforcedCodeIntegrity" -Name "Enabled"
Remove-RegValue -Path "HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard" -Name "EnableVirtualizationBasedSecurity"

# 6.11 移除 Defender 实时防护/网络保护策略
Remove-RegValue -Path "HKLM:\SOFTWARE\Microsoft\Windows Defender\Real-Time Protection" -Name "DisableNetworkProtection"
Remove-RegValue -Path "HKLM:\SOFTWARE\Microsoft\Windows Defender\Real-Time Protection" -Name "DisableNIS"

# 6.12 移除 HKLM 级 AppHost 策略（HKCU 已在上面清理）
Remove-RegValue -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppHost" -Name "EnableWebContentEvaluation"

# 6.13 移除 WTDS 组件级禁用
Remove-RegValue -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WTDS\Components" -Name "ServiceEnabled"

# 6.14 移除 Edge 文件 SmartScreen 覆盖策略
Remove-RegValue -Path "HKLM:\SOFTWARE\Policies\Microsoft\Edge" -Name "PreventSmartScreenPromptOverrideForFiles"

Write-Log "Windows 安全防护已重新启用" "Green"

# ============================================================
# 7. 重新启用任务栏资讯
# ============================================================
Write-Step "7. 重新启用任务栏资讯"

Remove-RegValue -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Feeds" -Name "EnableFeeds"
Remove-RegValue -Path "HKCU:\SOFTWARE\Policies\Microsoft\Windows\Windows Feeds" -Name "EnableFeeds"
Remove-RegValue -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Feeds" -Name "ShellFeedsTaskbarViewMode"
Remove-RegValue -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Feeds" -Name "IsFeedsAvailable"
Remove-RegValue -Path "HKLM:\SOFTWARE\Microsoft\PolicyManager\default\NewsAndInterests\AllowNewsAndInterests" -Name "value"
Remove-RegValue -Path "HKLM:\SOFTWARE\Microsoft\PolicyManager\current\device\Feeds" -Name "EnableFeedsHeader"
# Win11 小组件
Remove-RegValue -Path "HKLM:\SOFTWARE\Policies\Microsoft\Dsh" -Name "AllowNewsAndInterests"
Remove-RegKey -Path "HKLM:\SOFTWARE\Policies\Microsoft\Dsh"
Remove-RegValue -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "TaskbarDa"

# 恢复 Cortana
Remove-RegValue -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search" -Name "AllowCortana"
Remove-RegValue -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search" -Name "AllowSearchToUseLocation"
Remove-RegValue -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search" -Name "DisableWebSearch"
Remove-RegValue -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search" -Name "ConnectedSearchUseWeb"

# 恢复 WpnService（Win11 小组件通知服务）
try {
    Set-Service -Name "WpnService" -StartupType Automatic -ErrorAction SilentlyContinue
    Start-Service -Name "WpnService" -ErrorAction SilentlyContinue
    Write-Log "WpnService 已恢复为 Automatic" "Gray"
} catch {
    Write-Log "恢复 WpnService 失败" "Yellow"
}

Write-Log "任务栏资讯已恢复默认" "Green"

# 重启资源管理器使任务栏修改生效
Write-Log "正在重启 Windows 资源管理器..." "Cyan"
try {
    Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 2
    Start-Process explorer -ErrorAction SilentlyContinue
    Write-Log "资源管理器已重启" "Green"
} catch {
    Write-Log "资源管理器重启失败，请手动注销或重启" "Yellow"
}

# ============================================================
# 8. 还原其他优化
# ============================================================
Write-Step "8. 还原其他系统优化"

# 8.1 恢复文件扩展名隐藏（默认）
try {
    Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "HideFileExt" -Value 1 -Type DWORD -Force
    Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "Hidden" -Value 2 -Type DWORD -Force
    Write-Log "文件扩展名和隐藏文件显示已恢复默认" "Green"
} catch {
    Write-Log "文件资源管理器设置恢复失败: $_" "Yellow"
}

# 8.2 恢复开始菜单建议内容
Remove-RegValue -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" -Name "SubscribedContent-338393Enabled"
Remove-RegValue -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" -Name "SubscribedContent-338389Enabled"

# 8.3 移除桌面"此电脑"图标（恢复默认不显示）
try {
    Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\HideDesktopIcons\NewStartPanel" -Name "{20D04FE0-3AEA-1069-A2D8-08002B30309D}" -Value 1 -Type DWORD -Force
} catch { }

# 8.4 恢复文件夹隐私设置（最近文件/常用文件夹/Office.com文件）
try {
    Remove-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "Start_TrackDocs" -Force -ErrorAction SilentlyContinue
} catch {}
try {
    Remove-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "ShowFrequent" -Force -ErrorAction SilentlyContinue
} catch {}
try {
    Remove-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer" -Name "ShowCloudFilesInQuickAccess" -Force -ErrorAction SilentlyContinue
} catch {}
try {
    Remove-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "ShowSyncProviderNotifications" -Force -ErrorAction SilentlyContinue
} catch {}
Write-Log "文件夹隐私设置已恢复默认" "Gray"

Write-Log "其他系统优化已恢复默认" "Green"

# ============================================================
# 9. 软件卸载（用户自选）
# ============================================================
Write-Step "9. 已安装软件卸载"

$canUninstall = $false
try { Add-Type -AssemblyName System.Windows.Forms, System.Drawing -ErrorAction Stop; $canUninstall = $true }
catch { Write-Log "无法加载图形界面，跳过软件卸载" "Yellow" }

if ($canUninstall) {
    # 扫描已安装软件
    $uninstallPaths = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*"
    )
    $installedApps = @{}
    foreach ($up in $uninstallPaths) {
        Get-ItemProperty -Path $up -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -and $_.UninstallString } | ForEach-Object {
            $name = $_.DisplayName
            if (-not $installedApps.ContainsKey($name)) {
                $installedApps[$name] = @{ Name=$name; Uninstall=$_.UninstallString; Publisher=$_.Publisher }
            }
        }
    }
    
    if ($installedApps.Count -gt 0) {
        # 弹窗让用户勾选
        Write-Log "[注意] 即将弹出卸载选择窗口，请在电脑上勾选要卸载的软件" "Red"
        $sf = New-Object System.Windows.Forms.Form
        $sf.Text = "选择要卸载的软件 --龙信硬件组"
        $sf.Size = New-Object System.Drawing.Size(550, 500)
        $sf.StartPosition = [System.Windows.Forms.FormStartPosition]::CenterScreen
        $sf.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::FixedDialog
        $sf.TopMost = $true
        $sf.Show(); $sf.Hide()

        $lbl = New-Object System.Windows.Forms.Label
        $lbl.Text = "系统已还原。请勾选需要额外卸载的软件（默认全不选）："
        $lbl.Location = New-Object System.Drawing.Point(12, 12)
        $lbl.Size = New-Object System.Drawing.Size(510, 22)
        $sf.Controls.Add($lbl)

        $clb = New-Object System.Windows.Forms.CheckedListBox
        $clb.Location = New-Object System.Drawing.Point(12, 38)
        $clb.Size = New-Object System.Drawing.Size(510, 330)
        $clb.CheckOnClick = $true
        $appList = $installedApps.Values | Sort-Object Name
        $appMap = @{}
        $idx = 0
        foreach ($app in $appList) {
            $label = if ($app.Publisher) { "$($app.Name)  [$($app.Publisher)]" } else { $app.Name }
            $clb.Items.Add($label) | Out-Null
            $appMap[$idx] = $app
            $idx++
        }
        $sf.Controls.Add($clb)

        $btnAll = New-Object System.Windows.Forms.Button
        $btnAll.Text = "全选"
        $btnAll.Location = New-Object System.Drawing.Point(12, 378)
        $btnAll.Size = New-Object System.Drawing.Size(90, 30)
        $btnAll.Add_Click({ for ($i = 0; $i -lt $clb.Items.Count; $i++) { $clb.SetItemChecked($i, $true) } })
        $sf.Controls.Add($btnAll)

        $btnNone = New-Object System.Windows.Forms.Button
        $btnNone.Text = "取消全选"
        $btnNone.Location = New-Object System.Drawing.Point(112, 378)
        $btnNone.Size = New-Object System.Drawing.Size(90, 30)
        $btnNone.Add_Click({ for ($i = 0; $i -lt $clb.Items.Count; $i++) { $clb.SetItemChecked($i, $false) } })
        $sf.Controls.Add($btnNone)

        $btnOK = New-Object System.Windows.Forms.Button
        $btnOK.Text = "卸载所选软件"
        $btnOK.Location = New-Object System.Drawing.Point(340, 410)
        $btnOK.Size = New-Object System.Drawing.Size(120, 35)
        $btnOK.BackColor = [System.Drawing.Color]::FromArgb(200, 50, 50)
        $btnOK.ForeColor = [System.Drawing.Color]::White
        $btnOK.DialogResult = [System.Windows.Forms.DialogResult]::OK
        $sf.Controls.Add($btnOK)
        $sf.AcceptButton = $btnOK

        $btnSkip = New-Object System.Windows.Forms.Button
        $btnSkip.Text = "跳过"
        $btnSkip.Location = New-Object System.Drawing.Point(470, 410)
        $btnSkip.Size = New-Object System.Drawing.Size(60, 35)
        $btnSkip.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
        $sf.Controls.Add($btnSkip)
        $sf.CancelButton = $btnSkip

        $result = $sf.ShowDialog()

        $toUninstall = @()
        if ($result -eq [System.Windows.Forms.DialogResult]::OK) {
            for ($i = 0; $i -lt $clb.Items.Count; $i++) {
                if ($clb.GetItemChecked($i) -and $appMap.ContainsKey($i)) {
                    $toUninstall += $appMap[$i]
                }
            }
        }
        $sf.Dispose()

        if ($toUninstall.Count -gt 0) {
            Write-Log "准备卸载 $($toUninstall.Count) 个软件..." "Cyan"
            foreach ($app in $toUninstall) {
                Write-Log "正在卸载: $($app.Name)" "Cyan"
                $uninstCmd = $app.Uninstall
                $exe = $null
                $args = ""
                $success = $false
                
                # 从注册表卸载命令中提取 exe 路径和参数
                if ($uninstCmd -match 'msiexec') {
                    $args = $uninstCmd -replace '.*msiexec\.exe\s*', ''
                    $exe = "msiexec.exe"
                } elseif ($uninstCmd -match '^\s*"([^"]+)"\s*(.*)') {
                    $exe = $Matches[1]; $args = $Matches[2].Trim()
                } elseif ($uninstCmd -match '^([a-zA-Z]:\\.*?\.exe)\s*(.*)') {
                    $exe = $Matches[1]; $args = $Matches[2].Trim()
                }
                
                if (-not $exe -or -not (Test-Path $exe)) {
                    Write-Log "  找不到卸载程序: $exe" "Red"
                    Write-Log "卸载失败: $($app.Name)（请手动在控制面板卸载）" "Red"
                    continue
                }
                
                # 弹窗提示用户手动卸载
                try {
                    Add-Type -AssemblyName System.Windows.Forms -ErrorAction Stop
                    $topForm = New-Object System.Windows.Forms.Form; $topForm.TopMost = $true; $topForm.Show(); $topForm.Hide()
                    [System.Windows.Forms.MessageBox]::Show($topForm, "正在卸载: $($app.Name)`n`n卸载程序已打开，请手动完成卸载。`n完成后点击「确定」继续。", "手动卸载 --龙信硬件组", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
                    $topForm.Dispose()
                } catch {
                    Write-Log "  弹窗失败，直接启动卸载..." "Yellow"
                }
                
                # 启动卸载程序（正常窗口，无静默参数）
                if ($exe -eq "msiexec.exe") {
                    $proc = Start-Process msiexec -ArgumentList "$args /norestart" -PassThru -WindowStyle Normal -ErrorAction SilentlyContinue
                } else {
                    $proc = Start-Process -FilePath $exe -ArgumentList $args -PassThru -WindowStyle Normal -ErrorAction SilentlyContinue
                }
                
                if ($proc) {
                    $proc.WaitForExit(300000)
                    if (-not $proc.HasExited) { try { $proc.Kill() } catch {} }
                    if ($proc.ExitCode -eq 0 -or $proc.ExitCode -eq 3010) {
                        $success = $true
                        Write-Log "卸载完成: $($app.Name)" "Green"
                    } else {
                        Write-Log "  卸载异常 (exit: $($proc.ExitCode))" "Red"
                        Write-Log "卸载失败: $($app.Name)（请手动在控制面板卸载）" "Red"
                    }
                } else {
                    Write-Log "  启动卸载程序失败" "Red"
                    Write-Log "卸载失败: $($app.Name)（请手动在控制面板卸载）" "Red"
                }
            }
        }
    } else {
        Write-Log "未检测到已安装的软件" "Yellow"
    }
}

# 刷新组策略，消除"由组织管理"状态
Write-Log "正在刷新组策略..." "Cyan"
gpupdate /force 2>&1 | Out-Null
Write-Log "组策略已刷新" "Green"

# ============================================================
# 完成
# ============================================================
Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "  系统设置已全部还原!" -ForegroundColor Green
Write-Host "  完成时间: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "注意事项:" -ForegroundColor Yellow
Write-Host "  1. 部分设置需要重启电脑后生效" -ForegroundColor Yellow
Write-Host "  2. 壁纸和锁屏已恢复为 Windows 默认" -ForegroundColor Yellow
Write-Host "  3. 火绒安全未被卸载（如需卸载请手动操作）" -ForegroundColor Yellow
Write-Host "  4. 可直接在弹出的卸载页面勾选软件进行卸载" -ForegroundColor Yellow
Write-Host "  5. Windows 更新已重新启用，可能会自动下载更新" -ForegroundColor Yellow

Save-LogFile
if (-not $NoPause) {
    Write-Host ""
    Read-Host "按 Enter 键退出..."
}
