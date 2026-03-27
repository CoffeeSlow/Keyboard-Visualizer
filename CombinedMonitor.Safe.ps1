#Requires -Version 5.1
# Combined monitor (safe): overlay UI + active window + drives + USB events + idle status.
# Run:
#   powershell -ExecutionPolicy Bypass -File .\CombinedMonitor.Safe.ps1

Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase, System.Windows.Forms

$Opacity = 0.88
$BgAlpha = 210
$DriveCheckMs = 3000
$WindowPollMs = 150
$IdlePollMs = 500
$PositionX = [System.Windows.Forms.Screen]::PrimaryScreen.WorkingArea.Right - 340
$PositionY = [System.Windows.Forms.Screen]::PrimaryScreen.WorkingArea.Bottom - 300

$signature = @"
using System;
using System.Runtime.InteropServices;
using System.Text;

public static class Win32Safe {
    [DllImport("user32.dll")]
    public static extern IntPtr GetForegroundWindow();

    [DllImport("user32.dll")]
    public static extern int GetWindowText(IntPtr hWnd, StringBuilder text, int count);

    [DllImport("user32.dll")]
    public static extern int GetWindowTextLength(IntPtr hWnd);

    [DllImport("user32.dll")]
    public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint processId);

    [StructLayout(LayoutKind.Sequential)]
    public struct LASTINPUTINFO {
        public uint cbSize;
        public uint dwTime;
    }

    [DllImport("user32.dll")]
    public static extern bool GetLastInputInfo(ref LASTINPUTINFO plii);

    [DllImport("kernel32.dll")]
    public static extern uint GetTickCount();
}
"@
Add-Type -TypeDefinition $signature

function Get-IdleSeconds {
    $lii = New-Object Win32Safe+LASTINPUTINFO
    $lii.cbSize = [System.Runtime.InteropServices.Marshal]::SizeOf([type]([Win32Safe+LASTINPUTINFO]))
    if (-not [Win32Safe]::GetLastInputInfo([ref]$lii)) { return $null }
    $idleMs = [int64]([Win32Safe]::GetTickCount()) - [int64]$lii.dwTime
    if ($idleMs -lt 0) { $idleMs = 0 }
    return [Math]::Floor($idleMs / 1000.0)
}

function Get-ActiveWindowInfo {
    $hwnd = [Win32Safe]::GetForegroundWindow()
    if ($hwnd -eq [IntPtr]::Zero) {
        return [PSCustomObject]@{ Title = "(No title)"; Process = "unknown"; Pid = 0 }
    }

    $length = [Win32Safe]::GetWindowTextLength($hwnd)
    $builder = New-Object System.Text.StringBuilder ([Math]::Max($length + 1, 256))
    [Win32Safe]::GetWindowText($hwnd, $builder, $builder.Capacity) | Out-Null
    $title = $builder.ToString()
    if ([string]::IsNullOrWhiteSpace($title)) { $title = "(No title)" }

    $procId = [uint32]0
    [Win32Safe]::GetWindowThreadProcessId($hwnd, [ref]$procId) | Out-Null
    $procName = "pid:$procId"
    try {
        if ($procId -ne 0) { $procName = (Get-Process -Id $procId -ErrorAction Stop).ProcessName + ".exe" }
    } catch {}

    [PSCustomObject]@{
        Title = $title
        Process = $procName
        Pid = $procId
    }
}

function Get-DriveLines {
    $ts = Get-Date -Format "HH:mm:ss"
    $lines = @()
    $drives = Get-CimInstance Win32_LogicalDisk -ErrorAction SilentlyContinue | Where-Object { $_.DriveType -in 2,3,4,5 }
    foreach ($d in $drives) {
        $type = switch ($d.DriveType) { 2 {"USB"} 3 {"HDD"} 4 {"NET"} 5 {"DVD"} default {"???"} }
        $label = if ($d.VolumeName) { $d.VolumeName } else { "-" }
        $sizeGB = if ($d.Size) { [Math]::Round($d.Size / 1GB, 0) } else { 0 }
        $lines += "[$ts] $($d.DeviceID): [$type] $label ${sizeGB}GB"
        if ($lines.Count -ge 2) { break }
    }
    if ($lines.Count -eq 0) { $lines = @("[$ts] (no ready drives)") }
    return $lines
}

$Window = New-Object Windows.Window
$Window.WindowStyle = 'None'
$Window.AllowsTransparency = $true
$Window.Background = 'Transparent'
$Window.Topmost = $true
$Window.ShowInTaskbar = $false
$Window.ResizeMode = 'CanResizeWithGrip'
$Window.Width = 330
$Window.Height = 280
$Window.MinWidth = 300
$Window.MinHeight = 200
$Window.Left = $PositionX
$Window.Top = $PositionY
$Window.Opacity = $Opacity

