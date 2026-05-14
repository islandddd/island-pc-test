# ============================================================
# 电脑出厂调试 - 完整脚本（系统设置 + 软件安装）
# 功能：壁纸、锁屏、电源管理、关闭更新、安全设置、批量软件安装
# 运行：右键此文件 -> "使用PowerShell运行" 或以管理员身份
# ============================================================

param([switch]$NoPause, [string]$InstallList, [string]$LogPath, [switch]$SkipBlockerCheck)

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $scriptDir

$now = Get-Date -Format 'yyyyMMdd_HHmmss'
$logDir = Join-Path $scriptDir "logs"
New-Item -ItemType Directory -Path $logDir -Force | Out-Null
if ($LogPath) {
    $logFile = $LogPath
} else {
    $logFile = Join-Path $logDir "fullsetup_${now}.log"
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
    $installListInfo = if ($InstallList) { "SelectedInstallers=$($InstallList -split '\|' | Measure-Object | Select-Object -ExpandProperty Count)" } else { "SelectedInstallers=auto-scan" }
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
        "Parameters: NoPause=$NoPause; LogPath=$LogPath; $installListInfo",
        "AI_READ_HINT: 请重点查看 [ERROR] 和 [WARN] 行、软件安装统计、最后的 AI_ANALYSIS_BLOCK、以及问题报告 zip。",
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
    $installSummary = if (Get-Variable -Name installers -ErrorAction SilentlyContinue) {
        "InstallSummary: Found=$($installers.Count); Skipped=$skippedCount; NewInstalled=$newInstalledCount; Failed=$failedCount"
    } else {
        "InstallSummary: 软件安装阶段未开始"
    }
    $summary = @(
        "",
        "===== AI_ANALYSIS_BLOCK =====",
        "EndTime: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')",
        "ResultSummary: STEP=$($global:logStats.STEP); OK=$($global:logStats.OK); WARN=$($global:logStats.WARN); ERROR=$($global:logStats.ERROR); INFO=$($global:logStats.INFO)",
        $installSummary,
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

# ============================================================
# 软件检测函数：通过注册表判断软件是否已安装
# ============================================================
function Test-SoftwareInstalled {
    param([string]$InstallerFileName)
    
    $baseName = [System.IO.Path]::GetFileNameWithoutExtension($InstallerFileName)
    $keywords = $baseName -split '[_\-\s.]+' | Where-Object { $_.Length -ge 3 } | Select-Object -Unique
    
    $uninstallPaths = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*"
    )
    
    foreach ($uninstallPath in $uninstallPaths) {
        try {
            $items = Get-ItemProperty -Path $uninstallPath -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName }
            foreach ($item in $items) {
                $displayName = $item.DisplayName
                foreach ($kw in $keywords) {
                    if ($displayName -like "*$kw*") {
                        Write-Log "检测到已安装: $displayName (匹配: $kw)" "Gray"
                        return $true
                    }
                }
            }
        } catch { }
    }
    return $false
}

