# ============================================================
# 电脑出厂调试 - 统一 GUI 工具 v2.1  --龙信硬件组
# 启动：双击 "运行_GUI工具.bat"
# ============================================================

param()

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $scriptDir

# ===== Auto-elevate =====
if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]"Administrator")) {
    Start-Process powershell -Verb RunAs -ArgumentList "-ExecutionPolicy Bypass -File `"$PSCommandPath`""
    exit
}

Add-Type -AssemblyName System.Windows.Forms, System.Drawing

# 防闪屏：P/Invoke LockWindowUpdate
Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public class Win32Lock {
    [DllImport("user32.dll")]
    public static extern bool LockWindowUpdate(IntPtr hWndLock);
}
"@

# DPI 缩放因子：检测当前系统 DPI，等比缩放所有控件
$dpiGraphics = [System.Drawing.Graphics]::FromHwnd([IntPtr]::Zero)
$scale = [math]::Max($dpiGraphics.DpiX, $dpiGraphics.DpiY) / 96.0
$dpiGraphics.Dispose()

# ===== 颜色主题 =====
$colorBg = [System.Drawing.Color]::FromArgb(245, 247, 250)
$colorSurface = [System.Drawing.Color]::FromArgb(255, 255, 255)
$colorPanel = [System.Drawing.Color]::FromArgb(238, 242, 247)
$colorHeader = [System.Drawing.Color]::FromArgb(18, 72, 132)
$colorText = [System.Drawing.Color]::FromArgb(32, 37, 45)
$colorMuted = [System.Drawing.Color]::FromArgb(96, 111, 130)
$colorBorder = [System.Drawing.Color]::FromArgb(214, 222, 233)
$colorLogBg = [System.Drawing.Color]::FromArgb(18, 24, 32)
$colorBtn1 = [System.Drawing.Color]::FromArgb(30, 105, 190)
$colorBtn2 = [System.Drawing.Color]::FromArgb(20, 135, 82)
$colorBtn3 = [System.Drawing.Color]::FromArgb(214, 126, 30)
$colorBtn4 = [System.Drawing.Color]::FromArgb(95, 84, 190)
$colorBtnExit = [System.Drawing.Color]::FromArgb(176, 55, 55)

function New-UiLabel {
    param(
        [string]$Text,
        [int]$X,
        [int]$Y,
        [int]$W,
        [int]$H,
        [int]$Size = 9,
        [System.Drawing.FontStyle]$Style = [System.Drawing.FontStyle]::Regular,
        [System.Drawing.Color]$Color = $colorText
    )
    $label = New-Object System.Windows.Forms.Label
    $label.Text = $Text
    $label.Location = New-Object System.Drawing.Point([math]::Round($X * $scale), [math]::Round($Y * $scale))
    $label.Size = New-Object System.Drawing.Size([math]::Round($W * $scale), [math]::Round($H * $scale))
    $label.Font = New-Object System.Drawing.Font("Microsoft YaHei", [math]::Round($Size * $scale), $Style)
    $label.ForeColor = $Color
    $label.BackColor = [System.Drawing.Color]::Transparent
    return $label
}

function New-ActionCard {
    param(
        [string]$Title,
        [string]$Desc,
        [string]$ButtonText,
        [int]$X,
        [int]$Y,
        [System.Drawing.Color]$ButtonColor
    )
    $card = New-Object System.Windows.Forms.Panel
    $card.Location = New-Object System.Drawing.Point([math]::Round($X * $scale), [math]::Round($Y * $scale))
    $card.Size = New-Object System.Drawing.Size([math]::Round(410 * $scale), [math]::Round(78 * $scale))
    $card.BackColor = $colorSurface
    $card.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
    $card.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Left
    $actionPanel.Controls.Add($card)

    $titleLabel = New-UiLabel $Title 14 10 245 24 11 ([System.Drawing.FontStyle]::Bold) $colorText
    $descLabel = New-UiLabel $Desc 14 38 255 30 8 ([System.Drawing.FontStyle]::Regular) $colorMuted
    $button = New-Object System.Windows.Forms.Button
    $button.Text = $ButtonText
    $button.Location = New-Object System.Drawing.Point([math]::Round(282 * $scale), [math]::Round(20 * $scale))
    $button.Size = New-Object System.Drawing.Size([math]::Round(112 * $scale), [math]::Round(38 * $scale))
    $button.Font = New-Object System.Drawing.Font("Microsoft YaHei", [math]::Round(9 * $scale), [System.Drawing.FontStyle]::Bold)
    $button.BackColor = $ButtonColor
    $button.ForeColor = [System.Drawing.Color]::White
    $button.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $button.FlatAppearance.BorderSize = 0
    $button.Cursor = [System.Windows.Forms.Cursors]::Hand
    $hoverColor = [System.Drawing.Color]::FromArgb(
        [math]::Min(255, $ButtonColor.R + 18),
        [math]::Min(255, $ButtonColor.G + 18),
        [math]::Min(255, $ButtonColor.B + 18)
    )
    $button.Add_MouseEnter({ $this.BackColor = $hoverColor }.GetNewClosure())
    $button.Add_MouseLeave({ $this.BackColor = $ButtonColor }.GetNewClosure())

    $card.Controls.Add($titleLabel)
    $card.Controls.Add($descLabel)
    $card.Controls.Add($button)
    return $button
}

# ===== 主窗口 =====
$form = New-Object System.Windows.Forms.Form
$form.Text = "电脑出厂调试工具 v2.1  --龙信硬件组"
$form.Size = New-Object System.Drawing.Size([math]::Round(920 * $scale), [math]::Round(720 * $scale))
$form.MinimumSize = New-Object System.Drawing.Size([math]::Round(940 * $scale), [math]::Round(660 * $scale))
$form.StartPosition = [System.Windows.Forms.FormStartPosition]::CenterScreen
$form.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::Sizable
$form.MaximizeBox = $true
$form.BackColor = $colorBg

# ===== 顶部品牌区域 =====
$headerPanel = New-Object System.Windows.Forms.Panel
$headerPanel.Location = New-Object System.Drawing.Point(0, 0)
$headerPanel.Size = New-Object System.Drawing.Size($form.ClientSize.Width, [math]::Round(92 * $scale))
$headerPanel.BackColor = $colorHeader
$headerPanel.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Right

$headerTitle = New-Object System.Windows.Forms.Label
$headerTitle.Text = "电脑出厂调试工具"
$headerTitle.Location = New-Object System.Drawing.Point([math]::Round(26 * $scale), [math]::Round(16 * $scale))
$headerTitle.Size = New-Object System.Drawing.Size([math]::Round(520 * $scale), [math]::Round(34 * $scale))
$headerTitle.Font = New-Object System.Drawing.Font("Microsoft YaHei", [math]::Round(17 * $scale), [System.Drawing.FontStyle]::Bold)
$headerTitle.ForeColor = [System.Drawing.Color]::White
$headerPanel.Controls.Add($headerTitle)

$headerSubtitle = New-Object System.Windows.Forms.Label
$headerSubtitle.Text = "仓库发货前使用：系统设置、软件安装、还原和网络驱动器映射"
$headerSubtitle.Location = New-Object System.Drawing.Point([math]::Round(28 * $scale), [math]::Round(54 * $scale))
$headerSubtitle.Size = New-Object System.Drawing.Size([math]::Round(650 * $scale), [math]::Round(22 * $scale))
$headerSubtitle.Font = New-Object System.Drawing.Font("Microsoft YaHei", [math]::Round(9 * $scale))
$headerSubtitle.ForeColor = [System.Drawing.Color]::FromArgb(198, 222, 246)
$headerPanel.Controls.Add($headerSubtitle)

$headerBrand = New-Object System.Windows.Forms.Label
$headerBrand.Text = "龙信硬件组  v2.1"
$headerBrand.Location = New-Object System.Drawing.Point([math]::Round(690 * $scale), [math]::Round(30 * $scale))
$headerBrand.Size = New-Object System.Drawing.Size([math]::Round(190 * $scale), [math]::Round(28 * $scale))
$headerBrand.Font = New-Object System.Drawing.Font("Microsoft YaHei", [math]::Round(10 * $scale), [System.Drawing.FontStyle]::Bold)
$headerBrand.ForeColor = [System.Drawing.Color]::White
$headerBrand.TextAlign = [System.Drawing.ContentAlignment]::MiddleRight
$headerBrand.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Right
$headerPanel.Controls.Add($headerBrand)

$form.Add_Resize({ $headerPanel.Width = $form.ClientSize.Width })
$form.Controls.Add($headerPanel)

# ===== 状态区域 =====
$statusPanel = New-Object System.Windows.Forms.Panel
$statusPanel.Location = New-Object System.Drawing.Point([math]::Round(18 * $scale), [math]::Round(108 * $scale))
$statusPanel.Size = New-Object System.Drawing.Size([math]::Round(866 * $scale), [math]::Round(72 * $scale))
$statusPanel.BackColor = $colorSurface
$statusPanel.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
$statusPanel.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Right
$form.Controls.Add($statusPanel)

$statusPill = New-Object System.Windows.Forms.Label
$statusPill.Text = "就绪"
$statusPill.Location = New-Object System.Drawing.Point([math]::Round(16 * $scale), [math]::Round(18 * $scale))
$statusPill.Size = New-Object System.Drawing.Size([math]::Round(76 * $scale), [math]::Round(32 * $scale))
$statusPill.Font = New-Object System.Drawing.Font("Microsoft YaHei", [math]::Round(10 * $scale), [System.Drawing.FontStyle]::Bold)
$statusPill.ForeColor = [System.Drawing.Color]::White
$statusPill.BackColor = [System.Drawing.Color]::FromArgb(55, 145, 90)
$statusPill.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
$statusPanel.Controls.Add($statusPill)

$statusLabel = New-UiLabel "请选择下面的操作，运行时会自动显示日志。" 108 14 620 24 10 ([System.Drawing.FontStyle]::Bold) $colorText
$taskLabel = New-UiLabel "当前任务：等待开始" 108 40 320 20 8 ([System.Drawing.FontStyle]::Regular) $colorMuted
$logPathLabel = New-UiLabel "日志位置：尚未开始" 430 40 410 20 8 ([System.Drawing.FontStyle]::Regular) $colorMuted
$logPathLabel.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Right
$statusPanel.Controls.Add($statusLabel)
$statusPanel.Controls.Add($taskLabel)
$statusPanel.Controls.Add($logPathLabel)

# ===== 操作区域 =====
$actionPanel = New-Object System.Windows.Forms.Panel
$actionPanel.Location = New-Object System.Drawing.Point([math]::Round(18 * $scale), [math]::Round(194 * $scale))
$actionPanel.Size = New-Object System.Drawing.Size([math]::Round(866 * $scale), [math]::Round(176 * $scale))
$actionPanel.BackColor = $colorBg
$actionPanel.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Right
$form.Controls.Add($actionPanel)

$btnSetup = New-ActionCard "仅系统设置" "设置壁纸、锁屏、电源、安全、任务栏等。" "开始设置" 0 0 $colorBtn1
$btnFull = New-ActionCard "完整安装" "先做系统设置，再安装 software 文件夹的软件。" "选择软件" 434 0 $colorBtn2
$btnRestore = New-ActionCard "还原设置" "把本工具修改过的系统设置恢复为默认。" "开始还原" 0 92 $colorBtn3
$btnNetwork = New-ActionCard "映射网络驱动器" "映射 Z: 到 T:，用于连接指定共享目录。" "开始映射" 434 92 $colorBtn4

# ===== 日志输出区 =====
$logTitle = New-UiLabel "运行日志" 18 380 160 24 11 ([System.Drawing.FontStyle]::Bold) $colorText
$form.Controls.Add($logTitle)

$btnExit = New-Object System.Windows.Forms.Button
$btnExit.Text = "退出"
$btnExit.Location = New-Object System.Drawing.Point([math]::Round(794 * $scale), [math]::Round(376 * $scale))
$btnExit.Size = New-Object System.Drawing.Size([math]::Round(90 * $scale), [math]::Round(30 * $scale))
$btnExit.Font = New-Object System.Drawing.Font("Microsoft YaHei", [math]::Round(9 * $scale))
$btnExit.BackColor = $colorBtnExit
$btnExit.ForeColor = [System.Drawing.Color]::White
$btnExit.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$btnExit.FlatAppearance.BorderSize = 0
$btnExit.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Right
$btnExit.Cursor = [System.Windows.Forms.Cursors]::Hand
$form.Controls.Add($btnExit)

$btnPrecheck = New-Object System.Windows.Forms.Button
$btnPrecheck.Text = "预检查"
$btnPrecheck.Location = New-Object System.Drawing.Point([math]::Round(596 * $scale), [math]::Round(376 * $scale))
$btnPrecheck.Size = New-Object System.Drawing.Size([math]::Round(90 * $scale), [math]::Round(30 * $scale))
$btnPrecheck.Font = New-Object System.Drawing.Font("Microsoft YaHei", [math]::Round(9 * $scale))
$btnPrecheck.BackColor = [System.Drawing.Color]::FromArgb(82, 112, 148)
$btnPrecheck.ForeColor = [System.Drawing.Color]::White
$btnPrecheck.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$btnPrecheck.FlatAppearance.BorderSize = 0
$btnPrecheck.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Right
$btnPrecheck.Cursor = [System.Windows.Forms.Cursors]::Hand
$form.Controls.Add($btnPrecheck)

$btnReport = New-Object System.Windows.Forms.Button
$btnReport.Text = "导出问题报告"
$btnReport.Location = New-Object System.Drawing.Point([math]::Round(692 * $scale), [math]::Round(376 * $scale))
$btnReport.Size = New-Object System.Drawing.Size([math]::Round(96 * $scale), [math]::Round(30 * $scale))
$btnReport.Font = New-Object System.Drawing.Font("Microsoft YaHei", [math]::Round(9 * $scale))
$btnReport.BackColor = [System.Drawing.Color]::FromArgb(72, 120, 92)
$btnReport.ForeColor = [System.Drawing.Color]::White
$btnReport.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$btnReport.FlatAppearance.BorderSize = 0
$btnReport.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Right
$btnReport.Cursor = [System.Windows.Forms.Cursors]::Hand
$form.Controls.Add($btnReport)

$outputBox = New-Object System.Windows.Forms.RichTextBox
$outputBox.Location = New-Object System.Drawing.Point([math]::Round(18 * $scale), [math]::Round(412 * $scale))
$outputBox.Size = New-Object System.Drawing.Size([math]::Round(866 * $scale), [math]::Round(210 * $scale))
$outputBox.ReadOnly = $true
$outputBox.Font = New-Object System.Drawing.Font("Consolas", [math]::Round(9.5 * $scale))
$outputBox.BackColor = $colorLogBg
$outputBox.ForeColor = [System.Drawing.Color]::FromArgb(226, 232, 240)
$outputBox.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
$outputBox.WordWrap = $true
$outputBox.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Right
$form.Controls.Add($outputBox)

$progress = New-Object System.Windows.Forms.ProgressBar
$progress.Location = New-Object System.Drawing.Point([math]::Round(18 * $scale), [math]::Round(632 * $scale))
$progress.Size = New-Object System.Drawing.Size([math]::Round(866 * $scale), [math]::Round(18 * $scale))
$progress.Style = [System.Windows.Forms.ProgressBarStyle]::Marquee
$progress.Visible = $false
$progress.Anchor = [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Right -bor [System.Windows.Forms.AnchorStyles]::Bottom
$form.Controls.Add($progress)

# ===== Core Logic =====
$script:running = $false
$script:proc = $null
$script:allButtons = @($btnSetup, $btnFull, $btnRestore, $btnNetwork, $btnPrecheck, $btnReport)
$script:logFilePath = $null

function Set-Running($run) {
    $script:running = $run
    foreach ($btn in $script:allButtons) { $btn.Enabled = -not $run }
    $progress.Visible = $run
    if ($run) {
        $statusPill.Text = "运行中"
        $statusPill.BackColor = [System.Drawing.Color]::FromArgb(30, 105, 190)
    } else {
        $statusPill.Text = "就绪"
        $statusPill.BackColor = [System.Drawing.Color]::FromArgb(55, 145, 90)
    }
}

function Append-Output($text, $color) {
    $outputBox.SelectionStart = $outputBox.TextLength
    $outputBox.SelectionLength = 0
    if ($color) { $outputBox.SelectionColor = $color }
    $outputBox.AppendText($text + "`r`n")
    $outputBox.ScrollToCaret()
}

function Write-CheckLine {
    param([bool]$Ok, [string]$Message, [string]$Help = "")
    if ($Ok) {
        Append-Output "[OK]  $Message" ([System.Drawing.Color]::FromArgb(80, 220, 80))
    } else {
        Append-Output "[!!]  $Message" ([System.Drawing.Color]::FromArgb(255, 100, 100))
        if ($Help) { Append-Output "      处理方法：$Help" ([System.Drawing.Color]::FromArgb(230, 200, 50)) }
    }
}

function Start-Precheck {
    if ($script:running) { return }
    Set-Running $true
    $outputBox.Clear()
    $statusLabel.Text = "正在做预检查，不会修改系统。"
    $taskLabel.Text = "当前任务：预检查"
    $logPathLabel.Text = "日志位置：预检查只显示在窗口内"
    Append-Output "预检查开始：本操作只检查环境，不会修改电脑设置。" ([System.Drawing.Color]::Cyan)
    Append-Output "────────────────────────────────────" ([System.Drawing.Color]::Gray)

    $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]"Administrator")
    Write-CheckLine $isAdmin "管理员权限" "请右键运行_GUI工具.bat，选择以管理员身份运行。"

    foreach ($name in @("system_setup.ps1","full_setup.ps1","system_restore.ps1","main_gui.ps1")) {
        $path = Join-Path $scriptDir $name
        Write-CheckLine (Test-Path $path) "脚本文件存在：$name" "请确认工具文件没有被删除或改名。"
    }

    $wallFound = @(Get-ChildItem -Path "$scriptDir\*" -Include "wallpaper.jpg","wallpaper.jpeg","wallpaper.png","wallpaper.bmp" -ErrorAction SilentlyContinue)
    Write-CheckLine ($wallFound.Count -gt 0) "壁纸文件：$($wallFound.Name -join ', ')" "请把壁纸命名为 wallpaper.jpg/png/bmp，放到工具同目录。"

    $lockFound = @(Get-ChildItem -Path "$scriptDir\*" -Include "lockscreen.jpg","lockscreen.jpeg","lockscreen.png","lockscreen.bmp" -ErrorAction SilentlyContinue)
    Write-CheckLine ($lockFound.Count -gt 0) "锁屏文件：$($lockFound.Name -join ', ')" "请把锁屏图命名为 lockscreen.jpg/png/bmp，放到工具同目录。"

    $softwareDir = Join-Path $scriptDir "software"
    if (Test-Path $softwareDir) {
        $installers = @(Get-ChildItem -Path "$softwareDir\*" -Include "*.exe","*.msi" -ErrorAction SilentlyContinue)
        Write-CheckLine ($installers.Count -gt 0) "software 文件夹安装包数量：$($installers.Count)" "请把 .exe 或 .msi 安装包放入 software 文件夹。"
    } else {
        Write-CheckLine $false "software 文件夹不存在" "请在工具目录创建 software 文件夹，并把安装包放进去。"
    }

    $usbInf = Join-Path $scriptDir "software\usb_driver\android_winusb.inf"
    Write-CheckLine (Test-Path $usbInf) "USB 驱动文件 android_winusb.inf" "如需要安装 USB 驱动，请放到 software\usb_driver\android_winusb.inf。"

    $mcrFolder = $null
    if (Test-Path $softwareDir) {
        $mcrFolder = Get-ChildItem -Path $softwareDir -Directory -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -match '(?i)MCR3512|诺为|诺咪雅|控制键' } |
            Select-Object -First 1
    }
    Write-CheckLine ($null -ne $mcrFolder) "MCR3512 控制键目录" "如需要控制键安装，请把 MCR3512/控制键相关文件夹放到 software 目录。"

    $blockers = @()
    foreach ($p in @("LenovoSafe*","LenovoPcManager*","360Safe*","QQPCMgr*","kxescore*","2345Safe*")) {
        if (Get-Process -Name $p -ErrorAction SilentlyContinue) { $blockers += $p }
    }
    Write-CheckLine ($blockers.Count -eq 0) "第三方安全软件进程检查" "检测到可能拦截设置的软件：$($blockers -join ', ')。建议先退出或卸载后再跑。"

    Append-Output "────────────────────────────────────" ([System.Drawing.Color]::Gray)
    Append-Output "预检查完成。红色项目不一定代表不能运行，但建议先处理。" ([System.Drawing.Color]::Cyan)
    Set-Running $false
    $statusLabel.Text = "预检查已完成。"
    $taskLabel.Text = "当前任务：已完成"
}

function Export-IssueReport {
    if ($script:running) { return }
    Set-Running $true
    $outputBox.Clear()
    $statusLabel.Text = "正在导出问题报告，请稍等。"
    $taskLabel.Text = "当前任务：导出问题报告"

    $logDir = Join-Path $scriptDir "logs"
    $null = New-Item -ItemType Directory -Path $logDir -Force
    $now = Get-Date -Format 'yyyyMMdd_HHmmss'
    $txtPath = Join-Path $logDir "问题报告_${now}.txt"
    $logPathLabel.Text = "报告位置：$txtPath"

    try {
        Append-Output "正在收集电脑信息..." ([System.Drawing.Color]::Cyan)
        $lines = @()
        $lines += "============================================"
        $lines += "  电脑出厂调试工具 - 问题报告"
        $lines += "  生成时间: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
        $lines += "============================================"
        $lines += ""
        $lines += "===== 电脑信息 ====="
        $lines += "生成时间: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
        $lines += "工具目录: $scriptDir"
        $lines += "当前用户: $env:USERNAME"
        $lines += "电脑名: $env:COMPUTERNAME"
        $lines += "PowerShell: $($PSVersionTable.PSVersion)"
        try { $lines += (Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue | Select-Object Caption, Version, BuildNumber, OSArchitecture, LastBootUpTime | Format-List | Out-String) } catch {}
        try { $lines += (Get-CimInstance Win32_ComputerSystem -ErrorAction SilentlyContinue | Select-Object Manufacturer, Model, SystemType, TotalPhysicalMemory | Format-List | Out-String) } catch {}
        try { $lines += (Get-CimInstance Win32_BIOS -ErrorAction SilentlyContinue | Select-Object Manufacturer, SMBIOSBIOSVersion, SerialNumber | Format-List | Out-String) } catch {}
        $lines += ""

        $lines += "===== 关键服务状态 ====="
        foreach ($svc in @("wuauserv","UsoSvc","BITS","WaaSMedicSvc","WinDefend","mpssvc","SecurityHealthService","HipsDaemon")) {
            try { $lines += (Get-Service -Name $svc -ErrorAction SilentlyContinue | Select-Object Name, DisplayName, Status, StartType | Format-List | Out-String) } catch {}
        }
        $lines += ""

        $lines += "===== 已安装软件列表 ====="
        $uninstallPaths = @(
            "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
            "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*",
            "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*"
        )
        foreach ($up in $uninstallPaths) {
            try { $lines += (Get-ItemProperty -Path $up -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName } | Select-Object DisplayName, DisplayVersion, Publisher, InstallDate | Sort-Object DisplayName | Format-Table -AutoSize | Out-String) } catch {}
        }
        $lines += ""

        $lines += "===== software 文件夹清单 ====="
        $softwareDir = Join-Path $scriptDir "software"
        if (Test-Path $softwareDir) {
            try { $lines += (Get-ChildItem -Path $softwareDir -Recurse -ErrorAction SilentlyContinue | Select-Object FullName, Length, LastWriteTime | Format-Table -AutoSize | Out-String) } catch {}
        } else {
            $lines += "未找到 software 文件夹"
        }
        $lines += ""

        $lines += "===== 最近系统错误 (3天内) ====="
        foreach ($logName in @("System","Application")) {
            $lines += "--- $logName ---"
            try {
                $lines += (Get-WinEvent -FilterHashtable @{LogName=$logName; Level=1,2; StartTime=(Get-Date).AddDays(-3)} -MaxEvents 50 -ErrorAction SilentlyContinue |
                    Select-Object TimeCreated, ProviderName, Id, LevelDisplayName, Message |
                    Format-List | Out-String)
            } catch {
                $lines += "读取 $logName 失败: $_"
            }
        }
        $lines += ""

        $lines += "===== 最近日志文件内容 ====="
        $logFiles = Get-ChildItem -Path "$logDir\*.log" -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 5
        if ($logFiles) {
            foreach ($lf in $logFiles) {
                $lines += "--- $($lf.Name) ($($lf.LastWriteTime)) ---"
                try {
                    $logContent = Get-Content -Path $lf.FullName -Encoding UTF8 -ErrorAction SilentlyContinue
                    $lines += $logContent
                } catch {
                    $lines += "读取失败: $_"
                }
                $lines += ""
            }
        } else {
            $lines += "没有找到日志文件"
        }

        [System.IO.File]::WriteAllText($txtPath, ($lines -join "`r`n"), [System.Text.Encoding]::UTF8)

        Append-Output "[OK] 问题报告已生成: $txtPath" ([System.Drawing.Color]::FromArgb(80, 220, 80))
        [System.Windows.Forms.MessageBox]::Show("问题报告已生成：`n`n$txtPath`n`n把这个 .txt 文件发给 AI 分析即可。", "导出完成 --龙信硬件组", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information) | Out-Null
        $statusLabel.Text = "问题报告已导出。"
        $taskLabel.Text = "当前任务：已完成"
    } catch {
        Append-Output "[!!] 导出问题报告失败: $_" ([System.Drawing.Color]::FromArgb(255, 100, 100))
        $statusLabel.Text = "导出问题报告失败。"
        $taskLabel.Text = "当前任务：失败"
    } finally {
        Set-Running $false
    }
}

function Start-ScriptRun($ps1Name, $displayName, $extraArgs = "") {
    if ($script:running) { return }
    Set-Running $true
    $outputBox.Clear()
    Append-Output "启动: $displayName" ([System.Drawing.Color]::Cyan)
    Append-Output "────────────────────────────────────" ([System.Drawing.Color]::Gray)
    $statusLabel.Text = "$displayName 正在运行，请不要关闭窗口。"
    $taskLabel.Text = "当前任务：$displayName"

    $ps1Path = Join-Path $scriptDir $ps1Name
    if (-not (Test-Path $ps1Path)) {
        Append-Output "[错误] 未找到脚本: $ps1Name" ([System.Drawing.Color]::Red)
        Set-Running $false
        $statusLabel.Text = "错误：脚本文件不存在。"
        $taskLabel.Text = "当前任务：启动失败"
        return
    }

    $logDir = Join-Path $scriptDir "logs"
    $null = New-Item -ItemType Directory -Path $logDir -Force
    $now = Get-Date -Format 'yyyyMMdd_HHmmss'
    $prefix = switch ($ps1Name) {
        "system_setup.ps1" { "setup" }
        "full_setup.ps1" { "fullsetup" }
        "system_restore.ps1" { "restore" }
        default { "run" }
    }
    $script:logFilePath = Join-Path $logDir "${prefix}_${now}_gui.log"
    $logPathLabel.Text = "日志位置：$($script:logFilePath)"
    Append-Output "日志: $($script:logFilePath)" ([System.Drawing.Color]::Gray)

    $proc = Start-Process powershell `
        -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$ps1Path`" -NoPause -LogPath `"$($script:logFilePath)`" $extraArgs" `
        -WindowStyle Minimized `
        -PassThru
    $script:proc = $proc

    $timer = New-Object System.Windows.Forms.Timer
    $timer.Interval = 200
    $lastReadPosition = 0
    $script:timerStopped = $false
    $timer.Add_Tick({
        if ($script:timerStopped) { return }
        if (-not $script:logFilePath) { return }
        try {
            if (Test-Path $script:logFilePath) {
                $stream = [System.IO.File]::Open($script:logFilePath, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite)
                if ($stream.Length -gt $lastReadPosition) {
                    $stream.Seek($lastReadPosition, [System.IO.SeekOrigin]::Begin) | Out-Null
                    $reader = New-Object System.IO.StreamReader($stream, [System.Text.Encoding]::UTF8)
                    $newLines = while (($line = $reader.ReadLine()) -ne $null) { $line }
                    if ($newLines) {
                        $userAtBottom = ($outputBox.SelectionStart -ge ($outputBox.TextLength - 50))
                        [Win32Lock]::LockWindowUpdate($outputBox.Handle)
                        foreach ($line in $newLines) {
                            $clr = [System.Drawing.Color]::FromArgb(200, 200, 200)
                            if ($line -match '\[OK\]|安装完成|成功|已禁用|已关闭|已启用|已恢复|设置成功|重命名|改名') { $clr = [System.Drawing.Color]::FromArgb(80, 220, 80) }
                            elseif ($line -match '\[!!\]|失败|错误|ERROR') { $clr = [System.Drawing.Color]::FromArgb(255, 100, 100) }
                            elseif ($line -match '\[>>\]|跳过|警告|可能') { $clr = [System.Drawing.Color]::FromArgb(230, 200, 50) }
                            elseif ($line -match '\[ii\]|启动|正在|尝试|处理') { $clr = [System.Drawing.Color]::FromArgb(80, 200, 230) }
                            $outputBox.SelectionStart = $outputBox.TextLength
                            $outputBox.SelectionLength = 0
                            $outputBox.SelectionColor = $clr
                            $outputBox.AppendText($line + "`r`n")
                        }
                        if ($userAtBottom) { $outputBox.ScrollToCaret() }
                        [Win32Lock]::LockWindowUpdate([IntPtr]::Zero)
                    }
                    $lastReadPosition = $stream.Position
                    $reader.Close()
                }
                $stream.Close()
            }
        } catch { }
        
        if ($script:proc -and $script:proc.HasExited) {
            if ($script:timerStopped) { return }
            $script:timerStopped = $true
            try { $timer.Stop() } catch {}
            try { $timer.Dispose() } catch {}
            $outputBox.SelectionStart = $outputBox.TextLength
            $outputBox.SelectionColor = [System.Drawing.Color]::FromArgb(100, 255, 100)
            $outputBox.AppendText("`r`n────────────────────────────────────`r`n")
            $outputBox.AppendText("$displayName — 执行完毕`r`n")
            $outputBox.ScrollToCaret()
            Set-Running $false
            $statusLabel.Text = "$displayName 已完成。可以继续选择其他操作。"
            $taskLabel.Text = "当前任务：已完成"
            $script:proc = $null
        }
    })
    $timer.Start()
    $script:activeTimer = $timer
}

# ===== Software Selection Dialog =====
function Show-SoftwareSelection {
    $sf = New-Object System.Windows.Forms.Form
    $sf.Text = "选择要安装的软件 --龙信硬件组"
    $sf.Size = New-Object System.Drawing.Size([math]::Round(600 * $scale), [math]::Round(560 * $scale))
    $sf.StartPosition = [System.Windows.Forms.FormStartPosition]::CenterParent
    $sf.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::FixedDialog
    $sf.MaximizeBox = $false
    $sf.MinimizeBox = $false
    $sf.TopMost = $true
    $sf.BackColor = $colorBg
    
    $lbl = New-Object System.Windows.Forms.Label
    $lbl.Text = "请勾选需要安装的软件（默认全选）："
    $lbl.Location = New-Object System.Drawing.Point([math]::Round(16 * $scale), [math]::Round(16 * $scale))
    $lbl.Size = New-Object System.Drawing.Size([math]::Round(560 * $scale), [math]::Round(28 * $scale))
    $lbl.Font = New-Object System.Drawing.Font("Microsoft YaHei", [math]::Round(10 * $scale))
    $lbl.ForeColor = $colorText
    $sf.Controls.Add($lbl)
    
    $clb = New-Object System.Windows.Forms.CheckedListBox
    $clb.Location = New-Object System.Drawing.Point([math]::Round(16 * $scale), [math]::Round(50 * $scale))
    $clb.Size = New-Object System.Drawing.Size([math]::Round(560 * $scale), [math]::Round(370 * $scale))
    $clb.Font = New-Object System.Drawing.Font("Microsoft YaHei", [math]::Round(11 * $scale))
    $clb.ItemHeight = [math]::Round(22 * $scale)
    $clb.CheckOnClick = $true
    $clb.BackColor = [System.Drawing.Color]::FromArgb(35, 35, 38)
    $clb.ForeColor = $colorText
    $sf.Controls.Add($clb)
    
    $scriptNames = @("system_setup.ps1","full_setup.ps1","system_restore.ps1","main_gui.ps1")
    $imgNames = @("wallpaper.jpg","wallpaper.jpeg","wallpaper.png","wallpaper.bmp","lockscreen.jpg","lockscreen.jpeg","lockscreen.png","lockscreen.bmp")
    $softwareDir = Join-Path $scriptDir "software"
    if (Test-Path $softwareDir) {
        $found = @(Get-ChildItem -Path "$softwareDir\*" -Include "*.exe","*.msi" -ErrorAction SilentlyContinue |
            Where-Object { -not ($scriptNames -contains $_.Name) -and -not ($imgNames -contains $_.Name) } |
            Sort-Object Name)
    } else {
        $found = @()
    }
    
    $fileMap = @{}
    foreach ($f in $found) {
        $idx = $clb.Items.Add($f.Name)
        $clb.SetItemChecked($idx, $true)
        $fileMap[$idx] = $f.FullName
    }
    
    if ($found.Count -eq 0) {
        if (Test-Path $softwareDir) {
            $clb.Items.Add("(software 文件夹里没有 .exe 或 .msi 安装包)")
        } else {
            $clb.Items.Add("(未找到 software 文件夹，请先创建并放入安装包)")
        }
        $clb.Enabled = $false
    }
    
    $btnAll = New-Object System.Windows.Forms.Button
    $btnAll.Text = "全选"
    $btnAll.Location = New-Object System.Drawing.Point([math]::Round(16 * $scale), [math]::Round(435 * $scale))
    $btnAll.Size = New-Object System.Drawing.Size([math]::Round(100 * $scale), [math]::Round(36 * $scale))
    $btnAll.Font = New-Object System.Drawing.Font("Microsoft YaHei", [math]::Round(9 * $scale))
    $btnAll.BackColor = $colorPanel
    $btnAll.ForeColor = $colorText
    $btnAll.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $btnAll.FlatAppearance.BorderSize = 1
    $btnAll.FlatAppearance.BorderColor = $colorBorder
    $btnAll.Add_Click({
        for ($i = 0; $i -lt $clb.Items.Count; $i++) { $clb.SetItemChecked($i, $true) }
    })
    $sf.Controls.Add($btnAll)
    
    $btnNone = New-Object System.Windows.Forms.Button
    $btnNone.Text = "取消全选"
    $btnNone.Location = New-Object System.Drawing.Point([math]::Round(126 * $scale), [math]::Round(435 * $scale))
    $btnNone.Size = New-Object System.Drawing.Size([math]::Round(100 * $scale), [math]::Round(36 * $scale))
    $btnNone.Font = New-Object System.Drawing.Font("Microsoft YaHei", [math]::Round(9 * $scale))
    $btnNone.BackColor = $colorPanel
    $btnNone.ForeColor = $colorText
    $btnNone.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $btnNone.FlatAppearance.BorderSize = 1
    $btnNone.FlatAppearance.BorderColor = $colorBorder
    $btnNone.Add_Click({
        for ($i = 0; $i -lt $clb.Items.Count; $i++) { $clb.SetItemChecked($i, $false) }
    })
    $sf.Controls.Add($btnNone)
    
    $sf.AcceptButton = New-Object System.Windows.Forms.Button
    $sf.AcceptButton.Text = ""
    
    $btnOK = New-Object System.Windows.Forms.Button
    $btnOK.Text = "确认安装所选软件"
    $btnOK.Location = New-Object System.Drawing.Point([math]::Round(350 * $scale), [math]::Round(475 * $scale))
    $btnOK.Size = New-Object System.Drawing.Size([math]::Round(150 * $scale), [math]::Round(40 * $scale))
    $btnOK.Font = New-Object System.Drawing.Font("Microsoft YaHei", [math]::Round(10 * $scale))
    $btnOK.BackColor = $colorBtn2
    $btnOK.ForeColor = [System.Drawing.Color]::White
    $btnOK.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $btnOK.FlatAppearance.BorderSize = 0
    $btnOK.DialogResult = [System.Windows.Forms.DialogResult]::OK
    $sf.Controls.Add($btnOK)
    $sf.AcceptButton = $btnOK
    
    $btnCancel = New-Object System.Windows.Forms.Button
    $btnCancel.Text = "取消"
    $btnCancel.Location = New-Object System.Drawing.Point([math]::Round(510 * $scale), [math]::Round(475 * $scale))
    $btnCancel.Size = New-Object System.Drawing.Size([math]::Round(70 * $scale), [math]::Round(40 * $scale))
    $btnCancel.Font = New-Object System.Drawing.Font("Microsoft YaHei", [math]::Round(9 * $scale))
    $btnCancel.BackColor = $colorBtnExit
    $btnCancel.ForeColor = [System.Drawing.Color]::White
    $btnCancel.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $btnCancel.FlatAppearance.BorderSize = 0
    $btnCancel.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
    $sf.Controls.Add($btnCancel)
    $sf.CancelButton = $btnCancel
    
    $result = $sf.ShowDialog()
    if ($result -eq [System.Windows.Forms.DialogResult]::OK) {
        $selected = @()
        for ($i = 0; $i -lt $clb.Items.Count; $i++) {
            if ($clb.GetItemChecked($i) -and $fileMap.ContainsKey($i)) {
                $selected += $fileMap[$i]
            }
        }
        $sf.Dispose()
        return $selected
    }
    $sf.Dispose()
    return $null
}

# ===== Network Drive Mapping =====
function Start-NetworkMapping {
    $drives = @('Z','Y','X','W','V','U','T')
    $ipBase = "10.10.10"
    $ipStart = 12
    $ipEnd = 18
    
    Append-Output "正在映射网络驱动器..." ([System.Drawing.Color]::Cyan)
    Append-Output "────────────────────────────────────" ([System.Drawing.Color]::Gray)
    
    foreach ($letter in $drives) {
        net use "${letter}:" /delete /y 2>&1 | Out-Null
    }
    Start-Sleep -Seconds 1
    
    $results = @()
    $successCount = 0
    $failCount = 0
    
    for ($i = 0; $i -lt $drives.Count; $i++) {
        $letter = $drives[$i]
        $ip = $ipStart + $i
        $path = "\\${ipBase}.${ip}\d"
        
        $output = net use "${letter}:" $path /persistent:yes 2>&1 | Out-String
        if ($LASTEXITCODE -eq 0) {
            $line = "[OK]  ${letter}: → $path  映射成功"
            Append-Output $line ([System.Drawing.Color]::FromArgb(80,220,80))
            $results += "  $line"
            $successCount++
        } else {
            $err = ($output -replace '\s+', ' ').Trim()
            $line = "[!!]  ${letter}: → $path  映射失败"
            Append-Output $line ([System.Drawing.Color]::FromArgb(255,100,100))
            $results += "  $line`n       原因: $err"
            $failCount++
        }
    }
    
    Append-Output "────────────────────────────────────" ([System.Drawing.Color]::Gray)
    
    $icon = if ($failCount -eq 0) { [System.Windows.Forms.MessageBoxIcon]::Information } else { [System.Windows.Forms.MessageBoxIcon]::Warning }
    $popupMsg = "多路塔机网络驱动器映射结果：`n`n" + ($results -join "`n") + "`n`n成功: $successCount  失败: $failCount"
    try {
        [System.Windows.Forms.MessageBox]::Show($popupMsg, "映射网络驱动器 --龙信硬件组", [System.Windows.Forms.MessageBoxButtons]::OK, $icon)
    } catch {}
}

