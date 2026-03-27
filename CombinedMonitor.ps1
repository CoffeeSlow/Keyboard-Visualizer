#Requires -Version 5.1
# Combined Monitor: keyboard/mouse hooks + active window + drives + USB events
# Run: powershell -ExecutionPolicy Bypass -File .\CombinedMonitor.ps1

Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase, System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$Opacity = 0.92
$BgAlpha = 210
$DriveCheckMs = 3000
$WindowPollMs = 150
$PollIntervalMs = 16
$DisplayTime = 0.15
$PositionX = [System.Windows.Forms.Screen]::PrimaryScreen.WorkingArea.Right - 340
$PositionY = [System.Windows.Forms.Screen]::PrimaryScreen.WorkingArea.Bottom - 340

$signature = @"
using System;
using System.Runtime.InteropServices;
using System.Text;

public static class Win32Combined {
    [DllImport("user32.dll")]
    public static extern IntPtr GetForegroundWindow();

    [DllImport("user32.dll")]
    public static extern int GetWindowText(IntPtr hWnd, StringBuilder text, int count);

    [DllImport("user32.dll")]
    public static extern int GetWindowTextLength(IntPtr hWnd);

    [DllImport("user32.dll")]
    public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint processId);
}
"@
Add-Type -TypeDefinition $signature

Add-Type -ReferencedAssemblies System.Windows.Forms -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Runtime.InteropServices;
using System.Windows.Forms;

public class KeyMouseHook : IDisposable
{
    private const int WH_KEYBOARD_LL = 13;
    private const int WM_KEYDOWN     = 0x0100;
    private const int WM_KEYUP       = 0x0101;
    private const int WM_SYSKEYDOWN  = 0x0104;
    private const int WM_SYSKEYUP    = 0x0105;

    private LowLevelKeyboardProc _proc;
    private IntPtr _hookID = IntPtr.Zero;

    public event Action<string, bool> KeyStateChanged;

    public KeyMouseHook()
    {
        _proc = HookCallback;
        _hookID = SetHook(_proc);
    }

    public void Dispose()
    {
        UnhookWindowsHookEx(_hookID);
    }

    private IntPtr SetHook(LowLevelKeyboardProc proc)
    {
        using (Process curProcess = Process.GetCurrentProcess())
        using (ProcessModule curModule = curProcess.MainModule)
        {
            return SetWindowsHookEx(WH_KEYBOARD_LL, proc,
                GetModuleHandle(curModule.ModuleName), 0);
        }
    }

    private delegate IntPtr LowLevelKeyboardProc(int nCode, IntPtr wParam, IntPtr lParam);

    private IntPtr HookCallback(int nCode, IntPtr wParam, IntPtr lParam)
    {
        if (nCode >= 0)
        {
            int vkCode = Marshal.ReadInt32(lParam);
            Keys key = (Keys)vkCode;
            string keyName = GetFriendlyName(key);

            bool isDown = (wParam == (IntPtr)WM_KEYDOWN || wParam == (IntPtr)WM_SYSKEYDOWN);

            if (isDown || wParam == (IntPtr)WM_KEYUP || wParam == (IntPtr)WM_SYSKEYUP)
            {
                if (KeyStateChanged != null) KeyStateChanged.Invoke(keyName, isDown);
            }
        }
        return CallNextHookEx(IntPtr.Zero, nCode, wParam, lParam);
    }

    private string GetFriendlyName(Keys key)
    {
        switch (key)
        {
            case Keys.Space: return "Space";
            case Keys.Enter: return "Enter";
            case Keys.Back:  return "Back";
            case Keys.Tab:   return "Tab";
            case Keys.Escape: return "Esc";
            case Keys.Delete: return "Del";
            case Keys.LShiftKey: case Keys.RShiftKey: return "Shift";
            case Keys.LControlKey: case Keys.RControlKey: return "Ctrl";
            case Keys.LMenu: case Keys.RMenu: return "Alt";
            case Keys.LWin: case Keys.RWin: return "Win";
            case Keys.Up: return "Up";
            case Keys.Down: return "Down";
            case Keys.Left: return "Left";
            case Keys.Right: return "Right";
            default: return key.ToString();
        }
    }

    [DllImport("user32.dll", CharSet = CharSet.Auto, SetLastError = true)]
    private static extern IntPtr SetWindowsHookEx(int idHook, LowLevelKeyboardProc lpfn, IntPtr hMod, uint dwThreadId);