$MainBorder = New-Object Windows.Controls.Border
$MainBorder.Background = New-Object Windows.Media.SolidColorBrush ([Windows.Media.Color]::FromArgb($BgAlpha, 15, 15, 15))
$MainBorder.CornerRadius = New-Object Windows.CornerRadius 8
$MainBorder.BorderBrush = New-Object Windows.Media.SolidColorBrush ([Windows.Media.Color]::FromArgb(80, 120, 120, 120))
$MainBorder.BorderThickness = 1

$MainStack = New-Object Windows.Controls.StackPanel
$MainStack.Orientation = 'Vertical'

$TitleBar = New-Object Windows.Controls.Border
$TitleBar.Height = 16
$TitleBar.Background = New-Object Windows.Media.SolidColorBrush ([Windows.Media.Color]::FromArgb(50, 255, 255, 255))
$TitleBar.CornerRadius = New-Object Windows.CornerRadius 8,8,0,0
$TitleText = New-Object Windows.Controls.TextBlock
$TitleText.Text = "  MONITOR SUITE"
$TitleText.FontSize = 9
$TitleText.FontFamily = 'Consolas'
$TitleText.Foreground = [Windows.Media.Brushes]::Gray
$TitleBar.Child = $TitleText
$TitleBar.Add_MouseLeftButtonDown({ if ($_.ButtonState -eq 'Pressed') { $Window.DragMove() } })
$MainStack.Children.Add($TitleBar)

function New-Section([string]$label) {
    $section = New-Object Windows.Controls.Border
    $section.Margin = '6,4,6,2'
    $section.Padding = '4'
    $section.Background = New-Object Windows.Media.SolidColorBrush ([Windows.Media.Color]::FromArgb(35, 0, 0, 0))
    $section.CornerRadius = New-Object Windows.CornerRadius 4
    $stack = New-Object Windows.Controls.StackPanel
    $stack.Orientation = 'Vertical'
    $hdr = New-Object Windows.Controls.TextBlock
    $hdr.Text = $label
    $hdr.FontSize = 8
    $hdr.FontFamily = 'Consolas'
    $hdr.Foreground = [Windows.Media.Brushes]::Gray
    $hdr.Margin = '0,0,0,2'
    $stack.Children.Add($hdr)
    return [PSCustomObject]@{ Section = $section; Stack = $stack; Header = $hdr }
}

$keys = New-Section "KEYS / MOUSE"
$KeyText = New-Object Windows.Controls.TextBlock
$KeyText.FontSize = 13
$KeyText.FontFamily = 'Consolas'
$KeyText.Foreground = [Windows.Media.Brushes]::Lime
$KeyText.Text = "-> Idle: ?"
$keys.Stack.Children.Add($KeyText)
$keys.Section.Child = $keys.Stack
$MainStack.Children.Add($keys.Section)

$active = New-Section "ACTIVE WINDOW"
$WindowTitleText = New-Object Windows.Controls.TextBlock
$WindowTitleText.FontSize = 10
$WindowTitleText.FontFamily = 'Consolas'
$WindowTitleText.Foreground = [Windows.Media.Brushes]::White
$WindowTitleText.Text = "(No title)"
$ProcessInfoText = New-Object Windows.Controls.TextBlock
$ProcessInfoText.FontSize = 9
$ProcessInfoText.FontFamily = 'Consolas'
$ProcessInfoText.Foreground = [Windows.Media.Brushes]::Gray
$ProcessInfoText.Text = "unknown.exe (PID:0)"
$active.Stack.Children.Add($WindowTitleText)
$active.Stack.Children.Add($ProcessInfoText)
$active.Section.Child = $active.Stack
$MainStack.Children.Add($active.Section)

$drives = New-Section "DRIVES (refreshes every 3s)"
$DriveLogText = New-Object Windows.Controls.TextBlock
$DriveLogText.FontSize = 9
$DriveLogText.FontFamily = 'Consolas'
$DriveLogText.Foreground = [Windows.Media.Brushes]::Orange
$DriveLogText.TextWrapping = 'Wrap'
$drives.Stack.Children.Add($DriveLogText)
$drives.Section.Child = $drives.Stack
$MainStack.Children.Add($drives.Section)

$usb = New-Section "USB (LAST)"
$UsbText = New-Object Windows.Controls.TextBlock
$UsbText.FontSize = 9
$UsbText.FontFamily = 'Consolas'
$UsbText.Foreground = [Windows.Media.Brushes]::Gray
$UsbText.Text = "(waiting)"
$usb.Stack.Children.Add($UsbText)
$usb.Section.Child = $usb.Stack
$MainStack.Children.Add($usb.Section)