# ===== Button Events =====
$btnSetup.Add_Click({ Start-ScriptRun "system_setup.ps1" "仅系统设置" })
$btnPrecheck.Add_Click({ Start-Precheck })
$btnReport.Add_Click({ Export-IssueReport })

$btnNetwork.Add_Click({
    if ($script:running) { return }
    Set-Running $true
    $outputBox.Clear()
    $statusLabel.Text = "正在映射网络驱动器，请稍等。"
    $taskLabel.Text = "当前任务：映射网络驱动器"
    $logPathLabel.Text = "日志位置：此操作直接显示在窗口内"
    Start-NetworkMapping
    Set-Running $false
    $statusLabel.Text = "映射网络驱动器已完成。"
    $taskLabel.Text = "当前任务：已完成"
})

$btnFull.Add_Click({
    if ($script:running) { return }
    $selected = Show-SoftwareSelection
    if ($null -eq $selected) {
        Append-Output "用户取消了软件安装" ([System.Drawing.Color]::Yellow)
        return
    }
    if ($selected.Count -eq 0) {
        Append-Output "未选择任何软件，将仅执行系统设置" ([System.Drawing.Color]::Yellow)
        Start-ScriptRun "system_setup.ps1" "仅系统设置"
    } else {
        $list = ($selected -join "|")
        Append-Output "已选择 $($selected.Count) 个软件，开始完整安装..." ([System.Drawing.Color]::Cyan)
        Start-ScriptRun "full_setup.ps1" "完整安装" "-InstallList `"$list`""
    }
})

$btnRestore.Add_Click({ Start-ScriptRun "system_restore.ps1" "还原设置" })

$btnExit.Add_Click({ $form.Close() })

$form.Add_FormClosing({
    param($sender, $e)
    if ($script:proc -and !$script:proc.HasExited) {
        $result = [System.Windows.Forms.MessageBox]::Show(
            "当前还有任务正在运行。`n`n如果现在退出，正在运行的脚本会被停止。确定要退出吗？",
            "确认退出 --龙信硬件组",
            [System.Windows.Forms.MessageBoxButtons]::YesNo,
            [System.Windows.Forms.MessageBoxIcon]::Warning
        )
        if ($result -ne [System.Windows.Forms.DialogResult]::Yes) {
            $e.Cancel = $true
            return
        }
        try { $script:proc.Kill() } catch {}
    }
    if ($script:activeTimer) {
        try { $script:activeTimer.Stop(); $script:activeTimer.Dispose() } catch {}
    }
})

# ===== Welcome =====
Append-Output "电脑出厂调试工具 v2.1  --龙信硬件组" ([System.Drawing.Color]::Cyan)
Append-Output "" ([System.Drawing.Color]::Gray)
Append-Output "  仅系统设置：壁纸、锁屏、更新、电源、安全、任务栏" ([System.Drawing.Color]::FromArgb(180,180,180))
Append-Output "  完整安装：系统设置 + software 文件夹内勾选的软件" ([System.Drawing.Color]::FromArgb(180,180,180))
Append-Output "  还原设置：将本工具修改过的设置恢复为 Windows 默认" ([System.Drawing.Color]::FromArgb(180,180,180))
Append-Output "  映射网络驱动器：Z: 到 T:，对应 10.10.10.12 到 10.10.10.18" ([System.Drawing.Color]::FromArgb(180,180,180))
Append-Output "  预检查：只检查环境，不修改系统" ([System.Drawing.Color]::FromArgb(180,180,180))
Append-Output "  导出问题报告：把日志、脚本和电脑信息打包成 zip" ([System.Drawing.Color]::FromArgb(180,180,180))
Append-Output "" ([System.Drawing.Color]::Gray)
Append-Output "点击上方按钮开始。运行期间按钮会暂时禁用，完成后自动恢复。" ([System.Drawing.Color]::Gray)

$form.ShowDialog() | Out-Null
