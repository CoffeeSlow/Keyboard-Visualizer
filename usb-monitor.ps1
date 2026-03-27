Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Write-EventLine {
  param(
    [Parameter(Mandatory)][string]$Category,
    [Parameter(Mandatory)][string]$Message
  )
  $ts = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss.fff')
  Write-Host "[$ts] [$Category] $Message"
}

function Format-Duration {
  param([Parameter(Mandatory)][TimeSpan]$Duration)
  if ($Duration.TotalHours -ge 1) { return ('{0:hh\:mm\:ss}' -f $Duration) }
  return ('{0:mm\:ss}' -f $Duration)
}

Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
using System.Text;

public static class Win32 {
  [DllImport("user32.dll")]
  public static extern IntPtr GetForegroundWindow();

  [DllImport("user32.dll", CharSet = CharSet.Unicode)]
  public static extern int GetWindowText(IntPtr hWnd, StringBuilder text, int count);

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

function Get-ActiveWindowInfo {
  $h = [Win32]::GetForegroundWindow()
  if ($h -eq [IntPtr]::Zero) { return $null }

  $sb = New-Object System.Text.StringBuilder 1024
  [void][Win32]::GetWindowText($h, $sb, $sb.Capacity)
  $procId = [uint32]0
  [void][Win32]::GetWindowThreadProcessId($h, [ref]$procId)

  $procName = ''
  try {
    if ($procId -ne 0) {
      $procName = (Get-Process -Id $procId -ErrorAction Stop).ProcessName
    }
  } catch {
    $procName = "pid:$procId"
  }

  [PSCustomObject]@{
    Handle = $h
    Pid = $procId
    Process = $procName
    Title = $sb.ToString()
  }
}

function Get-IdleTime {
  $lii = New-Object Win32+LASTINPUTINFO
  $lii.cbSize = [System.Runtime.InteropServices.Marshal]::SizeOf([type]([Win32+LASTINPUTINFO]))
  if (-not [Win32]::GetLastInputInfo([ref]$lii)) { return $null }
  $ticks = [Win32]::GetTickCount()
  $idleMs = [int64]$ticks - [int64]$lii.dwTime
  if ($idleMs -lt 0) { $idleMs = 0 }
  return [TimeSpan]::FromMilliseconds($idleMs)
}

function New-UsbPnPEntityQuery {
  param(
    [Parameter(Mandatory)][ValidateSet('Create','Delete')][string]$Kind
  )
  $wmiClass = if ($Kind -eq 'Create') { '__InstanceCreationEvent' } else { '__InstanceDeletionEvent' }
  $withinSeconds = 1

  # Win32_PnPEntity covers most USB devices (HID, storage, hubs, etc.)
  # We filter on PNPDeviceID starting with "USB\" to avoid noisy non-USB PnP changes.
  return @"
SELECT * FROM $wmiClass WITHIN $withinSeconds
WHERE TargetInstance ISA 'Win32_PnPEntity'
  AND TargetInstance.PNPDeviceID LIKE 'USB\\%'
"@
}

function Start-UsbWatchers {
  $createQuery = New-UsbPnPEntityQuery -Kind Create
  $deleteQuery = New-UsbPnPEntityQuery -Kind Delete

  Register-WmiEvent -Query $createQuery -SourceIdentifier 'UsbPnP.Add' -Action {
    try {
      $ti = $Event.SourceEventArgs.NewEvent.TargetInstance
      $name = [string]$ti.Name
      $cls = [string]$ti.PNPClass
      $id = [string]$ti.PNPDeviceID
      Write-EventLine -Category 'USB+' -Message ("{0}  class={1}  id={2}" -f $name, $cls, $id)
    } catch {
      Write-EventLine -Category 'USB+' -Message ("(failed to parse event) {0}" -f $_.Exception.Message)
    }
  } | Out-Null

  Register-WmiEvent -Query $deleteQuery -SourceIdentifier 'UsbPnP.Remove' -Action {
    try {
      $ti = $Event.SourceEventArgs.NewEvent.TargetInstance
      $name = [string]$ti.Name
      $cls = [string]$ti.PNPClass
      $id = [string]$ti.PNPDeviceID
      Write-EventLine -Category 'USB-' -Message ("{0}  class={1}  id={2}" -f $name, $cls, $id)
    } catch {
      Write-EventLine -Category 'USB-' -Message ("(failed to parse event) {0}" -f $_.Exception.Message)
    }
  } | Out-Null
}

function Stop-UsbWatchers {
  Get-EventSubscriber | Where-Object { $_.SourceIdentifier -in @('UsbPnP.Add', 'UsbPnP.Remove') } | ForEach-Object {
    try { Unregister-Event -SubscriptionId $_.SubscriptionId -Force } catch {}
  }
}

function Start-Monitor {
  param(
    [int]$ActiveWindowPollMs = 250,
    [int]$IdlePrintEveryMs = 1000
  )

  Write-EventLine -Category 'INFO' -Message 'Starting monitor (USB add/remove, active window, idle time).'
  Write-EventLine -Category 'INFO' -Message 'Press Ctrl+C to stop.'

  Start-UsbWatchers

  $lastWin = $null
  $lastWinStart = Get-Date
  $lastIdlePrint = [DateTime]::MinValue

  try {
    while ($true) {
      $now = Get-Date

      $curWin = Get-ActiveWindowInfo
      if ($null -ne $curWin) {
        $changed = $false
        if ($null -eq $lastWin) { $changed = $true }
        elseif ($curWin.Handle -ne $lastWin.Handle) { $changed = $true }
        elseif ($curWin.Pid -ne $lastWin.Pid) { $changed = $true }
        elseif ($curWin.Title -ne $lastWin.Title) { $changed = $true }

        if ($changed) {
          if ($null -ne $lastWin) {
            $dur = $now - $lastWinStart
            Write-EventLine -Category 'WIN' -Message ("END   {0} ({1})  ""{2}""" -f $lastWin.Process, $lastWin.Pid, $lastWin.Title)
            Write-EventLine -Category 'WIN' -Message ("DUR   {0}" -f (Format-Duration -Duration $dur))
          }
          $lastWin = $curWin
          $lastWinStart = $now
          Write-EventLine -Category 'WIN' -Message ("START {0} ({1})  ""{2}""" -f $curWin.Process, $curWin.Pid, $curWin.Title)
        }
      }

      if (($now - $lastIdlePrint).TotalMilliseconds -ge $IdlePrintEveryMs) {
        $idle = Get-IdleTime
        if ($null -ne $idle) {
          $idleSec = [Math]::Floor($idle.TotalSeconds)
          Write-Host ("[{0}] [IDLE] {1}s" -f $now.ToString('yyyy-MM-dd HH:mm:ss.fff'), $idleSec)
        }
        $lastIdlePrint = $now
      }

      Start-Sleep -Milliseconds $ActiveWindowPollMs
    }
  } finally {
    Stop-UsbWatchers
    Write-EventLine -Category 'INFO' -Message 'Stopped.'
  }
}

Start-Monitor

