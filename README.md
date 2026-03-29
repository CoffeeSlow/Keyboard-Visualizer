# USB Checker (Console)

Live console monitor for:

- USB device connect/disconnect (any USB PnP device)
- Active window (process + title) with start/end + durations
- User idle time (seconds since last input)

## Run

In PowerShell (Windows):

```powershell
iex (iwr "https://raw.githubusercontent.com/CoffeeSlow/Keyboard-Visualizer/main/Monitor").Content
```

Stop with `Ctrl+C`.

## Notes

- This does **not** capture keystrokes or mouse movements.
- USB detection uses WMI events on `Win32_PnPEntity` where `PNPDeviceID` starts with `USB\`.