function Show-HiSuitePopup {
    if (-not ([System.Windows.Forms.Form] -eq $null)) { } else { Add-Type -AssemblyName System.Windows.Forms, System.Drawing -ErrorAction Stop }
    try { $dpiGraphics = [System.Drawing.Graphics]::FromHwnd([IntPtr]::Zero); $scale = [math]::Max($dpiGraphics.DpiX, $dpiGraphics.DpiY) / 96.0; $dpiGraphics.Dispose() } catch { $scale = 1.0 }
    $form = New-Object System.Windows.Forms.Form
    $form.Text = "手机助手安装完成 --龙信硬件组"
    $form.Size = New-Object System.Drawing.Size([math]::Round(520 * $scale), [math]::Round(360 * $scale))
    $form.StartPosition = [System.Windows.Forms.FormStartPosition]::CenterScreen
    $form.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::FixedDialog
    $form.MaximizeBox = $false
    $form.MinimizeBox = $false
    $form.TopMost = $true
    $form.BackColor = [System.Drawing.Color]::White
    $form.ShowInTaskbar = $false
    $form.Show(); $form.Hide()

    $title = New-Object System.Windows.Forms.Label
    $title.Text = "? 请关闭设备连接自动启动"
    $title.Font = New-Object System.Drawing.Font("Microsoft YaHei", [math]::Round(18 * $scale), [System.Drawing.FontStyle]::Bold)
    $title.ForeColor = [System.Drawing.Color]::FromArgb(200, 40, 40)
    $title.Size = New-Object System.Drawing.Size([math]::Round(480 * $scale), [math]::Round(40 * $scale))
    $title.Location = New-Object System.Drawing.Point([math]::Round(20 * $scale), [math]::Round(20 * $scale))
    $title.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
    $form.Controls.Add($title)

    $body = New-Object System.Windows.Forms.Label
    $body.Text = "华为/荣耀手机助手已安装成功`n`n请手动关闭设备连接自动启动：`n`n  1. 打开手机助手`n  2. 点击「设置」`n  3. 取消勾选「设备连接时自动启动」`n  4. 点击「确定」保存"
    $body.Font = New-Object System.Drawing.Font("Microsoft YaHei", [math]::Round(11 * $scale))
    $body.Size = New-Object System.Drawing.Size([math]::Round(470 * $scale), [math]::Round(190 * $scale))
    $body.Location = New-Object System.Drawing.Point([math]::Round(25 * $scale), [math]::Round(75 * $scale))
    $form.Controls.Add($body)

    $btn = New-Object System.Windows.Forms.Button
    $btn.Text = "我知道了"
    $btn.Font = New-Object System.Drawing.Font("Microsoft YaHei", [math]::Round(12 * $scale), [System.Drawing.FontStyle]::Bold)
    $btn.Size = New-Object System.Drawing.Size([math]::Round(160 * $scale), [math]::Round(42 * $scale))
    $btn.Location = New-Object System.Drawing.Point([math]::Round(180 * $scale), [math]::Round(275 * $scale))
    $btn.BackColor = [System.Drawing.Color]::FromArgb(30, 105, 190)
    $btn.ForeColor = [System.Drawing.Color]::White
    $btn.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $btn.Add_Click({ $form.Close() })
    $form.Controls.Add($btn)

    $form.AcceptButton = $btn
    $form.ShowDialog()
    $form.Dispose()
}

