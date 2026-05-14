# ============================================================
# 电脑出厂调试 - 系统设置脚本 v1.3
# 功能：壁纸、锁屏、电源管理、关闭更新、安全设置等
# 启动：双击 "运行_仅系统设置.bat"
# ============================================================

param([switch]$NoPause, [string]$LogPath, [switch]$SkipBlockerCheck)

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $scriptDir

$now = Get-Date -Format 'yyyyMMdd_HHmmss'
$logDir = Join-Path $scriptDir "logs"
New-Item -ItemType Directory -Path $logDir -Force | Out-Null
if ($LogPath) {
    $logFile = $LogPath
} else {
    $logFile = Join-Path $logDir "setup_${now}.log"
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
        "AI_READ_HINT: 请重点查看 [ERROR] 和 [WARN] 行、最后的 AI_ANALYSIS_BLOCK、以及问题报告 zip。",
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
    $summary = @(
        "",
        "===== AI_ANALYSIS_BLOCK =====",
        "EndTime: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')",
        "ResultSummary: STEP=$($global:logStats.STEP); OK=$($global:logStats.OK); WARN=$($global:logStats.WARN); ERROR=$($global:logStats.ERROR); INFO=$($global:logStats.INFO)",
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

$host.UI.RawUI.WindowTitle = "系统调试脚本"
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  电脑出厂调试 - 系统设置脚本 v1.2" -ForegroundColor Cyan
Write-Host "  时间: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

Write-LogHeader "system_setup.ps1" "仅系统设置"

if (-not $SkipBlockerCheck) {
# ============================================================
# 0. OEM 安全软件检测（联想/戴尔/惠普/360/腾讯管家等）
# ============================================================
Write-Step "0. 检测可能干扰的第三方安全软件"

$oemBlockers = @(
    @{Name="联想安全卫士"; Process="LenovoSafe*"; Service="LenovoSafe*"; Path="*Lenovo*Safe*"},
    @{Name="联想电脑管家"; Process="LenovoPcManager*"; Service="LenovoPCManager*"; Path="*Lenovo*PCManager*"},
    @{Name="联想杀毒"; Process="LVDaemon*"; Service="LV*"; Path="*Lenovo*Virus*"},
    @{Name="360安全卫士"; Process="360Safe*"; Service="ZhuDongFangYu"; Path="*360*"},
    @{Name="腾讯电脑管家"; Process="QQPCMgr*"; Service="QQPCRTP*"; Path="*Tencent*QQPCMgr*"},
    @{Name="金山毒霸"; Process="kxescore*"; Service="kxescore*"; Path="*kingsoft*"},
    @{Name="2345安全卫士"; Process="2345Safe*"; Service="2345Safe*"; Path="*2345*"},
    @{Name="火绒安全"; Process="HipsDaemon"; Service="HipsDaemon"; Path="*Huorong*"}
)

$blockerFound = @()
foreach ($b in $oemBlockers) {
    $found = $false
    if (Get-Process -Name $b.Process -ErrorAction SilentlyContinue) { $found = $true }
    if (Get-Service -Name $b.Service -ErrorAction SilentlyContinue) { $found = $true }
    if ($found) { $blockerFound += $b.Name; Write-Log "检测到: $($b.Name) (可能阻止系统修改)" "Yellow" }
}

if ($blockerFound.Count -gt 0) {
    $blockerNames = $blockerFound -join "`n  - "
    Write-Log "警告：检测到以下第三方安全软件，可能阻止系统设置修改:" "Red"
    foreach ($b in $blockerFound) { Write-Log "  - $b" "Red" }
    try {
        Add-Type -AssemblyName System.Windows.Forms -ErrorAction Stop
        # 循环确认：检查到火绒/安全软件仍运行就反复弹窗
        $hrResolved = $false
        while (-not $hrResolved) {
            $popupMsg = "检测到以下第三方安全软件正在运行:`n`n  $blockerNames`n`n这些软件会阻止脚本修改系统设置。必须先关闭后才能继续。`n`n"
            if ($blockerFound -contains "火绒安全") {
                $popupMsg += "【火绒安全处理步骤】`n"
                $popupMsg += "  1. 右键任务栏右下角火绒图标 → 安全设置`n"
                $popupMsg += "  2. 系统防护 → 文件实时监控 → 暂时关闭`n"
                $popupMsg += "  3. 系统防护 → 注册表防护 → 暂时关闭`n"
                $popupMsg += "  4. 设置完成后点击确认保存`n`n"
                $popupMsg += "完成后点击「我已关闭防护」继续。如果仍不行，请点「先退出」。"
            } else {
                $popupMsg += "请先暂时退出这些软件后再继续。`n`n完成后点击「我已关闭防护」继续。"
            }
            $topForm = New-Object System.Windows.Forms.Form; $topForm.TopMost = $true; $topForm.Show(); $topForm.Hide()
            $result = [System.Windows.Forms.MessageBox]::Show($topForm, $popupMsg, "安全软件警告 --龙信硬件组", [System.Windows.Forms.MessageBoxButtons]::YesNo, [System.Windows.Forms.MessageBoxIcon]::Warning)
            $topForm.Dispose()
            if ($result -eq [System.Windows.Forms.DialogResult]::No) {
                Write-Log "用户选择退出 (安全软件未处理)" "Red"
                Write-Host "按 Enter 键退出..." -ForegroundColor Red
                Save-LogFile
                Read-Host
                exit
            }
            # 再次检查安全软件是否还在运行
            $stillBlocking = @()
            foreach ($b in $oemBlockers) {
                $found = $false
                if ($b.Service -and (Get-Service -Name $b.Service -ErrorAction SilentlyContinue | Where-Object { $_.Status -eq 'Running' })) { $found = $true }
                if ($b.Process -and (Get-Process -Name $b.Process -ErrorAction SilentlyContinue)) { $found = $true }
                if ($found) { $stillBlocking += $b.Name }
            }
            if ($stillBlocking.Count -gt 0) {
                $stillNames = $stillBlocking -join "、"
                Write-Log "检测到以下安全软件仍在运行: $stillNames，继续循环确认" "Yellow"
                $retryForm = New-Object System.Windows.Forms.Form; $retryForm.TopMost = $true; $retryForm.Show(); $retryForm.Hide()
                $retryResult = [System.Windows.Forms.MessageBox]::Show($retryForm, "以下安全软件仍在运行：`n`n  $stillNames`n`n请按照上面的步骤关闭防护后再点「重试」。`n`n点「取消」可退出脚本。", "安全软件仍在运行 --龙信硬件组", [System.Windows.Forms.MessageBoxButtons]::RetryCancel, [System.Windows.Forms.MessageBoxIcon]::Exclamation)
                $retryForm.Dispose()
                if ($retryResult -eq [System.Windows.Forms.DialogResult]::Cancel) {
                    Write-Log "用户选择退出 (安全软件仍在运行)" "Red"
                    Save-LogFile; Read-Host "按 Enter 键退出..."; exit
                }
            } else {
                $hrResolved = $true
                Write-Log "安全软件已关闭防护，确认继续" "Green"
            }
        }
    } catch {
        Write-Log "无法弹出警告窗口，继续执行..." "Yellow"
    }
} else {
    Write-Log "未检测到第三方安全软件" "Green"
}
}

# ============================================================
# 1. 设置壁纸
# ============================================================
Write-Step "1. 设置壁纸"

# 修复：-Include 必须在路径带 \* 时才生效
$wallFile = Get-ChildItem -Path "$scriptDir\*" -Include "wallpaper.jpg","wallpaper.jpeg","wallpaper.png","wallpaper.bmp" -ErrorAction SilentlyContinue | Select-Object -First 1

if (-not $wallFile) {
    # 备用：直接用通配符逐个匹配
    foreach ($ext in @(".jpg",".jpeg",".png",".bmp")) {
        $testFile = Get-Item (Join-Path $scriptDir "wallpaper$ext") -ErrorAction SilentlyContinue
        if ($testFile) { $wallFile = $testFile; break }
    }
}

if ($wallFile) {
    Write-Log "找到壁纸文件: $($wallFile.Name)" "Cyan"
    
    # 先复制到系统永久目录，避免脚本文件夹删除后壁纸失效
    $wallDestDir = "$env:ProgramData\CustomAssets"
    New-Item -ItemType Directory -Path $wallDestDir -Force | Out-Null
    $wallDestPath = Join-Path $wallDestDir "wallpaper$($wallFile.Extension)"
    Copy-Item -Path $wallFile.FullName -Destination $wallDestPath -Force
    Write-Log "壁纸已复制到: $wallDestPath" "Gray"
    # 同时复制一份到用户图片文件夹，方便查看
    $picDest = Join-Path ([Environment]::GetFolderPath("MyPictures")) "自定义壁纸$($wallFile.Extension)"
    Copy-Item -Path $wallFile.FullName -Destination $picDest -Force
    Write-Log "壁纸副本保存至图片文件夹" "Gray"
    
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
        [WallpaperHelper]::SetWallpaper($wallDestPath)
        Write-Log "壁纸设置成功" "Green"
    } catch {
        try {
            Set-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name WallPaper -Value $wallDestPath -Force
            rundll32.exe user32.dll, UpdatePerUserSystemParameters, 1, $true 2>$null
            Write-Log "壁纸设置成功 (备用方案)" "Green"
        } catch {
            Write-Log "壁纸设置失败: $_" "Red"
        }
    }
} else {
    Write-Log "未找到壁纸文件，请将壁纸命名为 wallpaper.jpg/png/bmp 放在脚本同目录" "Yellow"
}

# ============================================================
# 2. 设置锁屏
# ============================================================
Write-Step "2. 设置锁屏"

$lockFile = Get-ChildItem -Path "$scriptDir\*" -Include "lockscreen.jpg","lockscreen.jpeg","lockscreen.png","lockscreen.bmp" -ErrorAction SilentlyContinue | Select-Object -First 1

if (-not $lockFile) {
    foreach ($ext in @(".jpg",".jpeg",".png",".bmp")) {
        $testFile = Get-Item (Join-Path $scriptDir "lockscreen$ext") -ErrorAction SilentlyContinue
        if ($testFile) { $lockFile = $testFile; break }
    }
}

if ($lockFile) {
    Write-Log "找到锁屏文件: $($lockFile.Name)" "Cyan"
    try {
        # 1) 复制到 CustomAssets（策略引用用）
        $lockDestDir = "$env:ProgramData\CustomAssets"
        New-Item -ItemType Directory -Path $lockDestDir -Force | Out-Null
        $lockDestPath = Join-Path $lockDestDir "lockscreen$($lockFile.Extension)"
        Copy-Item -Path $lockFile.FullName -Destination $lockDestPath -Force
        
        # 2) 同时复制到用户图片文件夹
        $picLockPath = Join-Path ([Environment]::GetFolderPath("MyPictures")) "自定义锁屏$($lockFile.Extension)"
        Copy-Item -Path $lockFile.FullName -Destination $picLockPath -Force
        
        # 3) 先禁用 Windows 聚焦 + 写注册表策略（这部分无条件执行，WinRT 失败也不影响）
        & reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v RotatingLockScreenEnabled /t REG_DWORD /d 0 /f 2>&1 | Out-Null
        & reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v RotatingLockScreenOverlayEnabled /t REG_DWORD /d 0 /f 2>&1 | Out-Null
        & reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v SubscribedContent-338387Enabled /t REG_DWORD /d 0 /f 2>&1 | Out-Null
        & reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v ContentDeliveryAllowed /t REG_DWORD /d 0 /f 2>&1 | Out-Null
        & reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v SystemPaneSuggestionsEnabled /t REG_DWORD /d 0 /f 2>&1 | Out-Null
        Write-Log "Windows 聚焦已禁用" "Gray"

        # 4) 注册表策略双保险（HKLM + HKCU 同时设）
        Set-RegValue -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Personalization" -Name "LockScreenImage" -Value $lockDestPath -Type "String"
        Set-RegValue -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Lock Screen" -Name "LockScreenImagePath" -Value $lockDestPath -Type "String"
        & reg delete "HKLM\SOFTWARE\Policies\Microsoft\Windows\Personalization" /v NoChangingLockScreen /f 2>&1 | Out-Null
        & reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\CloudContent" /v DisableWindowsConsumerFeatures /t REG_DWORD /d 1 /f 2>&1 | Out-Null
        Write-Log "注册表策略已设置" "Gray"

        # 4.1) PersonalizationCSP 系统级锁屏设置（Win10 1803+ / Win11 家庭版也适用）
        & reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\PersonalizationCSP" /v LockScreenImagePath /t REG_SZ /d "$lockDestPath" /f 2>&1 | Out-Null
        & reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\PersonalizationCSP" /v LockScreenImageUrl /t REG_SZ /d "$lockDestPath" /f 2>&1 | Out-Null
        & reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\PersonalizationCSP" /v LockScreenImageStatus /t REG_DWORD /d 1 /f 2>&1 | Out-Null
        Write-Log "PersonalizationCSP 锁屏路径已设置" "Gray"

        # 5) WinRT API 设置锁屏（单独 try-catch，失败不影响注册表设置）
        try {
            Add-Type -AssemblyName System.Runtime.WindowsRuntime -ErrorAction Stop
            $asTaskGeneric = ([System.WindowsRuntimeSystemExtensions].GetMethods() | Where-Object { $_.Name -eq 'AsTask' -and $_.GetParameters().Count -eq 1 -and $_.GetParameters()[0].ParameterType.Name -eq 'IAsyncOperation`1' })[0]
            $storageFile = [Windows.Storage.StorageFile]::GetFileFromPathAsync($lockDestPath)
            $storageFileTask = $asTaskGeneric.MakeGenericMethod([Windows.Storage.StorageFile]).Invoke($null, @($storageFile))
            $storageFileTask.Wait()
            $file = $storageFileTask.Result
            $setLockOp = [Windows.System.UserProfile.LockScreen]::SetImageFileAsync($file)
            $setLockTask = $asTaskGeneric.MakeGenericMethod([void]).Invoke($null, @($setLockOp))
            $setLockTask.Wait()
            Write-Log "锁屏已通过 WinRT API 设置成功" "Green"
        } catch {
            Write-Log "WinRT API 设置锁屏不支持（注册表策略已生效，锁屏不会再显示聚焦）" "Yellow"
        }

        # 6) 刷新组策略 + 重启资源管理器确保立刻生效
        gpupdate /force 2>&1 | Out-Null
        Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 1
        Start-Process explorer -ErrorAction SilentlyContinue
        Write-Log "锁屏设置完成" "Green"
    } catch {
        Write-Log "锁屏设置失败: $_" "Red"
    }
} else {
    Write-Log "未找到锁屏文件，请将锁屏命名为 lockscreen.jpg/png/bmp 放在脚本同目录" "Yellow"
}

# ============================================================
# 3. 关闭 Windows 更新
# ============================================================
Write-Step "3. 关闭 Windows 更新"

$wuServices = @("wuauserv", "UsoSvc", "WaaSMedicSvc", "BITS")
foreach ($svc in $wuServices) {
    try {
        Stop-Service $svc -Force -ErrorAction SilentlyContinue
        Set-Service $svc -StartupType Disabled -ErrorAction SilentlyContinue
        Write-Log "服务 $svc 已禁用" "Gray"
    } catch {
        Write-Log "禁用服务 $svc 失败: $_" "Red"
    }
}

try {
    & reg add "HKLM\SYSTEM\CurrentControlSet\Services\WaaSMedicSvc" /v "Start" /t REG_DWORD /d "4" /f 2>$null
    Write-Log "已尝试禁用 WaaSMedic 注册表项" "Gray"
} catch {
    Write-Log "无法修改 WaaSMedicSvc 注册表，可能需要手动处理" "Yellow"
}

Set-RegValue -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" -Name "NoAutoUpdate" -Value 1 -Type "DWORD"
Set-RegValue -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" -Name "AUOptions" -Value 1 -Type "DWORD"
Set-RegValue -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" -Name "NoAutoRebootWithLoggedOnUsers" -Value 1 -Type "DWORD"

$updateTasks = @(
    "\Microsoft\Windows\WindowsUpdate\Scheduled Start",
    "\Microsoft\Windows\UpdateOrchestrator\Schedule Scan",
    "\Microsoft\Windows\UpdateOrchestrator\USO_UxBroker",
    "\Microsoft\Windows\UpdateOrchestrator\Reboot"
)
foreach ($task in $updateTasks) {
    try {
        Disable-ScheduledTask -TaskName (Split-Path $task -Leaf) -TaskPath (Split-Path $task) -ErrorAction SilentlyContinue
        Write-Log "已禁用计划任务: $task" "Gray"
    } catch { }
}

Write-Log "Windows 更新已禁用" "Green"

# ============================================================
# 4. 电源管理 - 永不息屏和休眠 + 笔记本/台式机判断
# ============================================================
Write-Step "4. 电源管理 - 设置永不息屏/休眠"

# === 笔记本/台式机检测 ===
$isLaptop = $false
# 自动检测
try {
    $cs = Get-WmiObject -Class Win32_ComputerSystem -ErrorAction SilentlyContinue
    if ($cs.PCSystemType -eq 2) { $isLaptop = $true }  # 2 = Mobile (laptop)
    $battery = Get-WmiObject -Class Win32_Battery -ErrorAction SilentlyContinue
    if ($battery) { $isLaptop = $true }
} catch {}

# 弹窗确认
try {
    Add-Type -AssemblyName System.Windows.Forms -ErrorAction Stop
    $msg = "是否将电源/睡眠按钮功能都设为【关机】？`n`n（选'是'→电源/睡眠按钮全设关机）`n（选'否'→不修改按钮，仅设置永不息屏）"
    $topForm = New-Object System.Windows.Forms.Form; $topForm.TopMost = $true; $topForm.Show(); $topForm.Hide()
    $dlgResult = [System.Windows.Forms.MessageBox]::Show($topForm, $msg, "电源按钮设置 --龙信硬件组", [System.Windows.Forms.MessageBoxButtons]::YesNo, [System.Windows.Forms.MessageBoxIcon]::Question)
    $topForm.Dispose()
    # 选"是"→要设关机(台式机行为), 选"否"→不修改(笔记本行为)
    $isLaptop = ($dlgResult -eq [System.Windows.Forms.DialogResult]::No)
} catch {
    # 弹窗失败，使用自动检测结果
}
if ($isLaptop) {
    Write-Log "确认为笔记本 — 跳过合盖/电源按钮设置" "Cyan"
} else {
    Write-Log "确认为台式机 — 将设置电源按钮功能" "Cyan"
}

try {
    # === 通用设置：显示器/睡眠/休眠永不息屏 ===
    powercfg /change monitor-timeout-ac 0 2>$null
    powercfg /change monitor-timeout-dc 0 2>$null
    Write-Log "显示器超时已设为永不 (AC+DC)" "Gray"

    powercfg /change standby-timeout-ac 0 2>$null
    powercfg /change standby-timeout-dc 0 2>$null
    Write-Log "睡眠超时已设为永不 (AC+DC)" "Gray"

    powercfg /change hibernate-timeout-ac 0 2>$null
    powercfg /change hibernate-timeout-dc 0 2>$null
    Write-Log "休眠超时已设为永不 (AC+DC)" "Gray"

    powercfg /hibernate off 2>$null
    Write-Log "休眠模式已禁用" "Gray"

    if ($isLaptop) {
        # 笔记本：合盖不采取任何操作
        powercfg /setacvalueindex SCHEME_CURRENT SUB_BUTTONS LIDACTION 0 2>$null
        powercfg /setdcvalueindex SCHEME_CURRENT SUB_BUTTONS LIDACTION 0 2>$null
        Write-Log "合盖操作已设为不执行任何操作" "Gray"
    } else {
        # 台式机：电源按钮→关机，睡眠按钮→不采取操作，取消关机设置勾选
        # 按电源按钮 → 关机
        powercfg /setacvalueindex SCHEME_CURRENT SUB_BUTTONS PBUTTONACTION 3 2>$null
        # 按睡眠按钮 → 不采取任何操作
        powercfg /setacvalueindex SCHEME_CURRENT SUB_BUTTONS SBUTTONACTION 0 2>$null
        Write-Log "电源按钮→关机，睡眠按钮→不采取任何操作" "Gray"

        # 关闭快速启动（对应关机设置中"启用快速启动"取消勾选）
        & reg add "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Power" /v HiberbootEnabled /t REG_DWORD /d 0 /f 2>&1 | Out-Null

        # 取消关机设置中的所有勾选（睡眠/休眠/锁定不在电源菜单显示）
        & reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\FlyoutMenuSettings" /v ShowSleepOption /t REG_DWORD /d 0 /f 2>&1 | Out-Null
        & reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\FlyoutMenuSettings" /v ShowHibernateOption /t REG_DWORD /d 0 /f 2>&1 | Out-Null
        & reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\FlyoutMenuSettings" /v ShowLockOption /t REG_DWORD /d 0 /f 2>&1 | Out-Null
        Write-Log "快速启动已关闭，关机设置勾选已全部取消" "Green"
    }

    # 应用电源方案
    powercfg /setactive SCHEME_CURRENT 2>$null
    Write-Log "电源管理设置完成" "Green"
} catch {
    Write-Log "电源管理设置部分失败: $_" "Yellow"
}

# ============================================================
# 5. 关闭 Windows 安全防护（完整版）
# ============================================================
Write-Step "5. 关闭 Windows 安全防护"

# 6.1 先尝试关闭篡改防护（Tamper Protection），否则后续设置可能被拦截
Write-Log "正在尝试关闭篡改防护..." "Cyan"
cmd /c 'reg add "HKLM\SOFTWARE\Microsoft\Windows Defender\Features" /v TamperProtection /t REG_DWORD /d 0 /f' 2>&1 | Out-Null
cmd /c 'reg add "HKLM\SOFTWARE\WOW6432Node\Microsoft\Windows Defender\Features" /v TamperProtection /t REG_DWORD /d 0 /f' 2>&1 | Out-Null
Write-Log "已尝试通过注册表关闭篡改防护" "Gray"

# 6.2 关闭防火墙
try {
    Set-NetFirewallProfile -Profile Domain,Public,Private -Enabled False -ErrorAction SilentlyContinue
    Write-Log "Windows 防火墙已关闭 (所有配置文件)" "Green"
} catch {
    Write-Log "关闭防火墙时出错: $_" "Yellow"
}

# 6.3 禁用 Defender 全面保护功能
try {
    Set-MpPreference -DisableRealtimeMonitoring $true -ErrorAction SilentlyContinue
    Set-MpPreference -DisableBehaviorMonitoring $true -ErrorAction SilentlyContinue
    Set-MpPreference -DisableBlockAtFirstSeen $true -ErrorAction SilentlyContinue
    Set-MpPreference -DisableIOAVProtection $true -ErrorAction SilentlyContinue
    Set-MpPreference -DisableIntrusionPreventionSystem $true -ErrorAction SilentlyContinue
    Set-MpPreference -DisableScriptScanning $true -ErrorAction SilentlyContinue
    Set-MpPreference -DisablePrivacyMode $true -ErrorAction SilentlyContinue
    Write-Log "Defender 实时监控/行为监控/脚本扫描/入侵防护 已关闭" "Green"
    Write-Log "注意：若篡改防护未关闭，部分设置可能被系统拦截" "Yellow"
} catch {
    Write-Log "关闭 Defender 部分功能失败（可能被篡改防护拦截）" "Yellow"
}

# 6.4 关闭 SmartScreen — 包括资源管理器、旧版 Edge、新版 Edge、应用商店
# 资源管理器 SmartScreen
Set-RegValue -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System" -Name "EnableSmartScreen" -Value 0 -Type "DWORD"
Set-RegValue -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer" -Name "SmartScreenEnabled" -Value "Off" -Type "String"

# 旧版 Edge SmartScreen
Set-RegValue -Path "HKLM:\SOFTWARE\Policies\Microsoft\MicrosoftEdge\PhishingFilter" -Name "EnabledV9" -Value 0 -Type "DWORD"

# 新版 Chromium Edge SmartScreen
Set-RegValue -Path "HKLM:\SOFTWARE\Policies\Microsoft\Edge" -Name "SmartScreenEnabled" -Value 0 -Type "DWORD"
Set-RegValue -Path "HKLM:\SOFTWARE\Policies\Microsoft\Edge" -Name "SmartScreenPuaEnabled" -Value 0 -Type "DWORD"
Set-RegValue -Path "HKLM:\SOFTWARE\Policies\Microsoft\Edge" -Name "PreventSmartScreenPromptOverride" -Value 1 -Type "DWORD"

# Microsoft Store 应用的 SmartScreen
Set-RegValue -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\AppHost" -Name "EnableWebContentEvaluation" -Value 0 -Type "DWORD"

Write-Log "SmartScreen 已全面关闭 (资源管理器 + Edge + 应用商店)" "Green"

# 6.5 关闭"检查应用和文件" - 基于声誉的保护
Set-RegValue -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies\Attachments" -Name "SaveZoneInformation" -Value 1 -Type "DWORD"
Set-RegValue -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Attachments" -Name "SaveZoneInformation" -Value 1 -Type "DWORD"
Write-Log "文件信誉检查 / 基于声誉的保护 已关闭" "Green"

# 6.6 关闭"可能不需要的应用"拦截
Set-RegValue -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender" -Name "PUAProtection" -Value 0 -Type "DWORD"
Set-RegValue -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\MpEngine" -Name "MpEnablePus" -Value 0 -Type "DWORD"
Write-Log "PUA (可能不需要的应用) 拦截已关闭" "Green"

# 6.7 关闭 UAC 用户账户控制
try {
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -Name "EnableLUA" -Value 0 -Type DWORD -Force -ErrorAction SilentlyContinue
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -Name "ConsentPromptBehaviorAdmin" -Value 0 -Type DWORD -Force -ErrorAction SilentlyContinue
    Write-Log "UAC 用户账户控制已关闭" "Green"
} catch {
    Write-Log "UAC 关闭失败" "Yellow"
}

# 6.8 关闭 Defender 样本提交
Set-RegValue -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\Spynet" -Name "SpynetReporting" -Value 0 -Type "DWORD"
Set-RegValue -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\Spynet" -Name "SubmitSamplesConsent" -Value 2 -Type "DWORD"

# 6.9 尝试彻底禁用 Defender（此键在现代 Win10/11 上受系统保护，静默失败属正常）
Set-RegValue -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender" -Name "DisableAntiSpyware" -Value 1 -Type "DWORD"
# 下面这个键在现代 Windows 上必定失败，不再尝试
# Set-RegValue -Path "HKLM:\SOFTWARE\Microsoft\Windows Defender" -Name "DisableAntiSpyware" -Value 1 -Type "DWORD"

# 6.10 Win11 内存完整性（Memory Integrity）关闭
Write-Log "正在尝试关闭内存完整性..." "Cyan"
try {
    & reg add "HKLM\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\HypervisorEnforcedCodeIntegrity" /v "Enabled" /t REG_DWORD /d 0 /f 2>&1 | Out-Null
    & reg add "HKLM\SYSTEM\CurrentControlSet\Control\DeviceGuard" /v "EnableVirtualizationBasedSecurity" /t REG_DWORD /d 0 /f 2>&1 | Out-Null
    Write-Log "内存完整性注册表已修改" "Gray"
} catch {
    Write-Log "内存完整性关闭失败: $_" "Red"
}

# 6.11 网络防钓鱼 / NIS / 应用和浏览器控制 关闭
Write-Log "正在关闭网络防钓鱼防护..." "Cyan"
# 方法1: PowerShell API
try { Set-MpPreference -EnableNetworkProtection Disabled -ErrorAction SilentlyContinue } catch {}
try { Set-MpPreference -DisableIntrusionPreventionSystem $true -ErrorAction SilentlyContinue } catch {}
try { Set-MpPreference -DisableIOAVProtection $true -ErrorAction SilentlyContinue } catch {}
# 方法2: 组策略覆盖
& reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows Defender" /v "EnableNetworkProtection" /t REG_DWORD /d 0 /f 2>&1 | Out-Null
& reg add "HKLM\SOFTWARE\Policies\Microsoft\Microsoft Defender Antivirus" /v "EnableNetworkProtection" /t REG_DWORD /d 0 /f 2>&1 | Out-Null
# 方法3: Defender 实时保护键
& reg add "HKLM\SOFTWARE\Microsoft\Windows Defender\Real-Time Protection" /v "DisableNetworkProtection" /t REG_DWORD /d 1 /f 2>&1 | Out-Null
& reg add "HKLM\SOFTWARE\Microsoft\Windows Defender\Real-Time Protection" /v "DisableNIS" /t REG_DWORD /d 1 /f 2>&1 | Out-Null
# 方法4: NIS 服务
Set-Service -Name "WdNisSvc" -StartupType Disabled -ErrorAction SilentlyContinue
Stop-Service -Name "WdNisSvc" -Force -ErrorAction SilentlyContinue
# 方法5: SmartScreen 策略 (影响 Win11 应用和浏览器控制页)
Set-RegValue -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\SmartScreen" -Name "ConfigureAppInstallControlEnabled" -Value 0 -Type "DWORD"
Set-RegValue -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\SmartScreen" -Name "ConfigureAppInstallControl" -Value "Anywhere" -Type "String"
# 方法6: Win11 增强型钓鱼防护 (Enhanced Phishing Protection) — 这是界面开关对应的真实键
& reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows Defender\SmartScreen" /v "ConfigureEnhancedPhishingProtection" /t REG_DWORD /d 0 /f 2>&1 | Out-Null
& reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows Defender\SmartScreen" /v "EnableEnhancedPhishingProtection" /t REG_DWORD /d 0 /f 2>&1 | Out-Null
& reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\WTDS\Settings" /v "NotifyUnsafeApp" /t REG_DWORD /d 0 /f 2>&1 | Out-Null
& reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\WTDS\Settings" /v "NotifyPasswordReuse" /t REG_DWORD /d 0 /f 2>&1 | Out-Null
& reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\WTDS\Settings" /v "NotifyUnsafePasswordStorage" /t REG_DWORD /d 0 /f 2>&1 | Out-Null

# 同时写入当前登录用户的真实 HKU 注册表（防止绕过管理员账户未覆盖到）
try {
    $loggedUser = (Get-WmiObject -Class Win32_ComputerSystem -ErrorAction SilentlyContinue).UserName
    if ($loggedUser -and $loggedUser -ne $env:USERNAME) {
        $userSid = (New-Object System.Security.Principal.NTAccount($loggedUser)).Translate([System.Security.Principal.SecurityIdentifier]).Value
        & reg add "HKU\$userSid\Software\Microsoft\Windows\CurrentVersion\WTDS\Settings" /v "NotifyUnsafeApp" /t REG_DWORD /d 0 /f 2>&1 | Out-Null
        & reg add "HKU\$userSid\Software\Microsoft\Windows\CurrentVersion\WTDS\Settings" /v "NotifyPasswordReuse" /t REG_DWORD /d 0 /f 2>&1 | Out-Null
        & reg add "HKU\$userSid\Software\Microsoft\Windows\CurrentVersion\WTDS\Settings" /v "NotifyUnsafePasswordStorage" /t REG_DWORD /d 0 /f 2>&1 | Out-Null
        Write-Log "已同步写入用户 $loggedUser 的钓鱼防护设置 (SID=$userSid)" "Gray"
    } else {
        Write-Log "未检测到其他登录用户，HKU 同步跳过" "Gray"
    }
} catch {
    Write-Log "HKU 用户级钓鱼防护写入失败: $_" "Yellow"
}

# 补充：WTDS 功能开关（HKLM 系统级）
& reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\WTDS\Components" /v "ServiceEnabled" /t REG_DWORD /d 0 /f 2>&1 | Out-Null

# 补充：禁止 SmartScreen 在资源管理器中扫描下载的文件
& reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\AppHost" /v "EnableWebContentEvaluation" /t REG_DWORD /d 0 /f 2>&1 | Out-Null

# 补充：禁止 Edge 在地址栏显示安全警告
& reg add "HKLM\SOFTWARE\Policies\Microsoft\Edge" /v "PreventSmartScreenPromptOverrideForFiles" /t REG_DWORD /d 1 /f 2>&1 | Out-Null

Write-Log "网络防钓鱼 / 增强型钓鱼防护 / NIS / 应用控制 设置已修改" "Gray"
# 刷新安全中心 + 组策略，确保界面状态同步
try {
    Restart-Service -Name "SecurityHealthService" -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 1
} catch {}
gpupdate /force 2>&1 | Out-Null
Write-Log "安全中心服务已刷新 + 组策略已更新" "Gray"

# 6.12 验证关键设置是否生效
$failedSettings = @()
Write-Log "正在验证关键设置是否生效..." "Cyan"

# 先检测火绒是否接管安全防护
$hrActive = $false
$hrSvc = Get-Service -Name "HipsDaemon" -ErrorAction SilentlyContinue
if ($hrSvc -and $hrSvc.Status -eq 'Running') { $hrActive = $true }

# 检查防火墙
try {
    $fwProfile = Get-NetFirewallProfile -Profile Domain -ErrorAction SilentlyContinue
    if ($fwProfile -and $fwProfile.Enabled) { $failedSettings += "防火墙(域)"; Write-Log "  验证失败: 防火墙(域) 仍然开启" "Red" }
} catch { Write-Log "  验证异常: 防火墙检测失败 ($_)" "Yellow" }

# 检查 Defender 实时监控
try {
    $rtm = Get-MpPreference -ErrorAction SilentlyContinue | Select-Object -ExpandProperty DisableRealtimeMonitoring
    if (-not $rtm) { $failedSettings += "Defender实时监控"; Write-Log "  验证失败: Defender实时监控 仍然开启" "Red" }
} catch { Write-Log "  验证异常: Defender检测失败 ($_)" "Yellow" }

# 检查内存完整性 (修复 reg query 输出匹配)
$hvci = & reg query "HKLM\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\HypervisorEnforcedCodeIntegrity" /v Enabled 2>&1 | Out-String
if ($hvci -match '0x0\s*$' -or $hvci -match '0x0\r') {
    Write-Log "  内存完整性(HVCI): 已关闭" "Gray"
} elseif ($hvci -notmatch 'Enabled') {
    Write-Log "  内存完整性(HVCI): 注册表键不存在,可能已关闭" "Gray"
} else {
    $failedSettings += "内存完整性(HVCI)"; Write-Log "  验证失败: 内存完整性 检测到非0值" "Red"
}

# 检查网络防钓鱼 (组合检查: 首选项 + 运行状态 + 注册表)
try {
    $npPref = Get-MpPreference -ErrorAction SilentlyContinue | Select-Object -ExpandProperty EnableNetworkProtection
    $mpStatus = Get-MpComputerStatus -ErrorAction SilentlyContinue
    
    # 检查组策略是否覆盖
    $gpOverride = & reg query "HKLM\SOFTWARE\Policies\Microsoft\Windows Defender" /v EnableNetworkProtection 2>&1
    $gpBlocked = ($gpOverride -match '0x1')
    
    $npIssue = $false
    if ($npPref -eq 1) { $npIssue = $true }
    if ($gpBlocked) { $npIssue = $true; Write-Log "  发现: 组策略覆盖了网络防钓鱼设置" "Yellow" }
    
    if ($npIssue) {
        $failedSettings += "网络防钓鱼"; Write-Log "  验证失败: 网络防钓鱼防护 状态为启用 (首选项=$npPref)" "Red"
    } else {
        $msg = "  网络防钓鱼: "
        if ($npPref -eq 0) { $msg += "已关闭" }
        elseif ($npPref -eq 2) { $msg += "审计模式" }
        else { $msg += "状态=$npPref" }
        Write-Log $msg "Gray"
    }
    
    # 额外: 检查 NIS(网络检查系统)
    if ($mpStatus -and $mpStatus.NISEnabled -eq $true) {
        $failedSettings += "NIS网络检查"; Write-Log "  验证失败: NIS(网络检查系统) 仍在运行" "Red"
    }
    
    # 检查增强型钓鱼防护 (Win11 界面"网络钓鱼防护"开关)
    $enhancedPhish = & reg query "HKLM\SOFTWARE\Policies\Microsoft\Windows Defender\SmartScreen" /v ConfigureEnhancedPhishingProtection 2>&1
    if ($enhancedPhish -match '0x1') { $failedSettings += "增强型钓鱼防护"; Write-Log "  验证失败: 增强型钓鱼防护(组策略) 仍启用" "Red" }
    $enhancedPhish2 = & reg query "HKLM\SOFTWARE\Policies\Microsoft\Windows Defender\SmartScreen" /v EnableEnhancedPhishingProtection 2>&1
    if ($enhancedPhish2 -match '0x1') { $failedSettings += "增强型钓鱼防护2"; Write-Log "  验证失败: 增强型钓鱼防护(备用键) 仍启用" "Red" }
} catch { Write-Log "  验证异常: 网络保护检测失败 ($_)" "Yellow" }

if ($failedSettings.Count -gt 0) {
    Write-Log "以下设置未能成功关闭: $($failedSettings -join ', ')" "Red"
    # 检查篡改防护状态
    $tamperOn = $false
    $tpCheck = & reg query "HKLM\SOFTWARE\Microsoft\Windows Defender\Features" /v TamperProtection 2>&1
    if ($tpCheck -match '0x[1-9a-fA-F]') { $tamperOn = $true }
    try {
        Add-Type -AssemblyName System.Windows.Forms -ErrorAction Stop
        $failList = $failedSettings -join "`n    "
        $popupMsg = "以下安全设置未能成功关闭:`n`n    $failList`n`n可能原因:"
        if ($tamperOn) { $popupMsg += "`n  0. 篡改防护(防篡改) 仍在启用 — 会阻止任何安全设置修改！" }
        $popupMsg += "`n  1. 第三方安全软件(联想安全卫士/360等)阻止`n  2. 系统组策略覆盖"
        if (-not $tamperOn) { $popupMsg += "`n  3. Windows 安全中心篡改防护未关" }
        if ($hrActive) { $popupMsg += "`n`n  ** 火绒安全已运行，部分设置可能由其接管 **" }
        $popupMsg += "`n`n选择: 是 = 继续执行，否 = 退出脚本"
        $topForm = New-Object System.Windows.Forms.Form; $topForm.TopMost = $true; $topForm.Show(); $topForm.Hide()
        $result = [System.Windows.Forms.MessageBox]::Show($topForm, $popupMsg, "安全设置验证 --龙信硬件组", [System.Windows.Forms.MessageBoxButtons]::YesNo, [System.Windows.Forms.MessageBoxIcon]::Warning)
        $topForm.Dispose()
        if ($result -eq [System.Windows.Forms.DialogResult]::No) {
            Write-Log "用户选择退出 (设置未完全生效)" "Red"
            Save-LogFile
            Read-Host "按 Enter 键退出..."
            exit
        }
        Write-Log "用户确认继续" "Yellow"
    } catch {
        Write-Log "无法弹出验证窗口，继续执行..." "Yellow"
    }
} else {
    $okMsg = "所有关键安全设置均已验证通过"
    if ($hrActive) { $okMsg += "（火绒正在运行，安全由火绒接管）" }
    Write-Log $okMsg "Green"
    if ($hrActive) { Write-Log "火绒安全已在运行" "Cyan" }
}

Write-Log "Windows 安全防护全面设置完成" "Green"

# ============================================================
# 6. 关闭任务栏资讯与兴趣 — 多方案级联
# ============================================================
Write-Step "6. 关闭任务栏资讯和兴趣"

$taskbarClosed = $false

# 操作系统检测
$winVer = (Get-CimInstance -ClassName Win32_OperatingSystem).Version
$isWin11 = [version]$winVer -ge [version]"10.0.22000"
if ($isWin11) { Write-Log "检测到 Win11 系统，先禁用 WpnService + 卸载小组件..." "Cyan" } else { Write-Log "检测到 Win10 系统" "Cyan" }

# Win11 专属：禁用 WpnService + 卸载小组件应用包
if ($isWin11) {
    try {
        Stop-Service -Name "WpnService" -Force -ErrorAction SilentlyContinue
        & reg add "HKLM\SYSTEM\CurrentControlSet\Services\WpnService" /v Start /t REG_DWORD /d 4 /f 2>&1 | Out-Null
        Write-Log "Win11 WpnService 已禁用" "Gray"
    } catch {}
    try {
        Get-AppxPackage -Name "MicrosoftWindows.Client.WebExperience" -AllUsers -ErrorAction SilentlyContinue | Remove-AppxPackage -ErrorAction SilentlyContinue
        Write-Log "Win11 小组件应用包已卸载" "Gray"
    } catch {
        Write-Log "小组件应用包卸载失败（可能已移除）" "Gray"
    }
}

# 方案1: Win11 主策略 Dsh（控制小组件）
Write-Log "方案1: 写入 Win11 Dsh 策略..." "Gray"
reg.exe add "HKLM\SOFTWARE\Policies\Microsoft\Dsh" /v AllowNewsAndInterests /t REG_DWORD /d 0 /f 2>&1 | Out-Null
reg.exe query "HKLM\SOFTWARE\Policies\Microsoft\Dsh" /v AllowNewsAndInterests 2>&1 | Out-Null
if ($LASTEXITCODE -eq 0) { Write-Log "Win11 Dsh 策略已生效" "Green"; $taskbarClosed = $true }

# 方案2: Win10 主策略 Windows Feeds
if (-not $taskbarClosed) {
    Write-Log "方案2: 写入 Win10 Feeds 策略..." "Gray"
    foreach ($hive in @("HKCU","HKLM")) {
        reg.exe add "$hive\SOFTWARE\Policies\Microsoft\Windows\Windows Feeds" /v EnableFeeds /t REG_DWORD /d 0 /f 2>&1 | Out-Null
    }
    reg.exe query "HKCU\SOFTWARE\Policies\Microsoft\Windows\Windows Feeds" /v EnableFeeds 2>&1 | Out-Null
    if ($LASTEXITCODE -eq 0) { Write-Log "Win10 Feeds 策略已生效" "Green"; $taskbarClosed = $true }
}

# 方案3: 禁用 Windows Feeds 计划任务
if (-not $taskbarClosed) {
    Write-Log "方案3: 禁用资讯任务..." "Gray"
    Get-ScheduledTask -TaskPath "\Microsoft\Windows\Windows Feeds\" -ErrorAction SilentlyContinue | ForEach-Object {
        try { Disable-ScheduledTask -TaskName $_.TaskName -TaskPath "\Microsoft\Windows\Windows Feeds\" -ErrorAction SilentlyContinue } catch {}
    }
    Get-ScheduledTask -TaskPath "\Microsoft\Windows\Feeds\" -ErrorAction SilentlyContinue | ForEach-Object {
        try { Disable-ScheduledTask -TaskName $_.TaskName -TaskPath "\Microsoft\Windows\Feeds\" -ErrorAction SilentlyContinue } catch {}
    }
    Write-Log "已尝试禁用计划任务" "Cyan"
}

# 方案4: 直接写 Feeds 视图模式 = 2（关闭）
if (-not $taskbarClosed) {
    Write-Log "方案4: 直接关闭 Feeds 视图..." "Gray"
    reg.exe add "HKCU\Software\Microsoft\Windows\CurrentVersion\Feeds" /v ShellFeedsTaskbarViewMode /t REG_DWORD /d 2 /f 2>&1 | Out-Null
    reg.exe add "HKCU\Software\Microsoft\Windows\CurrentVersion\Feeds" /v IsFeedsAvailable /t REG_DWORD /d 0 /f 2>&1 | Out-Null
    reg.exe add "HKLM\SOFTWARE\Microsoft\PolicyManager\default\NewsAndInterests\AllowNewsAndInterests" /v value /t REG_DWORD /d 0 /f 2>&1 | Out-Null
}

# 刷新组策略 + 重启 Explorer
gpupdate /force 2>&1 | Out-Null
Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 1
Start-Process explorer -ErrorAction SilentlyContinue

# 最终判断
if ($taskbarClosed) {
    Write-Log "资讯和兴趣已通过策略禁用" "Green"
} else {
    Write-Log "自动关闭失败，请手动操作" "Yellow"
    try {
        Add-Type -AssemblyName System.Windows.Forms -ErrorAction Stop
        $infoMsg = "自动关闭未成功，请选择一种方法手动操作：`n`n"
        $infoMsg += "  方法1：右键任务栏空白处 → 资讯和兴趣 → 关闭`n`n"
        $infoMsg += "  方法2：设置 → 个性化 → 任务栏 → 关闭`n`n"
        $infoMsg += "  方法3：Win+R 输入 gpedit.msc → 计算机配置 →`n"
        $infoMsg += "        管理模板 → Windows组件 → 资讯和兴趣 →`n"
        $infoMsg += "        启用【禁用Windows资讯和兴趣】`n`n"
        $infoMsg += "  Win11：右键任务栏 → 任务栏设置 → 小组件 → 关闭`n`n"
        $infoMsg += '操作完成后点击「确定」继续。'
        $topForm = New-Object System.Windows.Forms.Form; $topForm.TopMost = $true; $topForm.Show(); $topForm.Hide()
        [System.Windows.Forms.MessageBox]::Show($topForm, $infoMsg, "关闭任务栏资讯 --龙信硬件组", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
        $topForm.Dispose()
        Write-Log "用户确认已手动完成操作" "Green"
    } catch {
        Write-Log "请手动：右键任务栏 → 资讯和兴趣 → 关闭" "Yellow"
    }
}

# ============================================================
# 7. 其他优化
# ============================================================
Write-Step "7. 其他系统优化"

try {
    Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "HideFileExt" -Value 0 -Type DWORD -Force
    Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "Hidden" -Value 1 -Type DWORD -Force
    Write-Log "已启用文件扩展名显示和隐藏文件显示" "Green"
} catch {
    Write-Log "文件资源管理器设置失败: $_" "Yellow"
}

Set-RegValue -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" -Name "SubscribedContent-338393Enabled" -Value 0 -Type "DWORD"
Set-RegValue -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" -Name "SubscribedContent-338389Enabled" -Value 0 -Type "DWORD"

try {
    Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\HideDesktopIcons\NewStartPanel" -Name "{20D04FE0-3AEA-1069-A2D8-08002B30309D}" -Value 0 -Type DWORD -Force
} catch { }

# 文件夹选项隐私设置
try {
    Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "Start_TrackDocs" -Value 0 -Type DWORD -Force
} catch {}
try {
    Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "ShowFrequent" -Value 0 -Type DWORD -Force
} catch {}
try {
    Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer" -Name "ShowCloudFilesInQuickAccess" -Value 0 -Type DWORD -Force
} catch {}
try {
    Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "ShowSyncProviderNotifications" -Value 0 -Type DWORD -Force
} catch {}
Write-Log "文件夹隐私已关闭 (最近文件/常用文件夹/Office.com文件)" "Green"

# ============================================================
# 8. 自动安装 USB 驱动 (android_winusb.inf)
# ============================================================
Write-Step "8. USB 驱动安装"
$infPath = Join-Path $scriptDir "software\usb_driver\android_winusb.inf"
if (Test-Path $infPath) {
    Write-Log "正在安装 USB 驱动..." "Cyan"
    pnputil /add-driver "$infPath" /install 2>&1 | Out-Null
    if ($LASTEXITCODE -eq 0 -or $LASTEXITCODE -eq 3010) {
        Write-Log "USB 驱动安装成功" "Green"
    } else {
        Write-Log "USB 驱动安装可能失败 (exit $LASTEXITCODE)，请手动安装" "Red"
    }
} else {
    Write-Log "未找到 USB 驱动文件 (software\usb_driver\android_winusb.inf)，跳过" "Yellow"
}

# ============================================================
# 9. Windows 激活状态检测
# ============================================================
Write-Step "9. Windows 激活状态检测"

$activated = $false

# 检测激活状态
Write-Log "正在检测 Windows 激活状态..." "Cyan"
try {
    $lic = Get-CimInstance -ClassName SoftwareLicensingProduct -Filter "Name like 'Windows%' and PartialProductKey is not null and LicenseStatus = 1" -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($lic) {
        $activated = $true
        Write-Log "Windows 已激活 (LicenseStatus=1)" "Green"
    } else {
        # 备用：slmgr 方式检测
        $slmgrOutput = & cscript.exe //Nologo "$env:SystemRoot\System32\slmgr.vbs" /xpr 2>&1 | Out-String
        if ($slmgrOutput -match 'permanently activated|已永久激活') {
            $activated = $true
            Write-Log "Windows 已激活 (slmgr 确认)" "Green"
        } else {
            Write-Log "Windows 未激活" "Yellow"
        }
    }
} catch {
    Write-Log "激活检测出错: $_" "Red"
}

# 未激活 → 尝试内置 KMS 激活
if (-not $activated) {
    Write-Log "尝试内置 KMS 激活..." "Cyan"
    try {
        & cscript.exe //Nologo "$env:SystemRoot\System32\slmgr.vbs" /skms kms.03k.org 2>&1 | Out-Null
        Start-Sleep -Seconds 2
        & cscript.exe //Nologo "$env:SystemRoot\System32\slmgr.vbs" /ato 2>&1 | Out-Null
        Start-Sleep -Seconds 5
        $lic2 = Get-CimInstance -ClassName SoftwareLicensingProduct -Filter "Name like 'Windows%' and PartialProductKey is not null and LicenseStatus = 1" -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($lic2) {
            $activated = $true
            Write-Log "内置 KMS 激活成功" "Green"
        } else {
            Write-Log "内置 KMS 激活未成功，尝试使用激活工具..." "Yellow"
        }
    } catch {
        Write-Log "内置 KMS 激活出错: $_" "Red"
    }
}

# 内置方法失败 → 使用 HEU_KMS_Activator
if (-not $activated) {
    Write-Log "查找激活工具..." "Cyan"

    # 暂停 Defender 实时防护（防止误删激活工具）
    try {
        Set-MpPreference -DisableRealtimeMonitoring $true -ErrorAction SilentlyContinue
        Write-Log "已暂停 Defender 实时防护" "Gray"
    } catch {}

    $activator = $null

    # 方法1：在 software 文件夹中查找 HEU 激活器
    $activator = Get-ChildItem -Path "$scriptDir\software\*" -Include "*HEU*","*KMS*Activator*","*jihuo*","*激活*" -ErrorAction SilentlyContinue |
        Where-Object { $_.Extension -match '\.(exe|cmd|bat)$' -and -not ($_.Name -match 'chrome|HiSuite|Honor|iTunes|WPS|burnaware|setup|vcredist|Huorong|火绒|Hips') } |
        Select-Object -First 1

    # 备用遍历
    if (-not $activator) {
        $allExes = Get-ChildItem -Path "$scriptDir\software\*" -Include "*.exe" -ErrorAction SilentlyContinue
        foreach ($exe in $allExes) {
            if ($exe.Name -match '(?i)(HEU|KMS.*Activ|激活.*工具|jihuo)') {
                $activator = $exe; break
            }
        }
    }

    # 方法2：从 jihuo.zip 解压
    if (-not $activator) {
        $zipPath = Join-Path $scriptDir "software\jihuo.zip"
        if (Test-Path $zipPath) {
            Write-Log "找到 jihuo.zip，正在解压..." "Cyan"
            try {
                $extractDir = Join-Path $env:TEMP "jihuo_activator"
                Remove-Item -Path $extractDir -Recurse -Force -ErrorAction SilentlyContinue
                Expand-Archive -Path $zipPath -DestinationPath $extractDir -Force
                $activator = Get-ChildItem -Path "$extractDir\*" -Include "*.exe","*.cmd","*.bat" -ErrorAction SilentlyContinue |
                    Where-Object { $_.Name -match '(?i)(HEU|KMS|Activ|激活)' } |
                    Select-Object -First 1
                if ($activator) {
                    Write-Log "从 jihuo.zip 提取到激活工具: $($activator.Name)" "Green"
                }
            } catch {
                Write-Log "解压 jihuo.zip 失败: $_" "Red"
            }
        }
    }

    if ($activator) {
        Write-Log "找到激活工具: $($activator.Name)" "Cyan"

        # 第一尝试：智能激活
        Write-Log "尝试智能激活 (/smart /nologo)..." "Gray"
        try {
            $proc = Start-Process -FilePath $activator.FullName -ArgumentList "/smart /nologo" -Wait -PassThru -WindowStyle Hidden -ErrorAction SilentlyContinue
            Start-Sleep -Seconds 8
            $lic3 = Get-CimInstance -ClassName SoftwareLicensingProduct -Filter "Name like 'Windows%' and PartialProductKey is not null and LicenseStatus = 1" -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($lic3) {
                $activated = $true
                Write-Log "激活成功 (智能激活)" "Green"
            }
        } catch {
            Write-Log "智能激活出错: $_" "Red"
        }

        # 第二尝试：KMS38 激活
        if (-not $activated) {
            Write-Log "尝试 KMS38 激活 (/kms38 /nologo)..." "Gray"
            try {
                $proc = Start-Process -FilePath $activator.FullName -ArgumentList "/kms38 /nologo" -Wait -PassThru -WindowStyle Hidden -ErrorAction SilentlyContinue
                Start-Sleep -Seconds 8
                $lic4 = Get-CimInstance -ClassName SoftwareLicensingProduct -Filter "Name like 'Windows%' and PartialProductKey is not null and LicenseStatus = 1" -ErrorAction SilentlyContinue | Select-Object -First 1
                if ($lic4) {
                    $activated = $true
                    Write-Log "激活成功 (KMS38)" "Green"
                }
            } catch {
                Write-Log "KMS38 激活出错: $_" "Red"
            }
        }

        if (-not $activated) {
            Write-Log "激活工具运行完毕但未能确认激活状态，请重启后检查" "Yellow"
            Write-Log "  可手动双击运行: $($activator.Name)" "Yellow"
        }
    } else {
        Write-Log "未找到激活工具" "Red"
        Write-Log "  请将 HEU_KMS_Activator*.exe 或 jihuo.zip 放入 software 文件夹" "Red"
        Write-Log "  或手动运行激活工具后重启本脚本" "Red"
    }

    # 恢复 Defender 实时防护
    try {
        Set-MpPreference -DisableRealtimeMonitoring $false -ErrorAction SilentlyContinue
    } catch {}
}

# ============================================================
# 完成
# ============================================================
Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "  系统设置全部完成!" -ForegroundColor Green
Write-Host "  完成时间: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "注意事项:" -ForegroundColor Yellow
Write-Host "  1. 部分设置需要重启电脑后完全生效" -ForegroundColor Yellow
Write-Host "  2. 如篡改防护未被成功关闭，Defender 部分功能可能仍开启" -ForegroundColor Yellow
Write-Host "  3. 如需安装火绒安全，请在完整安装中勾选" -ForegroundColor Yellow
Write-Host "  4. 如需恢复更新，运行 '运行_还原设置.bat'" -ForegroundColor Yellow

Save-LogFile
if (-not $NoPause) {
    Write-Host ""
    Read-Host "按 Enter 键退出..."
}