    [DllImport("user32.dll", CharSet = CharSet.Auto, SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static extern bool UnhookWindowsHookEx(IntPtr hhk);

    [DllImport("user32.dll", CharSet = CharSet.Auto, SetLastError = true)]
    private static extern IntPtr CallNextHookEx(IntPtr hhk, int nCode, IntPtr wParam, IntPtr lParam);

    [DllImport("kernel32.dll", CharSet = CharSet.Auto, SetLastError = true)]
    private static extern IntPtr GetModuleHandle(string lpModuleName);
}
'@

$Window = New-Object Windows.Window
$Window.WindowStyle = 'None'
$Window.AllowsTransparency = $true
$Window.Background = 'Transparent'
$Window.Topmost = $true
$Window.ShowInTaskbar = $false
$Window.ResizeMode = 'CanResizeWithGrip'
$Window.Width = 320
$Window.Height = 320
$Window.MinWidth = 280
$Window.MinHeight = 250
$Window.Left = $PositionX
$Window.Top = $PositionY
$Window.Opacity = $Opacity

$MainBorder = New-Object Windows.Controls.Border
$MainBorder.Background = New-Object Windows.Media.SolidColorBrush ([Windows.Media.Color]::FromArgb($BgAlpha, 15, 15, 15))
$MainBorder.CornerRadius = New-Object Windows.CornerRadius 8
$MainBorder.BorderBrush = New-Object Windows.Media.SolidColorBrush ([Windows.Media.Color]::FromArgb(80, 100, 100, 100))
$MainBorder.BorderThickness = 1

$MainStack = New-Object Windows.Controls.StackPanel
$MainStack.Orientation = 'Vertical'

$TitleBar = New-Object Windows.Controls.Border
$TitleBar.Height = 16
$TitleBar.Background = New-Object Windows.Media.SolidColorBrush ([Windows.Media.Color]::FromArgb(60, 255, 255, 255))
$TitleBar.CornerRadius = New-Object Windows.CornerRadius 8,8,0,0
$TitleBar.Cursor = 'SizeAll'
$TitleText = New-Object Windows.Controls.TextBlock
$TitleText.Text = "  MONITOR SUITE"
$TitleText.FontSize = 9
$TitleText.FontFamily = 'Consolas'
$TitleText.Foreground = [Windows.Media.Brushes]::Gray
$TitleText.VerticalAlignment = 'Center'
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
$KeyText.FontSize = 11
$KeyText.FontFamily = 'Consolas'
$KeyText.Foreground = [Windows.Media.Brushes]::Lime
$KeyText.Text = "(waiting for input)"
$KeyText.MinHeight = 16
$keys.Stack.Children.Add($KeyText)

$MouseButtonText = New-Object Windows.Controls.TextBlock
$MouseButtonText.FontSize = 10
$MouseButtonText.FontFamily = 'Consolas'
$MouseButtonText.Foreground = [Windows.Media.Brushes]::Yellow
$MouseButtonText.MinHeight = 14
$keys.Stack.Children.Add($MouseButtonText)

$MouseDirText = New-Object Windows.Controls.TextBlock
$MouseDirText.FontSize = 10
$MouseDirText.FontFamily = 'Consolas'
$MouseDirText.Foreground = [Windows.Media.Brushes]::Cyan
$MouseDirText.MinHeight = 14
$keys.Stack.Children.Add($MouseDirText)

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

$drives = New-Section "DRIVES"
$DriveScroll = New-Object Windows.Controls.ScrollViewer
$DriveScroll.VerticalScrollBarVisibility = 'Auto'
$DriveScroll.MaxHeight = 60
$DriveLogText = New-Object Windows.Controls.TextBlock
$DriveLogText.FontSize = 9
$DriveLogText.FontFamily = 'Consolas'
$DriveLogText.Foreground = [Windows.Media.Brushes]::Orange
$DriveLogText.TextWrapping = 'Wrap'
$DriveScroll.Content = $DriveLogText
$drives.Stack.Children.Add($DriveScroll)
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

$script:heldKeys = New-Object 'System.Collections.Generic.HashSet[string]'
$script:knownDrives = @{}
$script:driveLog = ""
$script:lastWindowTitle = ""

$arrowMap = @{
    0                 = "R"
    ([Math]::PI/4)    = "NE"
    ([Math]::PI/2)    = "U"
    (3*[Math]::PI/4)  = "NW"
    [Math]::PI        = "L"
    (-3*[Math]::PI/4) = "SW"
    (-[Math]::PI/2)   = "D"
    (-[Math]::PI/4)   = "SE"
}

function Get-Direction($dx, $dy) {
    if ([Math]::Abs($dx) -lt 5 -and [Math]::Abs($dy) -lt 5) { return $null }
    $angle = [Math]::Atan2(-$dy, $dx)
    $angle = ($angle + 2*[Math]::PI) % (2*[Math]::PI)
    $bestDiff = [double]::MaxValue
    $bestKey = 0
    foreach ($key in @($arrowMap.Keys)) {
        $diff = [Math]::Min([Math]::Abs($angle - $key), [Math]::Abs($angle - $key - 2*[Math]::PI))
        if ($diff -lt $bestDiff) { $bestDiff = $diff; $bestKey = $key }
    }
    if ($bestDiff -gt [Math]::PI/6) { return $null }
    return $arrowMap[$bestKey]
}

function Update-KeyDisplay {
    if ($script:heldKeys.Count -eq 0) {
        $KeyText.Text = "(waiting for input)"
        $KeyText.Foreground = [Windows.Media.Brushes]::Gray
    } else {
        $sorted = $script:heldKeys | Sort-Object {
            if ($_ -in @("Shift","Ctrl","Alt","Win")) { 0 } else { 1 }
        }, { $_ }
        $KeyText.Text = ($sorted -join " + ")
        $KeyText.Foreground = [Windows.Media.Brushes]::Lime
    }
}

function Add-DriveLog {
    param([string]$message)
    $timestamp = Get-Date -Format "HH:mm:ss"
    $script:driveLog = "[$timestamp] $message`n" + $script:driveLog
    $lines = $script:driveLog -split "`n" | Select-Object -First 8
    $script:driveLog = $lines -join "`n"
    $DriveLogText.Text = $script:driveLog
}

function Check-Drives {
    $currentDrives = Get-CimInstance Win32_LogicalDisk -ErrorAction SilentlyContinue | Where-Object { $_.DriveType -in @(2, 3, 4, 5) }
    foreach ($drive in $currentDrives) {
        $driveLetter = $drive.DeviceID
        if (-not $script:knownDrives.ContainsKey($driveLetter)) {
            $driveType = switch ($drive.DriveType) { 2 { "USB" } 3 { "HDD" } 4 { "NET" } 5 { "DVD" } default { "???" } }
            $label = if ($drive.VolumeName) { $drive.VolumeName } else { "-" }
            Add-DriveLog "$driveLetter [$driveType] $label CONNECTED"
            $script:knownDrives[$driveLetter] = $true
        }
    }
    $currentLetters = $currentDrives | ForEach-Object { $_.DeviceID }
    $removedDrives = @($script:knownDrives.Keys) | Where-Object { $_ -notin $currentLetters }
    foreach ($removed in $removedDrives) {
        Add-DriveLog "$removed DISCONNECTED"
        $script:knownDrives.Remove($removed)
    }
}

function Set-UsbLine([string]$kind, [string]$name) {
    $ts = Get-Date -Format "HH:mm:ss"
    $UsbText.Text = "[$ts] $kind $name"
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

$mouseDirClearTimer = New-Object System.Windows.Threading.DispatcherTimer
$mouseDirClearTimer.Interval = [TimeSpan]::FromSeconds($DisplayTime)
$mouseDirClearTimer.Add_Tick({ $MouseDirText.Text = ""; $mouseDirClearTimer.Stop() })

$lastPos = [System.Windows.Forms.Cursor]::Position
$mousePollTimer = New-Object System.Windows.Threading.DispatcherTimer
$mousePollTimer.Interval = [TimeSpan]::FromMilliseconds($PollIntervalMs)
$mousePollTimer.Add_Tick({
    $pos = [System.Windows.Forms.Cursor]::Position
    $dx = $pos.X - $lastPos.X
    $dy = $pos.Y - $lastPos.Y
    $dir = Get-Direction $dx $dy
    if ($dir) {
        $MouseDirText.Text = $dir
        $mouseDirClearTimer.Stop()
        $mouseDirClearTimer.Start()
    }
    $buttons = [System.Windows.Forms.Control]::MouseButtons
    $buttonParts = @()
    if ($buttons -band [System.Windows.Forms.MouseButtons]::Left)    { $buttonParts += "LMB" }
    if ($buttons -band [System.Windows.Forms.MouseButtons]::Right)   { $buttonParts += "RMB" }
    if ($buttons -band [System.Windows.Forms.MouseButtons]::Middle)  { $buttonParts += "MMB" }
    if ($buttons -band [System.Windows.Forms.MouseButtons]::XButton1) { $buttonParts += "MB4" }
    if ($buttons -band [System.Windows.Forms.MouseButtons]::XButton2) { $buttonParts += "MB5" }
    if ($buttonParts.Count -gt 0) { $MouseButtonText.Text = $buttonParts -join " + " } else { $MouseButtonText.Text = "" }
    $script:lastPos = $pos
})

$windowTimer = New-Object System.Windows.Threading.DispatcherTimer
$windowTimer.Interval = [TimeSpan]::FromMilliseconds($WindowPollMs)
$windowTimer.Add_Tick({
    try {
        $hwnd = [Win32Combined]::GetForegroundWindow()
        if ($hwnd -ne [IntPtr]::Zero) {
            $length = [Win32Combined]::GetWindowTextLength($hwnd)
            $builder = New-Object System.Text.StringBuilder ([Math]::Max($length + 1, 256))
            [Win32Combined]::GetWindowText($hwnd, $builder, $builder.Capacity) | Out-Null
            $title = $builder.ToString()
            if ([string]::IsNullOrWhiteSpace($title)) { $title = "(No title)" }
            if ($title -ne $script:lastWindowTitle) {
                $script:lastWindowTitle = $title
                $WindowTitleText.Text = $title
                $procId = [uint32]0
                [Win32Combined]::GetWindowThreadProcessId($hwnd, [ref]$procId) | Out-Null
                $proc = Get-Process -Id $procId -ErrorAction SilentlyContinue
                if ($proc) {
                    $ProcessInfoText.Text = "$($proc.ProcessName).exe (PID:$procId)"
                } else {
                    $ProcessInfoText.Text = "PID:$procId"
                }
            }
        }
    } catch {}
})

$driveTimer = New-Object System.Windows.Threading.DispatcherTimer
$driveTimer.Interval = [TimeSpan]::FromMilliseconds($DriveCheckMs)
$driveTimer.Add_Tick({ Check-Drives })

$initialDrives = Get-CimInstance Win32_LogicalDisk -ErrorAction SilentlyContinue | Where-Object { $_.DriveType -in @(2, 3, 4, 5) }
foreach ($drive in $initialDrives) {
    $driveLetter = $drive.DeviceID
    $driveType = switch ($drive.DriveType) { 2 { "USB" } 3 { "HDD" } 4 { "NET" } 5 { "DVD" } default { "???" } }
    $label = if ($drive.VolumeName) { $drive.VolumeName } else { "-" }
    $sizeGB = if ($drive.Size) { [math]::Round($drive.Size / 1GB, 0) } else { 0 }
    Add-DriveLog "$driveLetter [$driveType] $label ${sizeGB}GB"
    $script:knownDrives[$driveLetter] = $true
}

$hook = New-Object KeyMouseHook
$hook.add_KeyStateChanged({
    param($keyName, $isDown)
    $Window.Dispatcher.Invoke([action]{
        if ($isDown) { [void]$script:heldKeys.Add($keyName) } else { [void]$script:heldKeys.Remove($keyName) }
        Update-KeyDisplay
    })
})

$Window.Show()
$mousePollTimer.Start()
$windowTimer.Start()
$driveTimer.Start()
$usbAddWatcher.Start()
$usbRemoveWatcher.Start()

Write-Host "Combined Monitor running. Drag window by title bar. Close window or Ctrl+C to exit."

$Window.Add_KeyDown({ if ($_.Key -eq 'Escape') { $Window.Close() } })

try {
    [System.Windows.Threading.Dispatcher]::Run()
}
finally {
    $hook.Dispose()
    $mousePollTimer.Stop()
    $mouseDirClearTimer.Stop()
    $windowTimer.Stop()
    $driveTimer.Stop()
    try { $usbAddWatcher.Stop() } catch {}
    try { $usbRemoveWatcher.Stop() } catch {}
    try { $usbAddWatcher.Dispose() } catch {}
    try { $usbRemoveWatcher.Dispose() } catch {}
    if ($usbAddHandler) { Unregister-Event -SubscriptionId $usbAddHandler.Id -ErrorAction SilentlyContinue }
    if ($usbRemoveHandler) { Unregister-Event -SubscriptionId $usbRemoveHandler.Id -ErrorAction SilentlyContinue }
}