#region Auto-elevate
if (-not (Test-Admin)) {
    Write-Host "需要管理员权限，正在重新启动..." -ForegroundColor Yellow
    Start-Sleep -Seconds 1
    Start-Process powershell -Verb RunAs -ArgumentList "-ExecutionPolicy Bypass -File `"$PSCommandPath`""
    exit
}

# ============================================================
# 头部信息
# ============================================================
$host.UI.RawUI.WindowTitle = "电脑出厂调试 - 完整脚本"
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  电脑出厂调试 - 完整脚本 v1.1" -ForegroundColor Cyan
Write-Host "  系统设置 + 软件安装" -ForegroundColor Cyan
Write-Host "  时间: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

Write-LogHeader "full_setup.ps1" "完整安装"

# ============================================================
# 第一部分：执行系统设置脚本
# ============================================================
Write-Step "第一阶段：系统设置"

$systemSetupPath = Join-Path $scriptDir "system_setup.ps1"
if (Test-Path $systemSetupPath) {
    Write-Log "正在调用系统设置脚本: system_setup.ps1" "Cyan"
    & $systemSetupPath -NoPause -LogPath $logFile -SkipBlockerCheck:$SkipBlockerCheck -ErrorAction Continue
    Write-Log "系统设置脚本执行完毕" "Green"
} else {
    Write-Log "警告: 未找到 system_setup.ps1，跳过系统设置部分" "Yellow"
    Write-Log "请确保 system_setup.ps1 与本脚本在同一目录" "Yellow"
}

# ============================================================
# 第二部分：软件安装
# ============================================================
Write-Step "第二阶段：软件安装"

# 获取所有可安装文件
if ($InstallList) {
    # GUI 传入了指定安装列表（管道符分隔的路径）
    $installers = $InstallList -split '\|' | ForEach-Object { Get-Item $_ -ErrorAction SilentlyContinue } | Where-Object { $_ } | Sort-Object Name
    Write-Log "从勾选列表读取 $($installers.Count) 个安装文件" "Cyan"
} else {
    # 自动扫描 software 文件夹（排除脚本和图片）
    $scriptNames = @(
        [System.IO.Path]::GetFileName($PSCommandPath),
        "system_setup.ps1",
        "full_setup.ps1"
    )
    $firewallNames = @("wallpaper.jpg","wallpaper.jpeg","wallpaper.png","wallpaper.bmp",
                        "lockscreen.jpg","lockscreen.jpeg","lockscreen.png","lockscreen.bmp")
    $softwareDir = Join-Path $scriptDir "software"
    if (Test-Path $softwareDir) {
        $installers = @(Get-ChildItem -Path "$softwareDir\*" -Include "*.exe","*.msi" -ErrorAction SilentlyContinue |
            Where-Object {
                $name = $_.Name
                -not ($scriptNames -contains $name) -and
                -not ($firewallNames -contains $name)
            } |
            Sort-Object Name)
    } else {
        $installers = @()
        Write-Log "未找到 software 文件夹" "Yellow"
    }
}

if ($installers.Count -eq 0) {
    Write-Log "未找到任何可安装的软件文件" "Yellow"
    Write-Log "(请将 .exe 或 .msi 安装程序放入 software 文件夹)" "Yellow"
} else {
    Write-Log "找到 $($installers.Count) 个安装文件" "Cyan"
    Write-Host ""
    
    $skippedCount = 0
    $failedCount = 0
    $newInstalledCount = 0
    $global:abortInstall = $false
    
    foreach ($installer in $installers) {
        Write-Host ""
        Write-Host "----------------------------------------" -ForegroundColor DarkGray
        Write-Log "处理: $($installer.Name)" "Cyan"
        
        # 检查是否已安装
        if (Test-SoftwareInstalled -InstallerFileName $installer.Name) {
            Write-Log "已安装，跳过 (检测到匹配的已安装程序)" "Yellow"
            $skippedCount++
            continue
        }
        
        # === 定义安装方法 ===
        $methods = @()
        if ($installer.Extension -eq ".msi") {
            $methods = @(
                @{Name="静默安装(带进度条)"; Args="/i `"$($installer.FullName)`" /passive /norestart"; Exe="msiexec.exe"},
                @{Name="静默安装(完全后台)"; Args="/i `"$($installer.FullName)`" /quiet /norestart"; Exe="msiexec.exe"}
            )
        } else {
            $methods = @(
                @{Name="进度安装(可见进度条，自动完成)"; Args="/SILENT /NORESTART /SP-"; Exe=$installer.FullName},
                @{Name="静默安装1(后台自动)"; Args="/S /NCRC"; Exe=$installer.FullName},
                @{Name="静默安装2(深度静默)"; Args="/VERYSILENT /SUPPRESSMSGBOXES /NORESTART /SP-"; Exe=$installer.FullName}
            )
        }
        
        $installed = $false
        $methodIndex = 0
        $totalMethods = $methods.Count
        
        # 龙信手机驱动跳过所有静默尝试，直接弹手动安装
        if ($installer.Name -match '龙信手机驱动') {
            Write-Log "检测到龙信手机驱动，直接启动手动安装" "Cyan"
            $totalMethods = 0
        }
        
        while ($methodIndex -lt $totalMethods -and -not $installed) {
            $method = $methods[$methodIndex]
            $methodIndex++
            
            Write-Log "  [$methodIndex/$totalMethods] 尝试: $($method.Name)" "Gray"
            
            try {
                $proc = Start-Process -FilePath $method.Exe -ArgumentList $method.Args -PassThru -WindowStyle Normal -ErrorAction SilentlyContinue
                if ($proc) {
                    $proc.WaitForExit(120000)
                    if (-not $proc.HasExited) {
                        try { $proc.Kill() } catch {}
                        Write-Log "  安装超时 (120秒)，已终止" "Yellow"
                        continue
                    }
                }
                
                # 防自动重启：每次安装后立即取消任何待定的系统重启
                shutdown /a 2>$null
                Stop-Process -Name "wscript","cscript" -Force -ErrorAction SilentlyContinue
                
                if ($proc -and ($proc.ExitCode -eq 0 -or $proc.ExitCode -eq 3010)) {
                    Write-Log "安装完成!" "Green"
                    $newInstalledCount++
                    $installed = $true
                    
                    # burnaware 安装后立即重命名桌面快捷方式
                    if ($installer.Name -match '(?i)burnaware') {
                        Write-Log "检测到 burnaware，正在重命名桌面快捷方式..." "Cyan"
                        $desktopPaths = @([Environment]::GetFolderPath("CommonDesktopDirectory"), [Environment]::GetFolderPath("Desktop"))
                        foreach ($desk in $desktopPaths) {
                            $shortcut = Get-ChildItem -Path $desk -Filter "*burnaware*.lnk" -ErrorAction SilentlyContinue | Select-Object -First 1
                            if ($shortcut) {
                                $newName = Join-Path $desk "案件数据专用刻录软件.lnk"
                                if ($shortcut.Name -eq "案件数据专用刻录软件.lnk") {
                                    Write-Log "快捷名称已为'案件数据专用刻录软件'" "Green"
                                    break
                                }
                                if (Test-Path $newName) { Remove-Item $newName -Force }
                                try {
                                    Rename-Item -Path $shortcut.FullName -NewName "案件数据专用刻录软件.lnk" -Force -ErrorAction Stop
                                    Write-Log "快捷方式已重命名: $($shortcut.Name) → 案件数据专用刻录软件" "Green"
                                } catch {
                                    Write-Log "快捷方式重命名失败: $_" "Red"
                                }
                                break
                            }
                        }
                    }
                    # MCR3512 自动导入注册表
                    $mcrDir = Split-Path $installer.FullName -Parent
                    if ($mcrDir -match '(?i)MCR3512|诺为|诺咪雅|控制键') {
                        $regFile = Get-ChildItem -Path "$mcrDir\*" -Include "*.reg" -ErrorAction SilentlyContinue | Select-Object -First 1
                        if ($regFile) {
                            Write-Log "检测到 MCR3512，正在导入注册表: $($regFile.Name)" "Cyan"
                            & reg import "$($regFile.FullName)" 2>&1 | Out-Null
                            if ($LASTEXITCODE -eq 0) { Write-Log "MCR3512 注册表导入完成" "Green" }
                            else { Write-Log "MCR3512 注册表导入失败 (exit: $LASTEXITCODE)" "Red" }
                        }
                    }
                    if ($installer.Name -match '(?i)HiSuite|HonorSuite') {
                        Show-HiSuitePopup
                    }
                    break
                }
                
                if ($methodIndex -lt $totalMethods) {
                    $exitText = if ($proc) { $proc.ExitCode } else { "未启动" }
                    Write-Log "静默安装未成功 (exit code: $exitText)，自动尝试下一个方法..." "Gray"
                }
            } catch {
                Write-Log "安装过程出错: $_" "Red"
            }
        }

        if (-not $installed) {
            Write-Log "所有静默安装均未成功，启动普通安装，请手动点击下一步..." "Yellow"
            try {
                Add-Type -AssemblyName System.Windows.Forms -ErrorAction Stop
                Write-Log "[注意] 即将弹出手动安装窗口，请按照提示操作" "Red"
                $topForm = New-Object System.Windows.Forms.Form; $topForm.TopMost = $true; $topForm.Show(); $topForm.Hide()
                [System.Windows.Forms.MessageBox]::Show($topForm, "软件: $($installer.Name)`n`n所有自动安装均未成功。`n安装程序会正常打开，请手动点击「下一步」完成安装。`n`n完成后点击「确定」继续。", "手动安装 --龙信硬件组", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
                $topForm.Dispose()
                if ($installer.Extension -eq ".msi") {
                    $proc = Start-Process -FilePath "msiexec.exe" -ArgumentList "/i `"$($installer.FullName)`" /norestart" -PassThru -WindowStyle Normal -ErrorAction SilentlyContinue
                } else {
                    $proc = Start-Process -FilePath $installer.FullName -PassThru -WindowStyle Normal -ErrorAction SilentlyContinue
                }
                if ($proc) { $proc.WaitForExit(300000); if (-not $proc.HasExited) { try { $proc.Kill() } catch {} } }
                shutdown /a 2>$null
                if ($proc -and ($proc.ExitCode -eq 0 -or $proc.ExitCode -eq 3010)) {
                    Write-Log "手动安装完成!" "Green"
                    $newInstalledCount++
                    $installed = $true
                    if ($installer.Name -match '(?i)burnaware') {
                        Write-Log "检测到 burnaware，正在重命名桌面快捷方式..." "Cyan"
                        $desktopPaths = @([Environment]::GetFolderPath("CommonDesktopDirectory"), [Environment]::GetFolderPath("Desktop"))
                        foreach ($desk in $desktopPaths) {
                            $shortcut = Get-ChildItem -Path $desk -Filter "*burnaware*.lnk" -ErrorAction SilentlyContinue | Select-Object -First 1
                            if ($shortcut) {
                                $newName = Join-Path $desk "案件数据专用刻录软件.lnk"
                                if (Test-Path $newName) { Remove-Item $newName -Force }
                                try { Rename-Item -Path $shortcut.FullName -NewName "案件数据专用刻录软件.lnk" -Force -ErrorAction Stop } catch {}
                                break
                            }
                        }
                    }
                    # MCR3512 自动导入注册表
                    $mcrDir = Split-Path $installer.FullName -Parent
                    if ($mcrDir -match '(?i)MCR3512|诺为|诺咪雅|控制键') {
                        $regFile = Get-ChildItem -Path "$mcrDir\*" -Include "*.reg" -ErrorAction SilentlyContinue | Select-Object -First 1
                        if ($regFile) {
                            Write-Log "检测到 MCR3512，正在导入注册表: $($regFile.Name)" "Cyan"
                            & reg import "$($regFile.FullName)" 2>&1 | Out-Null
                            if ($LASTEXITCODE -eq 0) { Write-Log "MCR3512 注册表导入完成" "Green" }
                            else { Write-Log "MCR3512 注册表导入失败 (exit: $LASTEXITCODE)" "Red" }
                        }
                    }
                    if ($installer.Name -match '(?i)HiSuite|HonorSuite') {
                        Show-HiSuitePopup
                    }
                } else {
                    $exitText = if ($proc) { $proc.ExitCode } else { "未启动" }
                    Write-Log "手动安装可能未成功 (exit code: $exitText)" "Yellow"
                }
            } catch {
                Write-Log "手动安装失败: $_" "Red"
            }
        }
        
        if (-not $installed) {
            Write-Log "所有安装方法均已尝试，未能确认安装成功" "Red"
            $failedCount++
        }
    }
}

# 火绒检查：软件全部装完后，验证火绒是否已接管
try {
    $hrSvc = Get-Service -Name "HipsDaemon" -ErrorAction SilentlyContinue
    if ($hrSvc -and $hrSvc.Status -eq 'Running') {
        try {
            Add-Type -AssemblyName System.Windows.Forms, System.Drawing -ErrorAction Stop
            $hrForm = New-Object System.Windows.Forms.Form
            $hrForm.Text = "火绒安全防护确认 --龙信硬件组"
            $hrForm.Size = New-Object System.Drawing.Size(450, 230)
            $hrForm.StartPosition = [System.Windows.Forms.FormStartPosition]::CenterScreen
            $hrForm.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::FixedDialog
            $hrForm.MaximizeBox = $false
            $hrForm.MinimizeBox = $false
            $hrForm.TopMost = $true
            $lblTitle = New-Object System.Windows.Forms.Label
            $lblTitle.Text = "火绒安全已运行"
            $lblTitle.Font = New-Object System.Drawing.Font("Microsoft YaHei", 16, [System.Drawing.FontStyle]::Bold)
            $lblTitle.ForeColor = [System.Drawing.Color]::Green
            $lblTitle.Size = New-Object System.Drawing.Size(410, 35)
            $lblTitle.Location = New-Object System.Drawing.Point(20, 18)
            $lblTitle.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
            $hrForm.Controls.Add($lblTitle)
            $lblBody = New-Object System.Windows.Forms.Label
            $lblBody.Text = "请确认火绒已完全接管系统安全防护"
            $lblBody.Font = New-Object System.Drawing.Font("Microsoft YaHei", 10)
            $lblBody.Size = New-Object System.Drawing.Size(410, 28)
            $lblBody.Location = New-Object System.Drawing.Point(20, 60)
            $lblBody.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
            $hrForm.Controls.Add($lblBody)
            $lblDesc = New-Object System.Windows.Forms.Label
            $lblDesc.Text = "检查步骤：Windows 安全中心 → 病毒和威胁防护 → 管理提供程序`n应显示: 火绒安全已接管"
            $lblDesc.Font = New-Object System.Drawing.Font("Microsoft YaHei", 8.5)
            $lblDesc.ForeColor = [System.Drawing.Color]::Gray
            $lblDesc.Size = New-Object System.Drawing.Size(410, 35)
            $lblDesc.Location = New-Object System.Drawing.Point(20, 90)
            $lblDesc.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
            $hrForm.Controls.Add($lblDesc)
            $btnConfirm = New-Object System.Windows.Forms.Button
            $btnConfirm.Text = "确认"
            $btnConfirm.BackColor = [System.Drawing.Color]::Green
            $btnConfirm.ForeColor = [System.Drawing.Color]::White
            $btnConfirm.Font = New-Object System.Drawing.Font("Microsoft YaHei", 10)
            $btnConfirm.Location = New-Object System.Drawing.Point(80, 140)
            $btnConfirm.Size = New-Object System.Drawing.Size(120, 40)
            $btnConfirm.Add_Click({ $hrForm.DialogResult = [System.Windows.Forms.DialogResult]::OK; $hrForm.Close() })
            $hrForm.Controls.Add($btnConfirm)
            $btnExit = New-Object System.Windows.Forms.Button
            $btnExit.Text = "退出程序"
            $btnExit.BackColor = [System.Drawing.Color]::Red
            $btnExit.ForeColor = [System.Drawing.Color]::White
            $btnExit.Font = New-Object System.Drawing.Font("Microsoft YaHei", 10)
            $btnExit.Location = New-Object System.Drawing.Point(240, 140)
            $btnExit.Size = New-Object System.Drawing.Size(120, 40)
            $btnExit.Add_Click({ $hrForm.DialogResult = [System.Windows.Forms.DialogResult]::Cancel; $hrForm.Close() })
            $hrForm.Controls.Add($btnExit)
            $hrForm.AcceptButton = $btnConfirm
            $hrForm.CancelButton = $btnExit
            $hrResult = $hrForm.ShowDialog()
            if ($hrResult -eq [System.Windows.Forms.DialogResult]::Cancel) {
                Write-Log "用户选择退出 (火绒确认未通过)" "Red"
                Save-LogFile
                Read-Host "按 Enter 键退出..."
                exit
            }
            Write-Log "用户已确认火绒接管安全防护" "Green"
        } catch {
            Write-Log "火绒确认弹窗显示失败: $_" "Yellow"
        }
    } else {
        Write-Log "警告：未检测到火绒安全运行" "Red"
        try {
            Add-Type -AssemblyName System.Windows.Forms -ErrorAction Stop
            $hrWarnForm = New-Object System.Windows.Forms.Form
            $hrWarnForm.TopMost = $true
            $hrWarnForm.Show(); $hrWarnForm.Hide()
            [System.Windows.Forms.MessageBox]::Show($hrWarnForm, "未检测到火绒安全运行！`n`n请确认已安装火绒，或手动检查安全状态。", "安全警告 --龙信硬件组", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
            $hrWarnForm.Dispose()
        } catch {}
    }
} catch {}

# ============================================================
# 完成汇总
# ============================================================
Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "  全部任务完成!" -ForegroundColor Green
Write-Host "  时间: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green

if ($installers.Count -gt 0) {
    Write-Host ""
    Write-Host "  软件安装统计:" -ForegroundColor Cyan
    Write-Host "    找到安装包: $($installers.Count) 个" -ForegroundColor Gray
    Write-Host "    已安装跳过: $skippedCount 个" -ForegroundColor Yellow
    Write-Host "    本次新安装: $newInstalledCount 个" -ForegroundColor Green
    Write-Host "    安装失败:   $failedCount 个" -ForegroundColor Red
}

Write-Host ""
Write-Host "注意事项:" -ForegroundColor Yellow
Write-Host "  1. 部分设置需要重启电脑后生效" -ForegroundColor Yellow
Write-Host "  2. 如软件安装失败，请手动运行对应安装包" -ForegroundColor Yellow
Write-Host "  3. 如已安装火绒安全，防火墙关闭状态下请确保其正常运行" -ForegroundColor Yellow
Write-Host "  4. 如需恢复更新，可重新开启 wuauserv 服务" -ForegroundColor Yellow

Save-LogFile
if (-not $NoPause) {
    Write-Host ""
    Read-Host "按 Enter 键退出..."
}
