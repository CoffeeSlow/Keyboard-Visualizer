# USB Checker (Console)

Live console monitor for:

- USB device connect/disconnect (any USB PnP device)
- Active window (process + title) with start/end + durations
- User idle time (seconds since last input)

## Run

In PowerShell (Windows):

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
.\usb-monitor.ps1
```

Stop with `Ctrl+C`.

## Notes

- This does **not** capture keystrokes or mouse movements.
- USB detection uses WMI events on `Win32_PnPEntity` where `PNPDeviceID` starts with `USB\`.