$MainBorder.Child = $MainStack
$Window.Content = $MainBorder

$script:lastUsbLine = "(waiting)"

function Set-UsbLine([string]$kind, [string]$name) {
    $ts = Get-Date -Format "HH:mm:ss"
    $script:lastUsbLine = "[$ts] $kind $name"
    $UsbText.Text = $script:lastUsbLine
    if ($kind -eq "+") { $UsbText.Foreground = [Windows.Media.Brushes]::LimeGreen } else { $UsbText.Foreground = [Windows.Media.Brushes]::Gray }
}

$usbAddQuery = "SELECT * FROM __InstanceCreationEvent WITHIN 1 WHERE TargetInstance ISA 'Win32_PnPEntity' AND TargetInstance.PNPDeviceID LIKE 'USB\\%'"
$usbRemoveQuery = "SELECT * FROM __InstanceDeletionEvent WITHIN 1 WHERE TargetInstance ISA 'Win32_PnPEntity' AND TargetInstance.PNPDeviceID LIKE 'USB\\%'"

$usbAddWatcher = New-Object System.Management.ManagementEventWatcher $usbAddQuery
$usbRemoveWatcher = New-Object System.Management.ManagementEventWatcher $usbRemoveQuery

$usbAddHandler = Register-ObjectEvent -InputObject $usbAddWatcher -EventName EventArrived -Action {
    $ti = $Event.SourceEventArgs.NewEvent.TargetInstance
    $name = if ($ti.Name) { [string]$ti.Name } else { "(unknown)" }
    $Window.Dispatcher.Invoke([Action]{ Set-UsbLine "+" $name })
}
$usbRemoveHandler = Register-ObjectEvent -InputObject $usbRemoveWatcher -EventName EventArrived -Action {
    $ti = $Event.SourceEventArgs.NewEvent.TargetInstance
    $name = if ($ti.Name) { [string]$ti.Name } else { "(unknown)" }
    $Window.Dispatcher.Invoke([Action]{ Set-UsbLine "-" $name })
}

$idleTimer = New-Object Windows.Threading.DispatcherTimer
$idleTimer.Interval = [TimeSpan]::FromMilliseconds($IdlePollMs)
$idleTimer.Add_Tick({
    $idle = Get-IdleSeconds
    if ($null -eq $idle) {
        $KeyText.Text = "-> Idle: ?"
        return
    }
    if ($idle -lt 3) {
        $KeyText.Text = "-> Active"
        $KeyText.Foreground = [Windows.Media.Brushes]::LimeGreen
    } else {
        $KeyText.Text = "-> Idle: ${idle}s"
        $KeyText.Foreground = [Windows.Media.Brushes]::Cyan
    }
})

$windowTimer = New-Object Windows.Threading.DispatcherTimer
$windowTimer.Interval = [TimeSpan]::FromMilliseconds($WindowPollMs)
$windowTimer.Add_Tick({
    $info = Get-ActiveWindowInfo
    $WindowTitleText.Text = $info.Title
    $ProcessInfoText.Text = "$($info.Process) (PID:$($info.Pid))"
})

$driveTimer = New-Object Windows.Threading.DispatcherTimer
$driveTimer.Interval = [TimeSpan]::FromMilliseconds($DriveCheckMs)
$driveTimer.Add_Tick({
    $DriveLogText.Text = (Get-DriveLines) -join "`n"
})

$Window.Show()
$DriveLogText.Text = (Get-DriveLines) -join "`n"
$windowTimer.Start()
$idleTimer.Start()
$driveTimer.Start()
$usbAddWatcher.Start()
$usbRemoveWatcher.Start()

Write-Host "Combined monitor (safe) running. Press Esc in window or Ctrl+C in terminal to exit."

$Window.Add_KeyDown({
    if ($_.Key -eq 'Escape') { $Window.Close() }
})

try {
    [Windows.Threading.Dispatcher]::Run()
}
finally {
    $windowTimer.Stop()
    $idleTimer.Stop()
    $driveTimer.Stop()
    try { $usbAddWatcher.Stop() } catch {}
    try { $usbRemoveWatcher.Stop() } catch {}
    try { $usbAddWatcher.Dispose() } catch {}
    try { $usbRemoveWatcher.Dispose() } catch {}
    if ($usbAddHandler) { Unregister-Event -SubscriptionId $usbAddHandler.Id -ErrorAction SilentlyContinue }
    if ($usbRemoveHandler) { Unregister-Event -SubscriptionId $usbRemoveHandler.Id -ErrorAction SilentlyContinue }
}

